import SwiftUI

// #region agent log
private let debugLogPath = "/Users/mallaire/Documents/sales-assistant/.cursor/debug.log"
private func debugLog(_ location: String, _ message: String, _ data: [String: Any] = [:], hypothesis: String = "") {
    let entry: [String: Any] = ["timestamp": Date().timeIntervalSince1970 * 1000, "location": location, "message": message, "data": data, "hypothesisId": hypothesis, "sessionId": "debug-session"]
    if let jsonData = try? JSONSerialization.data(withJSONObject: entry), let jsonString = String(data: jsonData, encoding: .utf8) {
        if let handle = FileHandle(forWritingAtPath: debugLogPath) {
            handle.seekToEndOfFile()
            handle.write((jsonString + "\n").data(using: .utf8)!)
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: debugLogPath, contents: (jsonString + "\n").data(using: .utf8))
        }
    }
}
// #endregion

/// Main application view with split layout
struct MainView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingSettings = false
    
    var body: some View {
        NavigationSplitView {
            // Left sidebar - Transcript
            TranscriptView()
                .frame(minWidth: 400)
        } detail: {
            // Right panel - Coaching
            CoachingPanelView()
                .frame(minWidth: 350)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                toolbarContent
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .frame(minWidth: 500, minHeight: 400)
        }
        .alert("Error", isPresented: .init(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )) {
            Button("OK") { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "")
        }
        // #region agent log
        .onAppear {
            debugLog("MainView.swift:onAppear", "MainView appeared", ["connectionStatus": appState.connectionStatus.displayText], hypothesis: "H2")
        }
        // #endregion
        .task {
            // #region agent log
            debugLog("MainView.swift:task", "Starting automatic connection test on launch", ["currentStatus": appState.connectionStatus.displayText], hypothesis: "H1-FIX")
            // #endregion
            
            // Automatically test LLM connection on app launch
            await appState.testLLMConnection()
            
            // #region agent log
            debugLog("MainView.swift:task", "Automatic connection test completed", ["newStatus": appState.connectionStatus.displayText], hypothesis: "H1-FIX")
            // #endregion
        }
        .focusEffectDisabled()
    }
    
    @ViewBuilder
    private var toolbarContent: some View {
        // Connection status
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(appState.connectionStatus.displayText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        
        Divider()
        
        // Recording controls
        SessionControlBar()
        
        Divider()
        
        // Settings button
        Button {
            showingSettings = true
        } label: {
            Image(systemName: "gear")
        }
        .keyboardShortcut(",", modifiers: .command)
    }
    
    private var statusColor: Color {
        switch appState.connectionStatus {
        case .connected: return .green
        case .connecting: return .orange
        case .error: return .red
        case .idle: return .gray
        }
    }
}

#Preview {
    MainView()
        .environmentObject(AppState())
}

