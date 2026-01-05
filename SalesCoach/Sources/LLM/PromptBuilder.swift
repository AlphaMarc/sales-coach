import Foundation

/// Builds prompts for the coaching LLM with optional Langfuse prompt management
struct PromptBuilder {
    private let checklist: ProcessChecklist
    private let langfuseService: LangfuseService?
    
    // Prompt names in Langfuse
    private static let systemPromptName = "coaching-system-prompt"
    private static let userPromptName = "coaching-user-prompt"
    private static let repairPromptName = "coaching-repair-prompt"
    
    init(
        checklist: ProcessChecklist = .defaultChecklist,
        langfuseService: LangfuseService? = nil
    ) {
        self.checklist = checklist
        self.langfuseService = langfuseService
    }
    
    // MARK: - Async Methods (with Langfuse support)
    
    /// Build the system prompt, optionally fetching from Langfuse
    func buildSystemPromptAsync() async -> (prompt: String, version: Int?) {
        // #region agent log
        let debugLogPath = "/Users/mallaire/Documents/sales-assistant/.cursor/debug.log"
        let h4_serviceNil = langfuseService == nil
        var h4_isEnabled = false
        if let svc = langfuseService {
            h4_isEnabled = await svc.isEnabled
        }
        let logEntry4 = "{\"location\":\"PromptBuilder.swift:24\",\"message\":\"H4: buildSystemPromptAsync entry\",\"data\":{\"serviceNil\":\(h4_serviceNil),\"isEnabled\":\(h4_isEnabled)},\"timestamp\":\(Int(Date().timeIntervalSince1970 * 1000)),\"sessionId\":\"debug-session\",\"hypothesisId\":\"H4\"}\n"
        if let data4 = logEntry4.data(using: .utf8), let handle4 = FileHandle(forWritingAtPath: debugLogPath) {
            handle4.seekToEndOfFile()
            handle4.write(data4)
            handle4.closeFile()
        } else if let data4 = logEntry4.data(using: .utf8) {
            FileManager.default.createFile(atPath: debugLogPath, contents: data4, attributes: nil)
        }
        // #endregion
        // Try Langfuse first if available
        if let service = langfuseService, await service.isEnabled {
            do {
                // #region agent log
                let logEntry5a = "{\"location\":\"PromptBuilder.swift:28\",\"message\":\"H5: attempting getPrompt for system\",\"data\":{\"promptName\":\"\(Self.systemPromptName)\"},\"timestamp\":\(Int(Date().timeIntervalSince1970 * 1000)),\"sessionId\":\"debug-session\",\"hypothesisId\":\"H5\"}\n"
                if let data5a = logEntry5a.data(using: .utf8), let handle5a = FileHandle(forWritingAtPath: debugLogPath) {
                    handle5a.seekToEndOfFile()
                    handle5a.write(data5a)
                    handle5a.closeFile()
                }
                // #endregion
                let langfusePrompt = try await service.getPrompt(name: Self.systemPromptName)
                // #region agent log
                let hasPrompt = langfusePrompt.prompt != nil
                let logEntry5b = "{\"location\":\"PromptBuilder.swift:33\",\"message\":\"H5: getPrompt success for system\",\"data\":{\"hasPrompt\":\(hasPrompt),\"version\":\(langfusePrompt.version ?? -1)},\"timestamp\":\(Int(Date().timeIntervalSince1970 * 1000)),\"sessionId\":\"debug-session\",\"hypothesisId\":\"H5\"}\n"
                if let data5b = logEntry5b.data(using: .utf8), let handle5b = FileHandle(forWritingAtPath: debugLogPath) {
                    handle5b.seekToEndOfFile()
                    handle5b.write(data5b)
                    handle5b.closeFile()
                }
                // #endregion
                if let promptContent = langfusePrompt.prompt {
                    // Replace template variables
                    let filledPrompt = promptContent
                        .replacingOccurrences(of: "{{checklist}}", with: checklist.toPromptString())
                    return (filledPrompt, langfusePrompt.version)
                }
            } catch {
                // #region agent log
                let errorMsg = error.localizedDescription.replacingOccurrences(of: "\"", with: "'")
                let logEntry5c = "{\"location\":\"PromptBuilder.swift:36\",\"message\":\"H5: getPrompt failed for system\",\"data\":{\"error\":\"\(errorMsg)\"},\"timestamp\":\(Int(Date().timeIntervalSince1970 * 1000)),\"sessionId\":\"debug-session\",\"hypothesisId\":\"H5\"}\n"
                if let data5c = logEntry5c.data(using: .utf8), let handle5c = FileHandle(forWritingAtPath: debugLogPath) {
                    handle5c.seekToEndOfFile()
                    handle5c.write(data5c)
                    handle5c.closeFile()
                }
                // #endregion
                print("[PromptBuilder] Failed to fetch system prompt from Langfuse: \(error.localizedDescription)")
            }
        }
        
        // Fall back to local prompt
        return (buildSystemPrompt(), nil)
    }
    
