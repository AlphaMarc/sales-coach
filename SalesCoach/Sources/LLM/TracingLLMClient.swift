import Foundation

/// Decorator that wraps an LLMClient and adds Langfuse tracing
actor TracingLLMClient: LLMClient {
    private let wrapped: any LLMClient
    private let langfuseService: LangfuseService?
    private let modelName: String
    
    // Prompt metadata for current generation (set before calling complete)
    private var currentPromptName: String?
    private var currentPromptVersion: Int?
    
    /// Create a tracing wrapper around an existing LLM client
    /// - Parameters:
    ///   - client: The LLM client to wrap
    ///   - langfuseService: Optional Langfuse service for tracing (if nil, tracing is disabled)
    ///   - modelName: The model name to log with generations
    init(
        wrapping client: any LLMClient,
        langfuseService: LangfuseService?,
        modelName: String
    ) {
        self.wrapped = client
        self.langfuseService = langfuseService
        self.modelName = modelName
    }
    
    /// Set prompt metadata for the next generation call
    /// This links the generation to the Langfuse prompt for tracking
    func setPromptMetadata(systemPromptName: String?, systemPromptVersion: Int?, userPromptName: String?, userPromptVersion: Int?) {
        // Use the user prompt as the primary prompt reference (it's the one that changes with each call)
        // Fall back to system prompt if no user prompt
        self.currentPromptName = userPromptName ?? systemPromptName
        self.currentPromptVersion = userPromptVersion ?? systemPromptVersion
    }
    
    /// Clear prompt metadata after use
    private func clearPromptMetadata() {
        currentPromptName = nil
        currentPromptVersion = nil
    }
    
    /// Complete a chat conversation with tracing
    func complete(messages: [ChatMessage], options: CompletionOptions) async throws -> String {
        // Start generation tracking
        if let service = langfuseService, await service.isEnabled {
            // Get or create trace ID
            var traceId = await service.getCurrentTraceId()
            if traceId == nil {
                traceId = await service.createTrace(name: "llm-completion")
            }
            let effectiveTraceId = traceId!
            
            // Capture prompt metadata before clearing
            let promptName = currentPromptName
            let promptVersion = currentPromptVersion
            clearPromptMetadata()
            
            var builder = await service.startGeneration(
                name: "chat-completion",
                traceId: effectiveTraceId,
                model: modelName,
                modelParameters: [
                    "temperature": options.temperature,
                    "max_tokens": options.maxTokens,
                    "json_mode": options.jsonMode
                ],
                input: messages.map { ["role": $0.role, "content": $0.content] },
                promptName: promptName,
                promptVersion: promptVersion
            )
            
            do {
                // Execute the actual LLM call
                let response = try await wrapped.complete(messages: messages, options: options)
                let endTime = Date()
                
                // Log successful completion
                builder.endTime = endTime
                builder.output = AnyCodable(response)
                builder.level = "DEFAULT"
                
                // Estimate tokens (rough approximation)
                let inputTokens = estimateTokens(messages.map { $0.content }.joined(separator: " "))
                let outputTokens = estimateTokens(response)
                builder.promptTokens = inputTokens
                builder.completionTokens = outputTokens
                builder.totalTokens = inputTokens + outputTokens
                
                await service.logGeneration(builder)
                
                // Record generation in session statistics
                await service.recordGeneration(promptTokens: inputTokens, completionTokens: outputTokens)
                
                return response
            } catch {
                let endTime = Date()
                
                // Log failed completion
                builder.endTime = endTime
                builder.level = "ERROR"
                builder.statusMessage = error.localizedDescription
                
                await service.logGeneration(builder)
                
                throw error
            }
        } else {
            // No tracing, just pass through
            return try await wrapped.complete(messages: messages, options: options)
        }
    }
    
    /// Test the connection to the LLM (delegated to wrapped client)
    func testConnection() async throws -> Bool {
        try await wrapped.testConnection()
    }
    
    // MARK: - Helpers
    
    /// Rough token estimation (approximately 4 characters per token for English)
    private func estimateTokens(_ text: String) -> Int {
        max(1, text.count / 4)
    }
}

// MARK: - Factory Extension

extension TracingLLMClient {
    /// Create a tracing LLM client from settings
    /// - Parameters:
    ///   - settings: App settings containing LLM configuration
    ///   - langfuseService: Optional Langfuse service for tracing
    /// - Returns: A tracing-enabled LLM client
    static func create(
        from settings: AppSettings,
        apiKey: String?,
        langfuseService: LangfuseService?
    ) -> TracingLLMClient {
        let baseClient: any LLMClient
        let modelName: String
        
        switch settings.llmMode {
        case .local:
            baseClient = LMStudioClient(config: settings.localLLMConfig)
            modelName = settings.localLLMConfig.modelName ?? "local-model"
        case .cloud:
            baseClient = OpenAICompatibleClient(
                config: settings.cloudLLMConfig,
                apiKey: apiKey ?? ""
            )
            modelName = settings.cloudLLMConfig.modelName
        }
        
        return TracingLLMClient(
            wrapping: baseClient,
            langfuseService: langfuseService,
            modelName: modelName
        )
    }
}

