import Foundation

/// LLM client for cloud OpenAI-compatible APIs
actor OpenAICompatibleClient: LLMClient {
    private let config: CloudLLMConfig
    private let apiKey: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    private var retryCount = 0
    private let maxRetries = 3
    
    init(config: CloudLLMConfig, apiKey: String) {
        self.config = config
        self.apiKey = apiKey
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 60
        sessionConfig.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: sessionConfig)
        
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }
    
    func complete(messages: [ChatMessage], options: CompletionOptions) async throws -> String {
        guard !apiKey.isEmpty else {
            throw LLMError.apiKeyMissing
        }
        
        return try await executeWithRetry {
            try await self.performCompletion(messages: messages, options: options)
        }
    }
    
    private func performCompletion(messages: [ChatMessage], options: CompletionOptions) async throws -> String {
        let url = try buildURL(path: "/chat/completions")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body = ChatCompletionRequest(
            model: config.modelName,
            messages: messages,
            temperature: options.temperature,
            maxTokens: options.maxTokens,
            responseFormat: options.jsonMode ? .json : nil
        )
        
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.requestFailed(httpResponse.statusCode, errorMessage)
        }
        
        let completionResponse = try decoder.decode(ChatCompletionResponse.self, from: data)
        
        guard let firstChoice = completionResponse.choices.first else {
            throw LLMError.invalidResponse
        }
        
        return firstChoice.message.content
    }
    
    func testConnection() async throws -> Bool {
        guard !apiKey.isEmpty else {
            throw LLMError.apiKeyMissing
        }
        
        let url = try buildURL(path: "/models")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        
        do {
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            
            return httpResponse.statusCode == 200
        } catch {
            throw LLMError.connectionFailed(error.localizedDescription)
        }
    }
    
    private func buildURL(path: String) throws -> URL {
        guard let url = URL(string: config.baseURL + path) else {
            throw LLMError.connectionFailed("Invalid base URL: \(config.baseURL)")
        }
        return url
    }
    
    private func executeWithRetry<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                return try await operation()
            } catch let error as LLMError {
                lastError = error
                
                // Don't retry for certain errors
                switch error {
                case .apiKeyMissing, .invalidJSON:
                    throw error
                case .requestFailed(let code, _) where code == 401 || code == 403:
                    throw error
                default:
                    break
                }
                
                // Exponential backoff
                if attempt < maxRetries - 1 {
                    let delay = pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            } catch {
                lastError = error
                
                if attempt < maxRetries - 1 {
                    let delay = pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? LLMError.connectionFailed("Unknown error after retries")
    }
}

