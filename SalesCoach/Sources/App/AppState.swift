import Foundation
import SwiftUI
import Combine

// #region agent log
private let debugLogPath = "/Users/mallaire/Documents/sales-assistant/.cursor/debug.log"
private func debugLog(_ location: String, _ message: String, _ data: [String: Any] = [:], hypothesis: String = "") {
    let entry: [String: Any] = ["timestamp": Date().timeIntervalSince1970 * 1000, "location": location, "message": message, "data": data, "hypothesisId": hypothesis, "sessionId": "debug-session"]
    if let jsonData = try? JSONSerialization.data(withJSONObject: entry), let jsonString = String(data: jsonData, encoding: .utf8) {
        if let handle = FileHandle(forWritingAtPath: debugLogPath) {
            handle.seekToEndOfFile()
            handle.write((jsonString + "\n").data(using: .utf8)!)
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: debugLogPath, contents: (jsonString + "\n").data(using: .utf8))
        }
    }
}
// #endregion

/// Global application state
@MainActor
class AppState: ObservableObject {
    // MARK: - Published Properties
    
    @Published var currentSession: CallSession?
    @Published var isRecording: Bool = false
    @Published var isPaused: Bool = false
    @Published var transcriptBuffer: TranscriptBuffer = TranscriptBuffer()
    @Published var coachingState: CoachingState = CoachingState()
    @Published var settings: AppSettings
    @Published var connectionStatus: ConnectionStatus = .idle
    @Published var recordingDuration: TimeInterval = 0
    @Published var showExportDialog: Bool = false
    @Published var errorMessage: String?
    @Published var isCloudModeWarningShown: Bool = false
    @Published var processChecklist: ProcessChecklist = .defaultChecklist
    
    // MARK: - Private Properties
    
    private var settingsStore: SettingsStore
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var cancellables = Set<AnyCancellable>()
    private var langfuseService: LangfuseService?
    
    // MARK: - Initialization
    
    init() {
        // #region agent log
        debugLog("AppState.swift:init", "AppState init started", ["connectionStatus": "idle"], hypothesis: "H1")
        // #endregion
        
        self.settingsStore = SettingsStore()
        self.settings = settingsStore.load()
        
        // #region agent log
        debugLog("AppState.swift:init", "Settings loaded", ["llmMode": settings.llmMode.rawValue, "baseURL": settings.localLLMConfig.baseURL], hypothesis: "H1")
        // #endregion
        
        setupSettingsObserver()
        configureLangfuse()
        
        // #region agent log
        debugLog("AppState.swift:init", "AppState init completed - NO connection test called", ["connectionStatus": "idle"], hypothesis: "H1")
        // #endregion
    }
    
    // MARK: - Langfuse Configuration
    
    /// Configure or reconfigure Langfuse service based on current settings
    func configureLangfuse() {
        let previouslyEnabled = langfuseService != nil
        
        guard settings.langfuseConfig.isEnabled else {
            langfuseService = nil
            return
        }
        
        // Priority: Environment variables -> Keychain
        let env = ProcessInfo.processInfo.environment
        let publicKey = env["LANGFUSE_PUBLIC_KEY"] ?? KeychainService.shared.getLangfusePublicKey() ?? ""
        let secretKey = env["LANGFUSE_SECRET_KEY"] ?? KeychainService.shared.getLangfuseSecretKey() ?? ""
        
        // Override base URL from environment if provided
        if let baseURL = env["LANGFUSE_BASE_URL"], !baseURL.isEmpty {
            settings.langfuseConfig.baseURL = baseURL
        }
        
        guard !publicKey.isEmpty, !secretKey.isEmpty else {
            langfuseService = nil
            return
        }
        
        langfuseService = LangfuseService(
            config: settings.langfuseConfig,
            publicKey: publicKey,
            secretKey: secretKey
        )
        
        // If Langfuse was just enabled and there's an existing session without tracing,
        // invalidate it so the next recording gets proper tracing
        if !previouslyEnabled && currentSession != nil && !isRecording {
            currentSession = nil
        }
    }
    
    /// Save Langfuse API keys and reconfigure the service
    func saveLangfuseKeys(publicKey: String, secretKey: String) {
        _ = KeychainService.shared.setLangfusePublicKey(publicKey)
        _ = KeychainService.shared.setLangfuseSecretKey(secretKey)
        configureLangfuse()
    }
    
