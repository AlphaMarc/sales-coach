import Foundation

/// Protocol for LLM clients (local and cloud)
protocol LLMClient: Actor {
    /// Complete a chat conversation
    func complete(messages: [ChatMessage], options: CompletionOptions) async throws -> String
    
    /// Test the connection to the LLM
    func testConnection() async throws -> Bool
}

/// Chat message structure
struct ChatMessage: Codable, Equatable {
    let role: String  // "system", "user", "assistant"
    let content: String
    
    static func system(_ content: String) -> ChatMessage {
        ChatMessage(role: "system", content: content)
    }
    
    static func user(_ content: String) -> ChatMessage {
        ChatMessage(role: "user", content: content)
    }
    
    static func assistant(_ content: String) -> ChatMessage {
        ChatMessage(role: "assistant", content: content)
    }
}

/// Completion options for LLM requests
struct CompletionOptions {
    let temperature: Double
    let maxTokens: Int
    let jsonMode: Bool
    
    init(temperature: Double = 0.3, maxTokens: Int = 1024, jsonMode: Bool = false) {
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.jsonMode = jsonMode
    }
    
    static var `default`: CompletionOptions { CompletionOptions() }
    
    static var json: CompletionOptions {
        CompletionOptions(jsonMode: true)
    }
}

/// Errors that can occur during LLM operations
enum LLMError: LocalizedError {
    case connectionFailed(String)
    case invalidResponse
    case requestFailed(Int, String)
    case timeout
    case invalidJSON(String)
    case apiKeyMissing
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .invalidResponse:
            return "Invalid response from LLM"
        case .requestFailed(let code, let message):
            return "Request failed (\(code)): \(message)"
        case .timeout:
            return "Request timed out"
        case .invalidJSON(let reason):
            return "Invalid JSON: \(reason)"
        case .apiKeyMissing:
            return "API key is missing"
        }
    }
}

// MARK: - OpenAI-Compatible Request/Response Models

struct ChatCompletionRequest: Codable {
    let model: String?
    let messages: [ChatMessage]
    let temperature: Double
    let maxTokens: Int
    let responseFormat: ResponseFormat?
    
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
        case responseFormat = "response_format"
    }
}

struct ResponseFormat: Codable {
    let type: String
    
    static var json: ResponseFormat {
        ResponseFormat(type: "json_object")
    }
}

struct ChatCompletionResponse: Codable {
    let id: String?
    let choices: [Choice]
    let usage: Usage?
    
    struct Choice: Codable {
        let index: Int
        let message: ChatMessage
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }
    }
    
    struct Usage: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

struct ModelsResponse: Codable {
    let data: [ModelInfo]
    
    struct ModelInfo: Codable {
        let id: String
    }
}

