import Foundation

/// Engine that coordinates LLM-based coaching analysis
actor CoachEngine {
    private let llmClient: any LLMClient
    private let promptBuilder: PromptBuilder
    private let validator: JSONSchemaValidator
    private let options: CompletionOptions
    private let langfuseService: LangfuseService?
    
    private var lastAnalysisTime: Date?
    private var isProcessing = false
    
    init(
        llmClient: any LLMClient,
        checklist: ProcessChecklist = .defaultChecklist,
        langfuseService: LangfuseService? = nil,
        temperature: Double = 0.3,
        maxTokens: Int = 1024
    ) {
        self.llmClient = llmClient
        self.promptBuilder = PromptBuilder(checklist: checklist, langfuseService: langfuseService)
        self.validator = JSONSchemaValidator()
        self.langfuseService = langfuseService
        self.options = CompletionOptions(
            temperature: temperature,
            maxTokens: maxTokens,
            jsonMode: true
        )
    }
    
    /// Analyze transcript and update coaching state
    func analyze(
        currentState: CoachingState,
        transcriptBuffer: TranscriptBuffer,
        windowMs: Int64
    ) async throws -> CoachingState {
        guard !isProcessing else {
            throw CoachEngineError.alreadyProcessing
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // Get windowed and delta transcript
        let windowedTranscript = transcriptBuffer.windowedText(lastMs: windowMs)
        let deltaTranscript: String
        
        if let lastTime = lastAnalysisTime {
            deltaTranscript = transcriptBuffer.deltaText(since: lastTime)
        } else {
            deltaTranscript = transcriptBuffer.fullText
        }
        
        // Skip if no new content
        guard !deltaTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return currentState
        }
        
        // Create trace for this analysis tick if Langfuse is enabled
        // #region agent log
        let debugLogPath = "/Users/mallaire/Documents/sales-assistant/.cursor/debug.log"
        let h1_langfuseServiceNil = langfuseService == nil
        let logEntry1 = "{\"location\":\"CoachEngine.swift:60\",\"message\":\"H1: langfuseService nil check\",\"data\":{\"isNil\":\(h1_langfuseServiceNil)},\"timestamp\":\(Int(Date().timeIntervalSince1970 * 1000)),\"sessionId\":\"debug-session\",\"hypothesisId\":\"H1\"}\n"
        if let data1 = logEntry1.data(using: .utf8), let handle1 = FileHandle(forWritingAtPath: debugLogPath) {
            handle1.seekToEndOfFile()
            handle1.write(data1)
            handle1.closeFile()
        } else if let data1 = logEntry1.data(using: .utf8) {
            FileManager.default.createFile(atPath: debugLogPath, contents: data1, attributes: nil)
        }
        // #endregion
        
        // Create trace for this analysis tick if Langfuse is enabled
        var traceId: String? = nil
        if let service = langfuseService, await service.isEnabled {
            // Record coaching tick in session statistics
            await service.recordCoachingTick()
            
            // Pass input (transcript data) to trace
            traceId = await service.createTrace(
                name: "coaching-analysis-tick",
                metadata: [
                    "transcript_length": deltaTranscript.count,
                    "current_stage": currentState.stage?.name ?? "unknown"
                ],
                input: [
                    "windowed_transcript": windowedTranscript,
                    "delta_transcript": deltaTranscript,
                    "window_ms": Int(windowMs)  // Convert Int64 to Int for JSON encoding
                ]
            )
        }
        
        // Build messages (use async version if Langfuse is available for prompt tracking)
        let messages: [ChatMessage]
        var systemPromptVersion: Int? = nil
        var userPromptVersion: Int? = nil
        // #region agent log
        let h3_useAsyncPath = langfuseService != nil
        let logEntry3 = "{\"location\":\"CoachEngine.swift:74\",\"message\":\"H3: async path selection\",\"data\":{\"useAsyncPath\":\(h3_useAsyncPath)},\"timestamp\":\(Int(Date().timeIntervalSince1970 * 1000)),\"sessionId\":\"debug-session\",\"hypothesisId\":\"H3\"}\n"
        if let data3 = logEntry3.data(using: .utf8), let handle3 = FileHandle(forWritingAtPath: debugLogPath) {
            handle3.seekToEndOfFile()
            handle3.write(data3)
            handle3.closeFile()
        }
        // #endregion
        if langfuseService != nil {
            let result = await promptBuilder.buildMessagesAsync(
                currentState: currentState,
                windowedTranscript: windowedTranscript,
                deltaTranscript: deltaTranscript,
                windowMs: windowMs
            )
            messages = result.messages
            systemPromptVersion = result.systemPromptVersion
            userPromptVersion = result.userPromptVersion
        } else {
            messages = promptBuilder.buildMessages(
                currentState: currentState,
                windowedTranscript: windowedTranscript,
                deltaTranscript: deltaTranscript,
                windowMs: windowMs
            )
        }
        
        // Set prompt metadata on TracingLLMClient before calling complete
        if let tracingClient = llmClient as? TracingLLMClient {
            await tracingClient.setPromptMetadata(
                systemPromptName: "coaching-system-prompt",
                systemPromptVersion: systemPromptVersion,
                userPromptName: "coaching-user-prompt", 
                userPromptVersion: userPromptVersion
            )
        }
        
        // Call LLM (tracing is handled by TracingLLMClient)
        let response = try await llmClient.complete(messages: messages, options: options)
        
        // Validate and parse response
        let coachingResponse = try await validateAndRepair(response)
        
        // Update state
        var newState = currentState
        newState.applyUpdates(from: coachingResponse)
        
        // Update trace with output
        if let service = langfuseService, let tid = traceId, await service.isEnabled {
            await service.updateTrace(
                traceId: tid,
                output: [
                    "stage": newState.stage?.name ?? "unknown",
                    "suggested_questions_count": newState.suggestedQuestions.count,
                    "meddic_completion": newState.meddic.completionPercentage
                ]
            )
        }
        
        lastAnalysisTime = Date()
        
        return newState
    }
    
    private func validateAndRepair(_ jsonResponse: String) async throws -> CoachingResponse {
        // First attempt: direct validation
        switch validator.validate(jsonResponse) {
        case .success(let response):
            return response
        case .failure(let error):
            // Try to extract JSON if there's extra text
            if let extractedJSON = validator.extractJSON(from: jsonResponse) {
                switch validator.validate(extractedJSON) {
                case .success(let response):
                    return response
                case .failure:
                    break
                }
            }
            
            // Attempt repair
            return try await attemptRepair(
                invalidJSON: jsonResponse,
                error: error.localizedDescription
            )
        }
    }
    
    private func attemptRepair(invalidJSON: String, error: String) async throws -> CoachingResponse {
        let repairPrompt = promptBuilder.buildRepairPrompt(invalidJSON: invalidJSON, error: error)
        
        let messages = [
            ChatMessage.system("You are a JSON repair assistant. Fix the invalid JSON to match the required schema."),
            ChatMessage.user(repairPrompt)
        ]
        
        let repairedResponse = try await llmClient.complete(messages: messages, options: options)
        
        switch validator.validate(repairedResponse) {
        case .success(let response):
            return response
        case .failure(let repairError):
            throw CoachEngineError.jsonValidationFailed(repairError.localizedDescription)
        }
    }
    
    /// Reset the engine state
    func reset() {
        lastAnalysisTime = nil
        isProcessing = false
    }
}

/// Coach engine errors
enum CoachEngineError: LocalizedError {
    case alreadyProcessing
    case jsonValidationFailed(String)
    case llmError(String)
    
    var errorDescription: String? {
        switch self {
        case .alreadyProcessing:
            return "Coach engine is already processing a request"
        case .jsonValidationFailed(let reason):
            return "JSON validation failed: \(reason)"
        case .llmError(let reason):
            return "LLM error: \(reason)"
        }
    }
}

