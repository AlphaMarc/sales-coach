import Foundation

/// Persists application settings to UserDefaults
class SettingsStore {
    private let defaults: UserDefaults
    private let settingsKey = "com.salescoach.settings"
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }
    
    /// Load settings from storage
    func load() -> AppSettings {
        guard let data = defaults.data(forKey: settingsKey) else {
            return .default
        }
        
        do {
            return try decoder.decode(AppSettings.self, from: data)
        } catch {
            print("Failed to decode settings: \(error)")
            return .default
        }
    }
    
    /// Save settings to storage
    func save(_ settings: AppSettings) {
        do {
            let data = try encoder.encode(settings)
            defaults.set(data, forKey: settingsKey)
        } catch {
            print("Failed to encode settings: \(error)")
        }
    }
    
    /// Reset settings to defaults
    func reset() {
        defaults.removeObject(forKey: settingsKey)
    }
    
    /// Update a specific setting
    func update(_ update: (inout AppSettings) -> Void) {
        var settings = load()
        update(&settings)
        save(settings)
    }
}

// MARK: - Specific Setting Accessors

extension SettingsStore {
    var llmMode: LLMMode {
        get { load().llmMode }
        set { update { $0.llmMode = newValue } }
    }
    
    var tickIntervalSeconds: Int {
        get { load().tickIntervalSeconds }
        set { update { $0.tickIntervalSeconds = newValue } }
    }
    
    var selectedAudioDeviceID: String? {
        get { load().selectedAudioDeviceID }
        set { update { $0.selectedAudioDeviceID = newValue } }
    }
}


