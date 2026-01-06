import Foundation

/// Rolling buffer that manages transcript segments with windowing capabilities
struct TranscriptBuffer: Equatable {
    private(set) var segments: [TranscriptSegment] = []
    private(set) var partialText: String = ""
    
    /// Maximum number of segments to retain in memory
    private let maxSegments: Int
    
    init(maxSegments: Int = 1000) {
        self.maxSegments = maxSegments
    }
    
    /// Full concatenated text of all segments
    var fullText: String {
        segments.map { $0.text }.joined(separator: " ")
    }
    
    /// Total duration of all segments in milliseconds
    var totalDurationMs: Int64 {
        guard let first = segments.first, let last = segments.last else { return 0 }
        return last.endMs - first.startMs
    }
    
    /// Whether there's any content (segments or partial)
    var isEmpty: Bool {
        segments.isEmpty && partialText.isEmpty
    }
    
    /// Add a finalized segment
    mutating func addSegment(_ segment: TranscriptSegment) {
        segments.append(segment)
        partialText = ""
        
        // Trim old segments if exceeding max
        if segments.count > maxSegments {
            segments.removeFirst(segments.count - maxSegments)
        }
    }
    
    /// Update partial (in-progress) text
    mutating func updatePartial(_ text: String) {
        partialText = text
    }
    
    /// Clear partial text
    mutating func clearPartial() {
        partialText = ""
    }
    
    /// Get transcript text from the last N milliseconds
    func windowedText(lastMs: Int64) -> String {
        guard let latestEnd = segments.last?.endMs else { return "" }
        let cutoff = latestEnd - lastMs
        
        let windowedSegments = segments.filter { $0.endMs > cutoff }
        return windowedSegments.map { $0.text }.joined(separator: " ")
    }
    
    /// Get segments added since a specific date
    func segmentsSince(_ date: Date) -> [TranscriptSegment] {
        segments.filter { $0.createdAt > date }
    }
    
    /// Get delta text (new segments since a date)
    func deltaText(since date: Date) -> String {
        segmentsSince(date).map { $0.text }.joined(separator: " ")
    }
    
    /// Clear all segments and partial text
    mutating func clear() {
        segments.removeAll()
        partialText = ""
    }
    
    /// Export all segments as JSON
    func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(segments)
    }
    
    /// Export as plain text with timestamps
    func exportPlainText() -> String {
        segments.map { segment in
            "[\(segment.formattedTimestamp)] \(segment.speaker): \(segment.text)"
        }.joined(separator: "\n")
    }
}


