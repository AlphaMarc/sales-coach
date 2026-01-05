import Foundation

// MARK: - Langfuse Configuration

/// Configuration for Langfuse observability
struct LangfuseConfig: Codable, Equatable {
    var isEnabled: Bool
    var baseURL: String
    
    init(
        isEnabled: Bool = false,
        baseURL: String = "https://cloud.langfuse.com"
    ) {
        self.isEnabled = isEnabled
        self.baseURL = baseURL
    }
    
    static var `default`: LangfuseConfig { LangfuseConfig() }
}

// MARK: - Ingestion API Models

/// Batch ingestion request for traces and generations
struct LangfuseIngestionRequest: Codable {
    let batch: [LangfuseIngestionEvent]
    let metadata: LangfuseMetadata?
    
    init(batch: [LangfuseIngestionEvent], metadata: LangfuseMetadata? = nil) {
        self.batch = batch
        self.metadata = metadata
    }
}

/// Metadata for SDK identification
struct LangfuseMetadata: Codable {
    let sdkName: String
    let sdkVersion: String
    let publicKey: String
    
    enum CodingKeys: String, CodingKey {
        case sdkName = "sdk_name"
        case sdkVersion = "sdk_version"
        case publicKey = "public_key"
    }
    
    static var swiftSDK: LangfuseMetadata {
        LangfuseMetadata(
            sdkName: "langfuse-swift",
            sdkVersion: "1.0.0",
            publicKey: ""
        )
    }
    
    func with(publicKey: String) -> LangfuseMetadata {
        LangfuseMetadata(sdkName: sdkName, sdkVersion: sdkVersion, publicKey: publicKey)
    }
}

/// Wrapper for ingestion events
struct LangfuseIngestionEvent: Codable {
    let id: String
    let type: LangfuseEventType
    let timestamp: String
    let body: LangfuseEventBody
    
    init(type: LangfuseEventType, body: LangfuseEventBody) {
        self.id = UUID().uuidString
        self.type = type
        self.timestamp = ISO8601DateFormatter().string(from: Date())
        self.body = body
    }
}

/// Event types for ingestion
enum LangfuseEventType: String, Codable {
    case traceCreate = "trace-create"
    case generationCreate = "generation-create"
    case generationUpdate = "generation-update"
    case spanCreate = "span-create"
    case spanUpdate = "span-update"
    case eventCreate = "event-create"
}

/// Event body - can contain different payloads
struct LangfuseEventBody: Codable {
    // Common fields
    let id: String
    let traceId: String?
    let name: String?
    let startTime: String?
    let endTime: String?
    let metadata: [String: AnyCodable]?
    
    // Trace-specific
    let sessionId: String?
    let userId: String?
    let tags: [String]?
    let input: AnyCodable?
    let output: AnyCodable?
    
    // Generation-specific
    let model: String?
    let modelParameters: [String: AnyCodable]?
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?
    let level: String?
    let statusMessage: String?
    let parentObservationId: String?
    let promptName: String?
    let promptVersion: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case traceId = "trace_id"
        case name
        case startTime = "start_time"
        case endTime = "end_time"
        case metadata
        case sessionId = "session_id"
        case userId = "user_id"
        case tags
        case input
        case output
        case model
        case modelParameters = "model_parameters"
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
        case level
        case statusMessage = "status_message"
        case parentObservationId = "parent_observation_id"
        case promptName = "prompt_name"
        case promptVersion = "prompt_version"
    }
}

/// Ingestion response
struct LangfuseIngestionResponse: Codable {
    let successes: [LangfuseIngestionSuccess]?
    let errors: [LangfuseIngestionError]?
}

struct LangfuseIngestionSuccess: Codable {
    let id: String
    let status: Int
}

struct LangfuseIngestionError: Codable {
    let id: String
    let status: Int
    let message: String?
    let error: String?
}

// MARK: - Prompt API Models

/// Response for fetching a prompt
struct LangfusePromptResponse: Codable {
    let name: String
    let version: Int
    let prompt: String?
    let config: [String: AnyCodable]?
    let labels: [String]?
    let tags: [String]?
    
    /// For chat prompts, the prompt field contains JSON array of messages
    var chatMessages: [LangfusePromptMessage]? {
        guard let promptString = prompt,
              let data = promptString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([LangfusePromptMessage].self, from: data)
    }
}

/// Message structure in chat prompts
struct LangfusePromptMessage: Codable {
    let role: String
    let content: String
}

/// Cached prompt with TTL
/// Default TTL is set to effectively infinite (max double value) to cache for entire app session
struct CachedPrompt {
    let prompt: LangfusePromptResponse
    let fetchedAt: Date
    let ttl: TimeInterval
    
    var isExpired: Bool {
        Date().timeIntervalSince(fetchedAt) > ttl
    }
    
