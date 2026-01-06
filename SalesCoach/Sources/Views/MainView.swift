import SwiftUI

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
        .task {
            // Automatically test LLM connection on app launch
            await appState.testLLMConnection()
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
        .padding(.horizontal, 8)
        
        // Recording controls
        SessionControlBar()
        
        // Settings button
        Button {
            showingSettings = true
        } label: {
            Image(systemName: "gear")
        }
        .padding(.horizontal, 8)
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

