import Foundation

/// Service for interacting with Langfuse observability platform
actor LangfuseService {
    // MARK: - Properties
    
    private let config: LangfuseConfig
    private let publicKey: String
    private let secretKey: String
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    // Batching
    private var eventQueue: [LangfuseIngestionEvent] = []
    private var flushTask: Task<Void, Never>?
    private let maxBatchSize = 50
    private let flushIntervalSeconds: TimeInterval = 5.0
    
    // Prompt cache
    private var promptCache: [String: CachedPrompt] = [:]
    
    // Current session/trace context
    private var currentSessionId: String?
    private var currentTraceId: String?
    private var sessionStartTime: Date?
    
    // Session statistics
    private var sessionStats = SessionStats()
    
    // MARK: - Initialization
    
    init(config: LangfuseConfig, publicKey: String, secretKey: String) {
        self.config = config
        self.publicKey = publicKey
        self.secretKey = secretKey
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30
        sessionConfig.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: sessionConfig)
        
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.sortedKeys]
        
        self.decoder = JSONDecoder()
        
        startFlushTimer()
    }
    
    deinit {
        flushTask?.cancel()
    }
    
    // MARK: - Public API
    
    /// Check if Langfuse is enabled and configured
    var isEnabled: Bool {
        config.isEnabled && !publicKey.isEmpty && !secretKey.isEmpty
    }
    
    /// Set the current session ID for all subsequent traces
    func setSessionId(_ sessionId: String?) {
        currentSessionId = sessionId
        if sessionId != nil {
            sessionStartTime = Date()
            sessionStats = SessionStats()
        }
    }
    
    /// Get the current session ID
    func getSessionId() -> String? {
        currentSessionId
    }
    
    /// Get current session statistics
    func getSessionStats() -> SessionStats {
        sessionStats
    }
    
    /// Get session duration in seconds
    func getSessionDuration() -> TimeInterval? {
        guard let startTime = sessionStartTime else { return nil }
        return Date().timeIntervalSince(startTime)
    }
    
    /// Record an LLM generation for session statistics
    func recordGeneration(promptTokens: Int, completionTokens: Int) {
        sessionStats.llmCallCount += 1
        sessionStats.totalPromptTokens += promptTokens
        sessionStats.totalCompletionTokens += completionTokens
    }
    
    /// Record a coaching tick for session statistics
    func recordCoachingTick() {
        sessionStats.coachingTickCount += 1
    }
    
    /// End the current session and create a session-end trace
    func endSession(metadata: [String: Any] = [:]) -> String? {
        guard let sessionId = currentSessionId else { return nil }
        
        var sessionMetadata = metadata
        
        // Add session statistics
        if let duration = getSessionDuration() {
            sessionMetadata["session_duration_seconds"] = Int(duration)
        }
        sessionMetadata["llm_call_count"] = sessionStats.llmCallCount
        sessionMetadata["coaching_tick_count"] = sessionStats.coachingTickCount
        sessionMetadata["total_prompt_tokens"] = sessionStats.totalPromptTokens
        sessionMetadata["total_completion_tokens"] = sessionStats.totalCompletionTokens
        sessionMetadata["total_tokens"] = sessionStats.totalPromptTokens + sessionStats.totalCompletionTokens
        
        // Create session end trace
        let traceId = createTrace(
            name: "sales-coaching-session-end",
            tags: ["session-end"],
            metadata: sessionMetadata
        )
        
        // Clear session state
        currentSessionId = nil
        sessionStartTime = nil
        sessionStats = SessionStats()
        
        return traceId
    }
    
    /// Create a new trace and return its ID
    func createTrace(
        name: String,
        userId: String? = nil,
        tags: [String] = [],
        metadata: [String: Any] = [:],
        input: Any? = nil
    ) -> String {
        let traceId = UUID().uuidString
        currentTraceId = traceId
        
        let trace = LangfuseTraceBuilder(
            id: traceId,
            sessionId: currentSessionId,
            name: name,
            userId: userId,
            tags: tags,
            metadata: metadata.mapValues { AnyCodable($0) },
            input: input.map { AnyCodable($0) }
        )
        
        enqueue(trace.build())
        return traceId
    }
    
    /// Get the current trace ID
    func getCurrentTraceId() -> String? {
        currentTraceId
    }
    
    /// Update an existing trace with output data
    func updateTrace(
        traceId: String,
        output: Any? = nil,
        metadata: [String: Any]? = nil
    ) {
        var updateBody: [String: Any] = ["id": traceId]
        
        if let output = output {
            updateBody["output"] = output
        }
        if let metadata = metadata {
            updateBody["metadata"] = metadata
        }
        
        // Build update event body
        let body = LangfuseEventBody(
            id: traceId,
            traceId: nil,
            name: nil,
            startTime: nil,
            endTime: nil,
            metadata: metadata?.mapValues { AnyCodable($0) },
            sessionId: nil,
            userId: nil,
            tags: nil,
            input: nil,
            output: output.map { AnyCodable($0) },
            model: nil,
            modelParameters: nil,
            promptTokens: nil,
            completionTokens: nil,
            totalTokens: nil,
            level: nil,
            statusMessage: nil,
            parentObservationId: nil,
            promptName: nil,
            promptVersion: nil
        )
        
        // Note: Langfuse doesn't have a trace-update event, but we can use trace-create 
        // with the same ID which will merge/update the trace
        enqueue(LangfuseIngestionEvent(type: .traceCreate, body: body))
    }
    
    /// Log a generation (LLM call) start
    func startGeneration(
        name: String,
        traceId: String? = nil,
        model: String? = nil,
        modelParameters: [String: Any] = [:],
        input: Any? = nil,
        promptName: String? = nil,
        promptVersion: Int? = nil,
        metadata: [String: Any] = [:]
    ) -> LangfuseGenerationBuilder {
        let effectiveTraceId = traceId ?? currentTraceId ?? createTrace(name: "auto-trace")
        
        return LangfuseGenerationBuilder(
            traceId: effectiveTraceId,
            name: name,
            model: model,
            modelParameters: modelParameters.mapValues { AnyCodable($0) },
            input: input.map { AnyCodable($0) },
            promptName: promptName,
            promptVersion: promptVersion,
            metadata: metadata.mapValues { AnyCodable($0) }
        )
    }
    
    /// Log a completed generation
    func logGeneration(_ builder: LangfuseGenerationBuilder) {
        enqueue(builder.buildCreate())
    }
    
    /// Update a generation with completion data
    func updateGeneration(
        id: String,
        traceId: String,
        output: Any?,
        endTime: Date = Date(),
        promptTokens: Int? = nil,
        completionTokens: Int? = nil,
        totalTokens: Int? = nil,
        level: String? = nil,
        statusMessage: String? = nil
    ) {
        var builder = LangfuseGenerationBuilder(
            id: id,
            traceId: traceId,
            name: ""
        )
        builder.endTime = endTime
        builder.output = output.map { AnyCodable($0) }
        builder.promptTokens = promptTokens
        builder.completionTokens = completionTokens
        builder.totalTokens = totalTokens
        builder.level = level
        builder.statusMessage = statusMessage
        
        enqueue(builder.buildUpdate())
    }
    
    /// Fetch a prompt from Langfuse
    func getPrompt(
        name: String,
        version: Int? = nil,
        label: String? = nil,
        useCache: Bool = true
    ) async throws -> LangfusePromptResponse {
        guard isEnabled else {
            throw LangfuseError.notConfigured
        }
        
        // Check cache
        let cacheKey = "\(name):\(version ?? -1):\(label ?? "")"
        if useCache, let cached = promptCache[cacheKey], !cached.isExpired {
            // #region agent log
            let debugLogPath = "/Users/mallaire/Documents/sales-assistant/.cursor/debug.log"
            let logEntryCacheHit = "{\"location\":\"LangfuseService.swift:getPrompt\",\"message\":\"CACHE HIT - returning cached prompt\",\"data\":{\"promptName\":\"\(name)\",\"version\":\(cached.prompt.version)},\"timestamp\":\(Int(Date().timeIntervalSince1970 * 1000)),\"sessionId\":\"debug-session\",\"hypothesisId\":\"CACHE\"}\n"
            if let dataHit = logEntryCacheHit.data(using: .utf8), let handleHit = FileHandle(forWritingAtPath: debugLogPath) {
                handleHit.seekToEndOfFile()
                handleHit.write(dataHit)
                handleHit.closeFile()
            } else if let dataHit = logEntryCacheHit.data(using: .utf8) {
                FileManager.default.createFile(atPath: debugLogPath, contents: dataHit, attributes: nil)
            }
            // #endregion
            return cached.prompt
        }
        
        // #region agent log
        let debugLogPath = "/Users/mallaire/Documents/sales-assistant/.cursor/debug.log"
        let logEntryCacheMiss = "{\"location\":\"LangfuseService.swift:getPrompt\",\"message\":\"CACHE MISS - fetching from Langfuse\",\"data\":{\"promptName\":\"\(name)\"},\"timestamp\":\(Int(Date().timeIntervalSince1970 * 1000)),\"sessionId\":\"debug-session\",\"hypothesisId\":\"CACHE\"}\n"
        if let dataMiss = logEntryCacheMiss.data(using: .utf8), let handleMiss = FileHandle(forWritingAtPath: debugLogPath) {
            handleMiss.seekToEndOfFile()
            handleMiss.write(dataMiss)
            handleMiss.closeFile()
        } else if let dataMiss = logEntryCacheMiss.data(using: .utf8) {
            FileManager.default.createFile(atPath: debugLogPath, contents: dataMiss, attributes: nil)
        }
        // #endregion
        
        // Build URL
        var urlComponents = URLComponents(string: "\(config.baseURL)/api/public/v2/prompts/\(name)")!
        var queryItems: [URLQueryItem] = []
        if let version = version {
            queryItems.append(URLQueryItem(name: "version", value: String(version)))
        }
        if let label = label {
            queryItems.append(URLQueryItem(name: "label", value: label))
        }
        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }
        
        guard let url = urlComponents.url else {
            throw LangfuseError.networkError("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addAuthHeaders(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LangfuseError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            let prompt = try decoder.decode(LangfusePromptResponse.self, from: data)
            promptCache[cacheKey] = CachedPrompt(prompt: prompt)
            return prompt
        case 401, 403:
            throw LangfuseError.invalidCredentials
        case 404:
            throw LangfuseError.promptNotFound(name)
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LangfuseError.networkError("HTTP \(httpResponse.statusCode): \(message)")
        }
    }
    
    /// Force flush all pending events
    func flush() async {
        guard !eventQueue.isEmpty else { return }
        
        let events = eventQueue
        eventQueue = []
        
        await sendBatch(events)
    }
    
    /// Shutdown the service, flushing any pending events
    func shutdown() async {
        flushTask?.cancel()
        await flush()
    }
    
    // MARK: - Private Methods
    
    private func enqueue(_ event: LangfuseIngestionEvent) {
        eventQueue.append(event)
        
        if eventQueue.count >= maxBatchSize {
            Task {
                await flush()
            }
        }
    }
    
    private func startFlushTimer() {
        flushTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(5.0 * 1_000_000_000))
                await self?.flush()
            }
        }
    }
    
    private func sendBatch(_ events: [LangfuseIngestionEvent]) async {
        guard !events.isEmpty, isEnabled else { return }
        
        // #region agent log
        let debugLogPath = "/Users/mallaire/Documents/sales-assistant/.cursor/debug.log"
        let logEntryStart = "{\"location\":\"LangfuseService.swift:sendBatch\",\"message\":\"sendBatch starting\",\"data\":{\"eventCount\":\(events.count)},\"timestamp\":\(Int(Date().timeIntervalSince1970 * 1000)),\"sessionId\":\"debug-session\",\"hypothesisId\":\"H10\"}\n"
        if let dataStart = logEntryStart.data(using: .utf8), let handleStart = FileHandle(forWritingAtPath: debugLogPath) {
            handleStart.seekToEndOfFile()
            handleStart.write(dataStart)
            handleStart.closeFile()
        } else if let dataStart = logEntryStart.data(using: .utf8) {
            FileManager.default.createFile(atPath: debugLogPath, contents: dataStart, attributes: nil)
        }
        // #endregion
        
        do {
            let url = URL(string: "\(config.baseURL)/api/public/ingestion")!
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            addAuthHeaders(to: &request)
            
            let ingestionRequest = LangfuseIngestionRequest(
                batch: events,
                metadata: LangfuseMetadata.swiftSDK.with(publicKey: publicKey)
            )
            
            request.httpBody = try encoder.encode(ingestionRequest)
            
            // #region agent log
            let logEntryEncoded = "{\"location\":\"LangfuseService.swift:sendBatch\",\"message\":\"encoded successfully\",\"data\":{\"bodySize\":\(request.httpBody?.count ?? 0)},\"timestamp\":\(Int(Date().timeIntervalSince1970 * 1000)),\"sessionId\":\"debug-session\",\"hypothesisId\":\"H10\"}\n"
            if let dataEnc = logEntryEncoded.data(using: .utf8), let handleEnc = FileHandle(forWritingAtPath: debugLogPath) {
                handleEnc.seekToEndOfFile()
                handleEnc.write(dataEnc)
                handleEnc.closeFile()
            }
            // #endregion
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else { return }
            
            // #region agent log
            let logEntryResp = "{\"location\":\"LangfuseService.swift:sendBatch\",\"message\":\"response received\",\"data\":{\"statusCode\":\(httpResponse.statusCode)},\"timestamp\":\(Int(Date().timeIntervalSince1970 * 1000)),\"sessionId\":\"debug-session\",\"hypothesisId\":\"H10\"}\n"
            if let dataResp = logEntryResp.data(using: .utf8), let handleResp = FileHandle(forWritingAtPath: debugLogPath) {
                handleResp.seekToEndOfFile()
                handleResp.write(dataResp)
                handleResp.closeFile()
            }
            // #endregion
            
            if httpResponse.statusCode != 200 && httpResponse.statusCode != 207 {
                let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("[Langfuse] Ingestion failed: HTTP \(httpResponse.statusCode) - \(message)")
            }
        } catch let encodingError as EncodingError {
            // Encoding errors - DO NOT re-queue, these events have unencodable data types
            var errorDetail = "unknown"
            if case .invalidValue(let value, let context) = encodingError {
                errorDetail = "type=\(type(of: value)), path=\(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
            }
            // #region agent log
            let logEntryEncodingErr = "{\"location\":\"LangfuseService.swift:sendBatch\",\"message\":\"ENCODING ERROR - dropping events\",\"data\":{\"eventCount\":\(events.count),\"detail\":\"\(errorDetail)\"},\"timestamp\":\(Int(Date().timeIntervalSince1970 * 1000)),\"sessionId\":\"debug-session\",\"hypothesisId\":\"H11\"}\n"
            if let dataErr = logEntryEncodingErr.data(using: .utf8), let handleErr = FileHandle(forWritingAtPath: debugLogPath) {
                handleErr.seekToEndOfFile()
                handleErr.write(dataErr)
                handleErr.closeFile()
            }
            // #endregion
            print("[Langfuse] Encoding error - dropping \(events.count) events: \(errorDetail)")
            // DO NOT re-queue encoding errors - they will never succeed
        } catch {
            // Network errors - re-queue for retry
            // #region agent log
            let errorMsg = error.localizedDescription.replacingOccurrences(of: "\"", with: "'")
            let logEntryNetErr = "{\"location\":\"LangfuseService.swift:sendBatch\",\"message\":\"network error - requeuing\",\"data\":{\"error\":\"\(errorMsg)\"},\"timestamp\":\(Int(Date().timeIntervalSince1970 * 1000)),\"sessionId\":\"debug-session\",\"hypothesisId\":\"H10\"}\n"
            if let dataNetErr = logEntryNetErr.data(using: .utf8), let handleNetErr = FileHandle(forWritingAtPath: debugLogPath) {
                handleNetErr.seekToEndOfFile()
                handleNetErr.write(dataNetErr)
                handleNetErr.closeFile()
            }
            // #endregion
            print("[Langfuse] Failed to send batch: \(error.localizedDescription)")
            // Re-queue events on network failure only (with limit to prevent infinite growth)
            if eventQueue.count < maxBatchSize * 3 {
                eventQueue.insert(contentsOf: events, at: 0)
            }
        }
    }
    
    private func addAuthHeaders(to request: inout URLRequest) {
        let credentials = "\(publicKey):\(secretKey)"
        if let credentialsData = credentials.data(using: .utf8) {
            let base64Credentials = credentialsData.base64EncodedString()
            request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        }
    }
}

// MARK: - Shared Instance

extension LangfuseService {
    /// Shared instance - must be configured before use
    private static var _shared: LangfuseService?
    
    /// Get the shared instance
    static var shared: LangfuseService? {
        _shared
    }
    
    /// Configure the shared instance
    static func configure(config: LangfuseConfig, publicKey: String, secretKey: String) {
        _shared = LangfuseService(config: config, publicKey: publicKey, secretKey: secretKey)
    }
    
    /// Reset the shared instance
    static func reset() async {
        await _shared?.shutdown()
        _shared = nil
    }
}

// MARK: - Session Statistics

/// Statistics tracked during a Langfuse session
struct SessionStats {
    var llmCallCount: Int = 0
    var coachingTickCount: Int = 0
    var totalPromptTokens: Int = 0
    var totalCompletionTokens: Int = 0
    
    var totalTokens: Int {
        totalPromptTokens + totalCompletionTokens
    }
}