    /// Initialize with prompt response
    /// - Parameters:
    ///   - prompt: The Langfuse prompt response to cache
    ///   - ttl: Time-to-live in seconds. Defaults to max value (cache for entire app session)
    init(prompt: LangfusePromptResponse, ttl: TimeInterval = .greatestFiniteMagnitude) {
        self.prompt = prompt
        self.fetchedAt = Date()
        self.ttl = ttl
    }
}

// MARK: - Trace Builder

/// Builder for creating trace events
struct LangfuseTraceBuilder {
    let id: String
    let sessionId: String?
    let name: String
    let userId: String?
    let tags: [String]
    let metadata: [String: AnyCodable]
    let input: AnyCodable?
    
    init(
        id: String = UUID().uuidString,
        sessionId: String? = nil,
        name: String,
        userId: String? = nil,
        tags: [String] = [],
        metadata: [String: AnyCodable] = [:],
        input: AnyCodable? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.name = name
        self.userId = userId
        self.tags = tags
        self.metadata = metadata
        self.input = input
    }
    
    func build() -> LangfuseIngestionEvent {
        let body = LangfuseEventBody(
            id: id,
            traceId: nil,
            name: name,
            startTime: ISO8601DateFormatter().string(from: Date()),
            endTime: nil,
            metadata: metadata.isEmpty ? nil : metadata,
            sessionId: sessionId,
            userId: userId,
            tags: tags.isEmpty ? nil : tags,
            input: input,
            output: nil,
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
        return LangfuseIngestionEvent(type: .traceCreate, body: body)
    }
}

// MARK: - Generation Builder

/// Builder for creating generation events
struct LangfuseGenerationBuilder {
    let id: String
    let traceId: String
    let name: String
    let startTime: Date
    var endTime: Date?
    let model: String?
    let modelParameters: [String: AnyCodable]
    let input: AnyCodable?
    var output: AnyCodable?
    var promptTokens: Int?
    var completionTokens: Int?
    var totalTokens: Int?
    var level: String?
    var statusMessage: String?
    let promptName: String?
    let promptVersion: Int?
    let metadata: [String: AnyCodable]
    
    init(
        id: String = UUID().uuidString,
        traceId: String,
        name: String,
        startTime: Date = Date(),
        model: String? = nil,
        modelParameters: [String: AnyCodable] = [:],
        input: AnyCodable? = nil,
        promptName: String? = nil,
        promptVersion: Int? = nil,
        metadata: [String: AnyCodable] = [:]
    ) {
        self.id = id
        self.traceId = traceId
        self.name = name
        self.startTime = startTime
        self.model = model
        self.modelParameters = modelParameters
        self.input = input
        self.promptName = promptName
        self.promptVersion = promptVersion
        self.metadata = metadata
    }
    
    func buildCreate() -> LangfuseIngestionEvent {
        let formatter = ISO8601DateFormatter()
        let body = LangfuseEventBody(
            id: id,
            traceId: traceId,
            name: name,
            startTime: formatter.string(from: startTime),
            endTime: endTime.map { formatter.string(from: $0) },
            metadata: metadata.isEmpty ? nil : metadata,
            sessionId: nil,
            userId: nil,
            tags: nil,
            input: input,
            output: output,
            model: model,
            modelParameters: modelParameters.isEmpty ? nil : modelParameters,
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            totalTokens: totalTokens,
            level: level,
            statusMessage: statusMessage,
            parentObservationId: nil,
            promptName: promptName,
            promptVersion: promptVersion
        )
        return LangfuseIngestionEvent(type: .generationCreate, body: body)
    }
    
    func buildUpdate() -> LangfuseIngestionEvent {
        let formatter = ISO8601DateFormatter()
        let body = LangfuseEventBody(
            id: id,
            traceId: traceId,
            name: nil,
            startTime: nil,
            endTime: endTime.map { formatter.string(from: $0) },
            metadata: nil,
            sessionId: nil,
            userId: nil,
            tags: nil,
            input: nil,
            output: output,
            model: nil,
            modelParameters: nil,
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            totalTokens: totalTokens,
            level: level,
            statusMessage: statusMessage,
            parentObservationId: nil,
            promptName: nil,
            promptVersion: nil
        )
        return LangfuseIngestionEvent(type: .generationUpdate, body: body)
    }
}

// MARK: - AnyCodable Helper

/// Type-erased Codable wrapper for dynamic JSON values
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable cannot decode value")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "AnyCodable cannot encode value"))
        }
    }
}

// MARK: - Langfuse Errors

/// Errors that can occur during Langfuse operations
enum LangfuseError: LocalizedError {
    case notConfigured
    case invalidCredentials
    case networkError(String)
    case invalidResponse
    case promptNotFound(String)
    case ingestionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Langfuse is not configured"
        case .invalidCredentials:
            return "Invalid Langfuse credentials"
        case .networkError(let reason):
            return "Network error: \(reason)"
        case .invalidResponse:
            return "Invalid response from Langfuse"
        case .promptNotFound(let name):
            return "Prompt not found: \(name)"
        case .ingestionFailed(let reason):
            return "Ingestion failed: \(reason)"
        }
    }
}

