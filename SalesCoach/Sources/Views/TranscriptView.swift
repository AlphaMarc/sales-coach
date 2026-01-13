import SwiftUI

/// Live transcript display view
struct TranscriptView: View {
    @EnvironmentObject private var appState: AppState
    @State private var autoScroll = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            transcriptHeader
            
            Divider()
            
            // Transcript content
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(appState.transcriptBuffer.segments) { segment in
                            TranscriptSegmentView(segment: segment)
                                .id(segment.id)
                        }
                        
                        // Partial text (in-progress)
                        if !appState.transcriptBuffer.partialText.isEmpty {
                            PartialTextView(text: appState.transcriptBuffer.partialText)
                                .id("partial")
                        }
                        
                        // Empty state
                        if appState.transcriptBuffer.isEmpty && !appState.isRecording {
                            emptyState
                        }
                        
                        // Recording indicator
                        if appState.isRecording && appState.transcriptBuffer.isEmpty {
                            listeningIndicator
                        }
                    }
                    .padding()
                }
                .onChange(of: appState.transcriptBuffer.segments.count) { _, _ in
                    if autoScroll, let lastSegment = appState.transcriptBuffer.segments.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastSegment.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    private var transcriptHeader: some View {
        HStack {
            Text("Transcript")
                .font(.headline)
            
            Spacer()
            
            // Segment count
            Text("\(appState.transcriptBuffer.segments.count) segments")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Auto-scroll toggle
            Toggle(isOn: $autoScroll) {
                Image(systemName: "arrow.down.to.line")
            }
            .toggleStyle(.button)
            .help("Auto-scroll to latest")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            
            Text("No Transcript Yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Start recording to begin transcription")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var listeningIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)
            
            Text("Listening...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

/// Individual transcript segment view
struct TranscriptSegmentView: View {
    let segment: TranscriptSegment
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timestamp
            Text(segment.formattedTimestamp)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)
            
            // Speaker badge
            Text(segment.speaker)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(speakerColor.opacity(0.2))
                .foregroundStyle(speakerColor)
                .clipShape(Capsule())
            
            // Text content
            Text(segment.text)
                .font(.body)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }
    
    private var speakerColor: Color {
        switch segment.speaker {
        case "Speaker A": return .blue
        case "Speaker B": return .green
        default: return .gray
        }
    }
}

/// Partial (in-progress) text view
struct PartialTextView: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Placeholder for timestamp
            Text("--:--")
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
                .frame(width: 50, alignment: .trailing)
            
            // Typing indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
                Circle()
                    .fill(Color.orange.opacity(0.6))
                    .frame(width: 6, height: 6)
                Circle()
                    .fill(Color.orange.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
            
            // Partial text
            Text(text)
                .font(.body)
                .italic()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TranscriptView()
        .environmentObject(AppState())
        .frame(width: 500, height: 600)
}