    /// Check if Langfuse is properly configured
    var isLangfuseConfigured: Bool {
        settings.langfuseConfig.isEnabled && KeychainService.shared.hasLangfuseKeys
    }
    
    // MARK: - Settings
    
    private func setupSettingsObserver() {
        $settings
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] newSettings in
                self?.settingsStore.save(newSettings)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Session Management
    
    func startNewSession() {
        guard !isRecording else { return }
        
        transcriptBuffer = TranscriptBuffer()
        coachingState = CoachingState()
        recordingDuration = 0
        errorMessage = nil
        
        // Reconfigure Langfuse in case settings changed
        configureLangfuse()
        
        currentSession = CallSession(
            settings: settings,
            langfuseService: langfuseService,
            onTranscriptUpdate: { [weak self] event in
                Task { @MainActor in
                    self?.handleTranscriptEvent(event)
                }
            },
            onCoachingUpdate: { [weak self] state in
                Task { @MainActor in
                    self?.coachingState = state
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    self?.errorMessage = error.localizedDescription
                }
            }
        )
    }
    
    func startRecording() {
        if currentSession == nil {
            startNewSession()
        }
        
        if settings.llmMode == .cloud && !isCloudModeWarningShown {
            isCloudModeWarningShown = true
        }
        
        Task {
            do {
                try await currentSession?.start()
                isRecording = true
                isPaused = false
                startRecordingTimer()
            } catch {
                errorMessage = "Failed to start recording: \(error.localizedDescription)"
            }
        }
    }
    
    func stopRecording() {
        Task {
            await currentSession?.stop()
            isRecording = false
            isPaused = false
            stopRecordingTimer()
        }
    }
    
    func pauseRecording() {
        Task {
            await currentSession?.pause()
            isPaused = true
            stopRecordingTimer()
        }
    }
    
    func resumeRecording() {
        Task {
            await currentSession?.resume()
            isPaused = false
            startRecordingTimer()
        }
    }
    
    // MARK: - Transcript Handling
    
    private func handleTranscriptEvent(_ event: TranscriptEvent) {
        switch event {
        case .partial(let text):
            transcriptBuffer.updatePartial(text)
        case .final(let segment):
            transcriptBuffer.addSegment(segment)
        case .error(let error):
            errorMessage = "Transcription error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Recording Timer
    
    private func startRecordingTimer() {
        recordingStartTime = Date()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let startTime = self.recordingStartTime else { return }
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    // MARK: - Export
    
    func exportSession(format: ExportFormat) async throws -> URL {
        let sessionData = SessionData(
            transcript: transcriptBuffer.segments,
            coachingState: coachingState,
            settings: settings
        )
        
        let fileStore = FileStore()
        return try await fileStore.exportSession(sessionData, format: format)
    }
    
    // MARK: - LLM Connection
    
    func testLLMConnection() async {
        // #region agent log
        debugLog("AppState.swift:testLLMConnection", "testLLMConnection called", ["currentStatus": connectionStatus.displayText], hypothesis: "H1,H2")
        // #endregion
        
        connectionStatus = .connecting
        
        do {
            let client = createLLMClient()
            // #region agent log
            debugLog("AppState.swift:testLLMConnection", "LLM client created, testing connection", ["llmMode": settings.llmMode.rawValue], hypothesis: "H5")
            // #endregion
            
            let success = try await client.testConnection()
            connectionStatus = success ? .connected : .error("Connection test failed")
            
            // #region agent log
            debugLog("AppState.swift:testLLMConnection", "Connection test completed", ["success": success, "newStatus": connectionStatus.displayText], hypothesis: "H1,H2")
            // #endregion
        } catch {
            connectionStatus = .error(error.localizedDescription)
            // #region agent log
            debugLog("AppState.swift:testLLMConnection", "Connection test failed with error", ["error": error.localizedDescription], hypothesis: "H4,H5")
            // #endregion
        }
    }
    
    private func createLLMClient() -> any LLMClient {
        switch settings.llmMode {
        case .local:
            return LMStudioClient(config: settings.localLLMConfig)
        case .cloud:
            let apiKey = KeychainService.shared.getAPIKey() ?? ""
            return OpenAICompatibleClient(config: settings.cloudLLMConfig, apiKey: apiKey)
        }
    }
    
    // MARK: - Formatted Duration
    
    var formattedRecordingDuration: String {
        let seconds = Int(recordingDuration)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}
