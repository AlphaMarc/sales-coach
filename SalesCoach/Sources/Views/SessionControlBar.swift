import SwiftUI

/// Session control bar for recording controls
struct SessionControlBar: View {
    @EnvironmentObject private var appState: AppState
    @State private var showNewSessionConfirmation = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Recording duration
            if appState.isRecording {
                HStack(spacing: 6) {
                    // Recording indicator
                    Circle()
                        .fill(appState.isPaused ? .orange : .red)
                        .frame(width: 8, height: 8)
                        .opacity(appState.isPaused ? 1 : pulsingOpacity)
                    
                    Text(appState.formattedRecordingDuration)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // Main control buttons
            if !appState.isRecording {
                // New Session button
                Button {
                    if appState.transcriptBuffer.isEmpty && appState.coachingState.meddic.filledCount == 0 {
                        // Nothing to lose, just start fresh
                        appState.startNewSession()
                    } else {
                        showNewSessionConfirmation = true
                    }
                } label: {
                    Label("New", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)
                .confirmationDialog(
                    "Start New Session?",
                    isPresented: $showNewSessionConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Start New Session", role: .destructive) {
                        appState.startNewSession()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This will clear the current transcript and coaching data. This action cannot be undone.")
                }
                
                // Start button
                Button {
                    appState.startRecording()
                } label: {
                    Label("Start", systemImage: "record.circle")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                // Pause/Resume button
                Button {
                    if appState.isPaused {
                        appState.resumeRecording()
                    } else {
                        appState.pauseRecording()
                    }
                } label: {
                    Label(
                        appState.isPaused ? "Resume" : "Pause",
                        systemImage: appState.isPaused ? "play.fill" : "pause.fill"
                    )
                }
                .buttonStyle(.bordered)
                
                // Stop button
                Button {
                    appState.stopRecording()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            
            // Cloud mode warning
            if appState.settings.llmMode == .cloud && appState.isRecording {
                HStack(spacing: 4) {
                    Image(systemName: "icloud.fill")
                        .foregroundStyle(.blue)
                    Text("Cloud")
                        .font(.caption)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.blue.opacity(0.1))
                .clipShape(Capsule())
                .help("Transcript is being sent to cloud API")
            }
        }
    }
    
    @State private var pulsingOpacity: Double = 1.0
    
    private var pulsingAnimation: Animation {
        Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)
    }
}

/// Standalone recording button for menu bar
struct RecordingButton: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        Button {
            if appState.isRecording {
                appState.stopRecording()
            } else {
                appState.startRecording()
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(appState.isRecording ? .red : .gray)
                    .frame(width: 10, height: 10)
                
                Text(appState.isRecording ? "Stop" : "Record")
            }
        }
    }
}

#Preview {
    HStack {
        SessionControlBar()
    }
    .padding()
    .environmentObject(AppState())
}