    /// Build the user prompt, optionally fetching template from Langfuse
    func buildUserPromptAsync(
        currentState: CoachingState,
        windowedTranscript: String,
        deltaTranscript: String,
        windowMs: Int64
    ) async -> (prompt: String, version: Int?) {
        let stateJSON = encodeStateForPrompt(currentState)
        // #region agent log
        let debugLogPath = "/Users/mallaire/Documents/sales-assistant/.cursor/debug.log"
        // #endregion
        
        // Try Langfuse first if available
        if let service = langfuseService, await service.isEnabled {
            do {
                // #region agent log
                let logEntry6a = "{\"location\":\"PromptBuilder.swift:56\",\"message\":\"H5: attempting getPrompt for user\",\"data\":{\"promptName\":\"\(Self.userPromptName)\"},\"timestamp\":\(Int(Date().timeIntervalSince1970 * 1000)),\"sessionId\":\"debug-session\",\"hypothesisId\":\"H5\"}\n"
                if let data6a = logEntry6a.data(using: .utf8), let handle6a = FileHandle(forWritingAtPath: debugLogPath) {
                    handle6a.seekToEndOfFile()
                    handle6a.write(data6a)
                    handle6a.closeFile()
                }
                // #endregion
                let langfusePrompt = try await service.getPrompt(name: Self.userPromptName)
                // #region agent log
                let hasPrompt = langfusePrompt.prompt != nil
                let logEntry6b = "{\"location\":\"PromptBuilder.swift:63\",\"message\":\"H5: getPrompt success for user\",\"data\":{\"hasPrompt\":\(hasPrompt),\"version\":\(langfusePrompt.version ?? -1)},\"timestamp\":\(Int(Date().timeIntervalSince1970 * 1000)),\"sessionId\":\"debug-session\",\"hypothesisId\":\"H5\"}\n"
                if let data6b = logEntry6b.data(using: .utf8), let handle6b = FileHandle(forWritingAtPath: debugLogPath) {
                    handle6b.seekToEndOfFile()
                    handle6b.write(data6b)
                    handle6b.closeFile()
                }
                // #endregion
                if let promptTemplate = langfusePrompt.prompt {
                    // Replace template variables
                    let filledPrompt = promptTemplate
                        .replacingOccurrences(of: "{{state}}", with: stateJSON)
                        .replacingOccurrences(of: "{{window_seconds}}", with: String(windowMs / 1000))
                        .replacingOccurrences(of: "{{windowed_transcript}}", with: windowedTranscript.isEmpty ? "[No transcript yet]" : windowedTranscript)
                        .replacingOccurrences(of: "{{delta_transcript}}", with: deltaTranscript.isEmpty ? "[No new content]" : deltaTranscript)
                    return (filledPrompt, langfusePrompt.version)
                }
            } catch {
                // #region agent log
                let errorMsg = error.localizedDescription.replacingOccurrences(of: "\"", with: "'")
                let logEntry6c = "{\"location\":\"PromptBuilder.swift:67\",\"message\":\"H5: getPrompt failed for user\",\"data\":{\"error\":\"\(errorMsg)\"},\"timestamp\":\(Int(Date().timeIntervalSince1970 * 1000)),\"sessionId\":\"debug-session\",\"hypothesisId\":\"H5\"}\n"
                if let data6c = logEntry6c.data(using: .utf8), let handle6c = FileHandle(forWritingAtPath: debugLogPath) {
                    handle6c.seekToEndOfFile()
                    handle6c.write(data6c)
                    handle6c.closeFile()
                }
                // #endregion
                print("[PromptBuilder] Failed to fetch user prompt from Langfuse: \(error.localizedDescription)")
            }
        }
        
        // Fall back to local prompt
        return (buildUserPrompt(
            currentState: currentState,
            windowedTranscript: windowedTranscript,
            deltaTranscript: deltaTranscript,
            windowMs: windowMs
        ), nil)
    }
    
