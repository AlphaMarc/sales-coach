import SwiftUI

@main
struct SalesCoachApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appState)
                .frame(minWidth: 1200, minHeight: 700)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
            
            CommandMenu("Session") {
                Button("New Session") {
                    appState.startNewSession()
                }
                .keyboardShortcut("n", modifiers: [.command])
                .disabled(appState.isRecording)
                
                Button(appState.isRecording ? "Stop Recording" : "Start Recording") {
                    if appState.isRecording {
                        appState.stopRecording()
                    } else {
                        appState.startRecording()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command])
                
                Divider()
                
                Button("Export Transcript...") {
                    appState.showExportDialog = true
                }
                .keyboardShortcut("e", modifiers: [.command])
                .disabled(appState.transcriptBuffer.isEmpty)
            }
        }
        
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}


