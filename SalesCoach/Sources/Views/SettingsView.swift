import SwiftUI

/// Settings view for app configuration
struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            TabView(selection: $selectedTab) {
                LLMSettingsTab()
                    .tabItem {
                        Label("LLM", systemImage: "cpu")
                    }
                    .tag(0)
                
                AudioSettingsTab()
                    .tabItem {
                        Label("Audio", systemImage: "waveform")
                    }
                    .tag(1)
                
                CoachingSettingsTab()
                    .tabItem {
                        Label("Coaching", systemImage: "sparkles")
                    }
                    .tag(2)
                
                ObservabilitySettingsTab()
                    .tabItem {
                        Label("Observability", systemImage: "chart.bar.xaxis")
                    }
                    .tag(3)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

// MARK: - LLM Settings Tab

struct LLMSettingsTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var apiKey: String = ""
    @State private var isTestingConnection = false
    @State private var testResult: TestResult?
    
    enum TestResult {
        case success
        case failure(String)
    }
    
    var body: some View {
        Form {
            // Mode selection
            Section {
                Picker("LLM Mode", selection: $appState.settings.llmMode) {
                    ForEach(LLMMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Mode")
            }
            
            // Local settings
            if appState.settings.llmMode == .local {
                Section {
                    TextField("Base URL", text: $appState.settings.localLLMConfig.baseURL)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Model Name (optional)", text: Binding(
                        get: { appState.settings.localLLMConfig.modelName ?? "" },
                        set: { appState.settings.localLLMConfig.modelName = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    
                    HStack {
                        Text("Temperature")
                        Slider(value: $appState.settings.localLLMConfig.temperature, in: 0...1, step: 0.1)
                        Text(String(format: "%.1f", appState.settings.localLLMConfig.temperature))
                            .frame(width: 30)
                    }
                    
                    Stepper(
                        "Max Tokens: \(appState.settings.localLLMConfig.maxTokens)",
                        value: $appState.settings.localLLMConfig.maxTokens,
                        in: 256...4096,
                        step: 256
                    )
                } header: {
                    Text("Local LM Studio")
                } footer: {
                    Text("Make sure LM Studio is running with a model loaded.")
                }
            }
            
            // Cloud settings
            if appState.settings.llmMode == .cloud {
                Section {
                    TextField("Base URL", text: $appState.settings.cloudLLMConfig.baseURL)
                        .textFieldStyle(.roundedBorder)
                    
                    SecureField("API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .onAppear {
                            apiKey = KeychainService.shared.getAPIKey() ?? ""
                        }
                        .onChange(of: apiKey) { _, newValue in
                            _ = KeychainService.shared.setAPIKey(newValue)
                        }
                    
                    TextField("Model Name", text: $appState.settings.cloudLLMConfig.modelName)
                        .textFieldStyle(.roundedBorder)
                    
                    HStack {
                        Text("Temperature")
                        Slider(value: $appState.settings.cloudLLMConfig.temperature, in: 0...1, step: 0.1)
                        Text(String(format: "%.1f", appState.settings.cloudLLMConfig.temperature))
                            .frame(width: 30)
                    }
                    
                    Stepper(
                        "Max Tokens: \(appState.settings.cloudLLMConfig.maxTokens)",
                        value: $appState.settings.cloudLLMConfig.maxTokens,
                        in: 256...4096,
                        step: 256
                    )
                } header: {
                    Text("Cloud API (OpenAI-compatible)")
                } footer: {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Transcript text will be sent to the cloud API.")
                    }
                }
            }
            
            // Test connection
            Section {
                HStack {
                    Button {
                        testConnection()
                    } label: {
                        if isTestingConnection {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Text("Test Connection")
                        }
                    }
                    .disabled(isTestingConnection)
                    
                    Spacer()
                    
                    if let result = testResult {
                        switch result {
                        case .success:
                            Label("Connected", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        case .failure(let error):
                            Label(error, systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
    
    private func testConnection() {
        isTestingConnection = true
        testResult = nil
        
        Task {
            await appState.testLLMConnection()
            
            await MainActor.run {
                isTestingConnection = false
                
                switch appState.connectionStatus {
                case .connected:
                    testResult = .success
                case .error(let message):
                    testResult = .failure(message)
                default:
                    testResult = .failure("Unknown status")
                }
            }
        }
    }
}

// MARK: - Audio Settings Tab

struct AudioSettingsTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var devices: [AudioDevice] = []
    
    var body: some View {
        Form {
            Section {
                Picker("Input Device", selection: $appState.settings.selectedAudioDeviceID) {
                    Text("System Default").tag(nil as String?)
                    
                    ForEach(devices) { device in
                        Text(device.name).tag(device.id as String?)
                    }
                }
                
                Button("Refresh Devices") {
                    refreshDevices()
                }
            } header: {
                Text("Microphone")
            } footer: {
                Text("Select the microphone to use for recording.")
            }
            
            Section {
                Picker("Transcription Language", selection: $appState.settings.transcriptionLanguage) {
                    ForEach(TranscriptionLanguage.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
            } header: {
                Text("Language")
            } footer: {
                Text("Select the language for speech recognition. Auto-detect works for multilingual conversations.")
            }
            
            Section {
                HStack {
                    Text("Audio Format")
                    Spacer()
                    Text("16kHz, Mono, 16-bit PCM")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Chunk Duration")
                    Spacer()
                    Text("3 seconds")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Technical Details")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            refreshDevices()
        }
    }
    
    private func refreshDevices() {
        devices = AudioCaptureService.availableInputDevices
    }
}

// MARK: - Coaching Settings Tab

struct CoachingSettingsTab: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        Form {
            Section {
                Stepper(
                    "Analysis Interval: \(appState.settings.tickIntervalSeconds)s",
                    value: $appState.settings.tickIntervalSeconds,
                    in: 3...15
                )
                
                HStack {
                    Text("Transcript Window")
                    Spacer()
                    Picker("", selection: $appState.settings.transcriptWindowMs) {
                        Text("30 seconds").tag(Int64(30000))
                        Text("60 seconds").tag(Int64(60000))
                        Text("90 seconds").tag(Int64(90000))
                        Text("120 seconds").tag(Int64(120000))
                    }
                    .frame(width: 150)
                }
            } header: {
                Text("Timing")
            } footer: {
                Text("How often to analyze the transcript and how much context to include.")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Checklist: \(appState.settings.processChecklist.name)")
                        .font(.headline)
                    
                    ForEach(Array(appState.settings.processChecklist.stages.enumerated()), id: \.element.id) { index, stage in
                        HStack {
                            Text("\(index + 1).")
                                .foregroundStyle(.secondary)
                            Text(stage.name)
                            Spacer()
                            Text(stage.requiredTopics.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                
                Button("Reset to Default") {
                    appState.settings.processChecklist = .defaultChecklist
                }
            } header: {
                Text("Process Checklist")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Observability Settings Tab

struct ObservabilitySettingsTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var publicKey: String = ""
    @State private var secretKey: String = ""
    @State private var showSecretKey: Bool = false
    
    var body: some View {
        Form {
            Section {
                Toggle("Enable Langfuse", isOn: $appState.settings.langfuseConfig.isEnabled)
                    .onChange(of: appState.settings.langfuseConfig.isEnabled) { _, _ in
                        appState.configureLangfuse()
                    }
            } header: {
                Text("Langfuse Observability")
            } footer: {
                Text("Track LLM calls, sessions, and manage prompts with Langfuse.")
            }
            
            if appState.settings.langfuseConfig.isEnabled {
                Section {
                    TextField("Base URL", text: $appState.settings.langfuseConfig.baseURL)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Public Key", text: $publicKey)
                        .textFieldStyle(.roundedBorder)
                        .onAppear {
                            publicKey = KeychainService.shared.getLangfusePublicKey() ?? ""
                        }
                        .onChange(of: publicKey) { _, newValue in
                            _ = KeychainService.shared.setLangfusePublicKey(newValue)
                            appState.configureLangfuse()
                        }
                    
                    HStack {
                        if showSecretKey {
                            TextField("Secret Key", text: $secretKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("Secret Key", text: $secretKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Button {
                            showSecretKey.toggle()
                        } label: {
                            Image(systemName: showSecretKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.plain)
                    }
                    .onAppear {
                        secretKey = KeychainService.shared.getLangfuseSecretKey() ?? ""
                    }
                    .onChange(of: secretKey) { _, newValue in
                        _ = KeychainService.shared.setLangfuseSecretKey(newValue)
                        appState.configureLangfuse()
                    }
                } header: {
                    Text("Connection")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Get your API keys from your Langfuse project settings.")
                        Link("Open Langfuse Dashboard", destination: URL(string: "https://cloud.langfuse.com")!)
                            .font(.caption)
                    }
                }
                
                Section {
                    HStack {
                        Image(systemName: appState.isLangfuseConfigured ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(appState.isLangfuseConfigured ? .green : .red)
                        
                        Text(appState.isLangfuseConfigured ? "Configured" : "Missing API keys")
                        
                        Spacer()
                    }
                } header: {
                    Text("Status")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Execution Traces", systemImage: "arrow.triangle.branch")
                        Text("Track each LLM call with input, output, latency, and token usage.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Sessions", systemImage: "rectangle.stack")
                        Text("Group traces by coaching session for better analysis.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Prompt Management", systemImage: "text.quote")
                        Text("Manage and version your prompts in Langfuse, with automatic fallback to local prompts.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Features")
                }
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}