    /// Build messages for a coaching request with Langfuse prompt tracking
    func buildMessagesAsync(
        currentState: CoachingState,
        windowedTranscript: String,
        deltaTranscript: String,
        windowMs: Int64
    ) async -> (messages: [ChatMessage], systemPromptVersion: Int?, userPromptVersion: Int?) {
        let (systemPrompt, systemVersion) = await buildSystemPromptAsync()
        let (userPrompt, userVersion) = await buildUserPromptAsync(
            currentState: currentState,
            windowedTranscript: windowedTranscript,
            deltaTranscript: deltaTranscript,
            windowMs: windowMs
        )
        
        return (
            [.system(systemPrompt), .user(userPrompt)],
            systemVersion,
            userVersion
        )
    }
    
    // MARK: - Synchronous Methods (local prompts only)
    
    /// Build the system prompt (local fallback)
    func buildSystemPrompt() -> String {
        """
        You are a real-time sales coaching assistant. Analyze the conversation transcript and provide structured guidance.

        You must respond with valid JSON matching this exact schema:
        {
          "stage": {"name": string, "confidence": 0-1, "rationale": string},
          "suggested_questions": [{"question": string, "why": string, "priority": 1-3}],
          "meddic_updates": {
            "metrics": {"value": string, "confidence": 0-1, "evidence": [{"quote": string, "start_ms": int, "end_ms": int}]}|null,
            "economic_buyer": {"value": string, "confidence": 0-1, "evidence": [{"quote": string, "start_ms": int, "end_ms": int}]}|null,
            "decision_criteria": {"value": string, "confidence": 0-1, "evidence": [{"quote": string, "start_ms": int, "end_ms": int}]}|null,
            "decision_process": {"value": string, "confidence": 0-1, "evidence": [{"quote": string, "start_ms": int, "end_ms": int}]}|null,
            "identify_pain": {"value": string, "confidence": 0-1, "evidence": [{"quote": string, "start_ms": int, "end_ms": int}]}|null,
            "champion": {"value": string, "confidence": 0-1, "evidence": [{"quote": string, "start_ms": int, "end_ms": int}]}|null
          }
        }

        Guidelines:
        - Only include fields that have updates (null for unchanged MEDDIC fields)
        - Confidence scores should reflect certainty based on explicit statements
        - Provide 1-3 suggested questions, prioritized by importance
        - Include exact quotes with timestamps as evidence

        Process checklist:
        \(checklist.toPromptString())
        """
    }
    
    /// Build the user prompt for a coaching tick
    func buildUserPrompt(
        currentState: CoachingState,
        windowedTranscript: String,
        deltaTranscript: String,
        windowMs: Int64
    ) -> String {
        let stateJSON = encodeStateForPrompt(currentState)
        
        return """
        Current state:
        \(stateJSON)

        Transcript context (last \(windowMs / 1000) seconds):
        \(windowedTranscript.isEmpty ? "[No transcript yet]" : windowedTranscript)

        New transcript since last analysis:
        \(deltaTranscript.isEmpty ? "[No new content]" : deltaTranscript)

        Analyze and provide updated coaching guidance. Return valid JSON only.
        """
    }
    
    /// Build a repair prompt for invalid JSON
    func buildRepairPrompt(invalidJSON: String, error: String) -> String {
        """
        The previous response was invalid JSON. Error: \(error)
        
        Invalid response:
        \(invalidJSON.prefix(500))
        
        Please return valid JSON matching the required schema. Return only the JSON object, no explanation.
        """
    }
    
    /// Build messages for a coaching request (synchronous, no Langfuse)
    func buildMessages(
        currentState: CoachingState,
        windowedTranscript: String,
        deltaTranscript: String,
        windowMs: Int64
    ) -> [ChatMessage] {
        [
            .system(buildSystemPrompt()),
            .user(buildUserPrompt(
                currentState: currentState,
                windowedTranscript: windowedTranscript,
                deltaTranscript: deltaTranscript,
                windowMs: windowMs
            ))
        ]
    }
    
    private func encodeStateForPrompt(_ state: CoachingState) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        // Create a simplified state representation
        var stateDict: [String: Any] = [:]
        
        if let stage = state.stage {
            stateDict["current_stage"] = stage.name
        }
        
        stateDict["meddic_completion"] = String(format: "%.0f%%", state.meddic.completionPercentage * 100)
        
        // Serialize to JSON-like string
        if let data = try? JSONSerialization.data(withJSONObject: stateDict, options: .prettyPrinted),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        
        return "{}"
    }
}
