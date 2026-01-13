import Foundation

/// Complete session data for persistence
struct SessionData: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    var endedAt: Date?
    var transcript: [TranscriptSegment]
    var coachingState: CoachingState
    var settings: AppSettings
    
    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        endedAt: Date? = nil,
        transcript: [TranscriptSegment] = [],
        coachingState: CoachingState = CoachingState(),
        settings: AppSettings = .default
    ) {
        self.id = id
        self.createdAt = createdAt
        self.endedAt = endedAt
        self.transcript = transcript
        self.coachingState = coachingState
        self.settings = settings
    }
    
    /// Duration of the session in seconds
    var durationSeconds: Int {
        let end = endedAt ?? Date()
        return Int(end.timeIntervalSince(createdAt))
    }
    
    /// Formatted duration string
    var formattedDuration: String {
        let seconds = durationSeconds
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
    
    /// Session metadata for list display
    var metadata: SessionMetadata {
        SessionMetadata(
            id: id,
            createdAt: createdAt,
            endedAt: endedAt,
            segmentCount: transcript.count,
            meddicCompletion: coachingState.meddic.completionPercentage
        )
    }
}

/// Lightweight session metadata for listing
struct SessionMetadata: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let endedAt: Date?
    let segmentCount: Int
    let meddicCompletion: Double
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}

/// Export format options
enum ExportFormat: String, CaseIterable {
    case json
    case plainText
    case csv
    
    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .plainText: return "txt"
        case .csv: return "csv"
        }
    }
    
    var displayName: String {
        switch self {
        case .json: return "JSON"
        case .plainText: return "Plain Text"
        case .csv: return "CSV"
        }
    }
}




