import Foundation

/// LLM client for local LM Studio server
actor LMStudioClient: LLMClient {
    private let config: LocalLLMConfig
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    init(config: LocalLLMConfig) {
        self.config = config
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 60
        sessionConfig.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: sessionConfig)
        
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }
    
    func complete(messages: [ChatMessage], options: CompletionOptions) async throws -> String {
        let url = try buildURL(path: "/chat/completions")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Note: Local LLM servers (LM Studio, Ollama, etc.) often don't support
        // OpenAI's response_format parameter. We rely on the system prompt to
        // instruct the model to return JSON instead.
        let body = ChatCompletionRequest(
            model: config.modelName,
            messages: messages,
            temperature: options.temperature,
            maxTokens: options.maxTokens,
            responseFormat: nil  // Don't send response_format for local LLMs
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
        let url = try buildURL(path: "/models")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            
            // LM Studio returns 200 for models endpoint
            if httpResponse.statusCode == 200 {
                // Try to parse response to verify it's valid
                let _ = try? decoder.decode(ModelsResponse.self, from: data)
                return true
            }
            
            return false
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
}

