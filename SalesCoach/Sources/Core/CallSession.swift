import Foundation
import AVFoundation

/// Main orchestrator for a call session
actor CallSession {
    // MARK: - Components
    
    private let audioService: AudioCaptureService
    private var transcriber: WhisperTranscriber?
    private let coachEngine: CoachEngine
    private let tickScheduler: TickScheduler
    private let langfuseService: LangfuseService?
    
    // MARK: - State
    
    private var transcriptBuffer: TranscriptBuffer
    private var coachingState: CoachingState
    private var isRunning = false
    private var isPaused = false
    
    // MARK: - Session Identity
    
    let sessionId: String
    private let sessionStartTime: Date
    
    // MARK: - Configuration
    
    private let settings: AppSettings
    
    // MARK: - Callbacks
    
    private let onTranscriptUpdate: @Sendable (TranscriptEvent) -> Void
    private let onCoachingUpdate: @Sendable (CoachingState) -> Void
    private let onError: @Sendable (Error) -> Void
    
    // MARK: - Tasks
    
    private var transcriptionTask: Task<Void, Never>?
    
    init(
        settings: AppSettings,
        langfuseService: LangfuseService? = nil,
        onTranscriptUpdate: @escaping @Sendable (TranscriptEvent) -> Void,
        onCoachingUpdate: @escaping @Sendable (CoachingState) -> Void,
        onError: @escaping @Sendable (Error) -> Void
    ) {
        self.settings = settings
        self.langfuseService = langfuseService
        self.onTranscriptUpdate = onTranscriptUpdate
        self.onCoachingUpdate = onCoachingUpdate
        self.onError = onError
        
        // Generate unique session ID
        self.sessionId = UUID().uuidString
        self.sessionStartTime = Date()
        
        self.audioService = AudioCaptureService()
        self.transcriptBuffer = TranscriptBuffer()
        self.coachingState = CoachingState()
        self.tickScheduler = TickScheduler(intervalSeconds: settings.tickIntervalSeconds)
        
        // Create tracing-enabled LLM client
        let tracingClient = TracingLLMClient.create(
            from: settings,
            apiKey: KeychainService.shared.getAPIKey(),
            langfuseService: langfuseService
        )
        
        self.coachEngine = CoachEngine(
            llmClient: tracingClient,
            checklist: settings.processChecklist,
            langfuseService: langfuseService,
            temperature: settings.llmMode == .local ? settings.localLLMConfig.temperature : settings.cloudLLMConfig.temperature,
            maxTokens: settings.llmMode == .local ? settings.localLLMConfig.maxTokens : settings.cloudLLMConfig.maxTokens
        )
        
        setupCallbacks()
    }
    
    private func setupCallbacks() {
        // Setup tick scheduler
        Task {
            await tickScheduler.setTickHandler { [weak self] in
                await self?.performCoachingTick()
            }
            
            await tickScheduler.setSkipCheck { [weak self] in
                guard let self = self else { return true }
                // Skip if no new transcript content
                return await self.isTranscriptEmpty()
            }
        }
    }
    
    /// Check if transcript is empty (actor-isolated helper)
    private func isTranscriptEmpty() -> Bool {
        transcriptBuffer.isEmpty
    }
    
    // MARK: - Session Control
    
    func start() async throws {
        guard !isRunning else { return }
        
        // Setup Langfuse session tracking
        if let service = langfuseService, await service.isEnabled {
            await service.setSessionId(sessionId)
            
            // Create initial trace for the session with input
            let _ = await service.createTrace(
                name: "sales-coaching-session",
                tags: ["session-start"],
                metadata: [
                    "llm_mode": settings.llmMode.rawValue,
                    "language": settings.transcriptionLanguage.rawValue,
                    "tick_interval": settings.tickIntervalSeconds
                ],
                input: [
                    "session_id": sessionId,
                    "llm_mode": settings.llmMode.rawValue,
                    "language": settings.transcriptionLanguage.rawValue,
                    "tick_interval_seconds": settings.tickIntervalSeconds,
                    "transcript_window_ms": Int(settings.transcriptWindowMs)  // Convert Int64 to Int for JSON encoding
                ]
            )
        }
        
        // Initialize transcriber with model from bundle
        let modelPath = getModelPath()
        let config = TranscriberConfig(
            modelPath: modelPath,
            language: settings.transcriptionLanguage.whisperCode
        )
        transcriber = WhisperTranscriber(config: config)
        
        // Setup audio capture callback
        await audioService.setAudioBufferHandler { [weak self] buffer in
            Task { [weak self] in
                await self?.transcriber?.feedAudio(buffer)
            }
        }
        
        // Start components
        try await audioService.start()
        try await transcriber?.start()
        
        // Start listening to transcript events
        startTranscriptionListener()
        
        // Start tick scheduler
        await tickScheduler.start()
        
        isRunning = true
        isPaused = false
    }
    
    func stop() async {
        guard isRunning else { return }
        
        await tickScheduler.stop()
        await transcriber?.stop()
        await audioService.stop()
        
        transcriptionTask?.cancel()
        transcriptionTask = nil
        
        // Flush any pending Langfuse events
        await langfuseService?.flush()
        
        isRunning = false
        isPaused = false
    }
    
    func pause() async {
        guard isRunning && !isPaused else { return }
        
        await tickScheduler.pause()
        await audioService.pause()
        
        isPaused = true
    }
    
    func resume() async {
        guard isRunning && isPaused else { return }
        
        try? await audioService.resume()
        await tickScheduler.resume()
        
        isPaused = false
    }
    
    // MARK: - Transcription
    
    private func startTranscriptionListener() {
        transcriptionTask = Task { [weak self] in
            guard let self = self,
                  let transcriber = await self.transcriber else { return }
            
            for await event in await transcriber.transcriptStream {
                await self.handleTranscriptEvent(event)
            }
        }
    }
    
    private func handleTranscriptEvent(_ event: TranscriptEvent) {
        switch event {
        case .partial(let text):
            transcriptBuffer.updatePartial(text)
        case .final(let segment):
            transcriptBuffer.addSegment(segment)
        case .error:
            break
        }
        
        onTranscriptUpdate(event)
    }
    
    // MARK: - Coaching
    
    private func performCoachingTick() async {
        do {
            let newState = try await coachEngine.analyze(
                currentState: coachingState,
                transcriptBuffer: transcriptBuffer,
                windowMs: settings.transcriptWindowMs
            )
            
            coachingState = newState
            onCoachingUpdate(newState)
        } catch {
            onError(error)
        }
    }
    
    // MARK: - Helpers
    
    private func getModelPath() -> URL {
        // Try multilingual model in bundle first (supports English, French, etc.)
        if let bundlePath = Bundle.main.path(forResource: "ggml-base", ofType: "bin") {
            return URL(fileURLWithPath: bundlePath)
        }
        
        // Fallback to English-only model in bundle
        if let bundlePath = Bundle.main.path(forResource: "ggml-base.en", ofType: "bin") {
            return URL(fileURLWithPath: bundlePath)
        }
        
        // Fallback to common locations
        let possiblePaths = [
            "/usr/local/share/whisper/ggml-base.bin",
            "~/.cache/whisper/ggml-base.bin",
            "/usr/local/share/whisper/ggml-base.en.bin",
            "~/.cache/whisper/ggml-base.en.bin"
        ]
        
        for path in possiblePaths {
            let expandedPath = NSString(string: path).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expandedPath) {
                return URL(fileURLWithPath: expandedPath)
            }
        }
        
        // Default path (may not exist)
        return URL(fileURLWithPath: "/usr/local/share/whisper/ggml-base.bin")
    }
    
    // MARK: - Accessors
    
    var currentTranscriptBuffer: TranscriptBuffer {
        transcriptBuffer
    }
    
    var currentCoachingState: CoachingState {
        coachingState
    }
    
    var sessionIsRunning: Bool {
        isRunning
    }
    
    var sessionIsPaused: Bool {
        isPaused
    }
}
