import Foundation

/// Represents a single segment of transcribed speech
struct TranscriptSegment: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let startMs: Int64
    let endMs: Int64
    let speaker: String  // "Speaker A", "Speaker B", or "Unknown"
    let isFinal: Bool
    let createdAt: Date
    
    init(
        id: UUID = UUID(),
        text: String,
        startMs: Int64,
        endMs: Int64,
        speaker: String = "Unknown",
        isFinal: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.startMs = startMs
        self.endMs = endMs
        self.speaker = speaker
        self.isFinal = isFinal
        self.createdAt = createdAt
    }
    
    /// Duration of this segment in milliseconds
    var durationMs: Int64 {
        endMs - startMs
    }
    
    /// Formatted timestamp string (MM:SS)
    var formattedTimestamp: String {
        let seconds = Int(startMs / 1000)
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

/// Events emitted by the transcription pipeline
enum TranscriptEvent {
    case partial(text: String)
    case final(segment: TranscriptSegment)
    case error(Error)
}

