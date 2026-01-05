import Foundation

/// Application settings
struct AppSettings: Codable, Equatable {
    var llmMode: LLMMode
    var localLLMConfig: LocalLLMConfig
    var cloudLLMConfig: CloudLLMConfig
    var langfuseConfig: LangfuseConfig
    var tickIntervalSeconds: Int
    var selectedAudioDeviceID: String?
    var transcriptionLanguage: TranscriptionLanguage
    var transcriptWindowMs: Int64
    var processChecklist: ProcessChecklist
    
    init(
        llmMode: LLMMode = .local,
        localLLMConfig: LocalLLMConfig = .default,
        cloudLLMConfig: CloudLLMConfig = .default,
        langfuseConfig: LangfuseConfig = .default,
        tickIntervalSeconds: Int = 7,
        selectedAudioDeviceID: String? = nil,
        transcriptionLanguage: TranscriptionLanguage = .auto,
        transcriptWindowMs: Int64 = 60000,
        processChecklist: ProcessChecklist = .defaultChecklist
    ) {
        self.llmMode = llmMode
        self.localLLMConfig = localLLMConfig
        self.cloudLLMConfig = cloudLLMConfig
        self.langfuseConfig = langfuseConfig
        self.tickIntervalSeconds = tickIntervalSeconds
        self.selectedAudioDeviceID = selectedAudioDeviceID
        self.transcriptionLanguage = transcriptionLanguage
        self.transcriptWindowMs = transcriptWindowMs
        self.processChecklist = processChecklist
    }
    
    static var `default`: AppSettings { AppSettings() }
}

/// Transcription language selection
enum TranscriptionLanguage: String, Codable, CaseIterable {
    case auto
    case english = "en"
    case french = "fr"
    
    var displayName: String {
        switch self {
        case .auto: return "Auto-detect"
        case .english: return "English"
        case .french: return "Français"
        }
    }
    
    /// The language code to pass to Whisper CLI
    var whisperCode: String {
        rawValue
    }
}

/// LLM mode selection
enum LLMMode: String, Codable, CaseIterable {
    case local
    case cloud
    
    var displayName: String {
        switch self {
        case .local: return "Local (LM Studio)"
        case .cloud: return "Cloud (API)"
        }
    }
}

/// Configuration for local LM Studio
struct LocalLLMConfig: Codable, Equatable {
    var baseURL: String
    var modelName: String?
    var temperature: Double
    var maxTokens: Int
    
    init(
        baseURL: String = "http://localhost:1234/v1",
        modelName: String? = nil,
        temperature: Double = 0.3,
        maxTokens: Int = 1024
    ) {
        self.baseURL = baseURL
        self.modelName = modelName
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
    
    static var `default`: LocalLLMConfig { LocalLLMConfig() }
}

/// Configuration for cloud LLM (OpenAI-compatible)
struct CloudLLMConfig: Codable, Equatable {
    var baseURL: String
    var modelName: String
    var temperature: Double
    var maxTokens: Int
    // Note: API key stored separately in Keychain
    
    init(
        baseURL: String = "https://api.openai.com/v1",
        modelName: String = "gpt-4",
        temperature: Double = 0.3,
        maxTokens: Int = 1024
    ) {
        self.baseURL = baseURL
        self.modelName = modelName
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
    
    static var `default`: CloudLLMConfig { CloudLLMConfig() }
}

/// Connection status for LLM backends
enum ConnectionStatus: Equatable {
    case idle
    case connecting
    case connected
    case error(String)
    
    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
    
    var displayText: String {
        switch self {
        case .idle: return "Not Connected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .error(let message): return "Error: \(message)"
        }
    }
}

