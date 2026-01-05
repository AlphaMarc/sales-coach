import Foundation

/// MEDDIC framework data structure
/// Metrics, Economic Buyer, Decision Criteria, Decision Process, Identify Pain, Champion
struct MEDDICData: Codable, Equatable {
    var metrics: MEDDICField?
    var economicBuyer: MEDDICField?
    var decisionCriteria: MEDDICField?
    var decisionProcess: MEDDICField?
    var identifyPain: MEDDICField?
    var champion: MEDDICField?
    
    enum CodingKeys: String, CodingKey {
        case metrics
        case economicBuyer = "economic_buyer"
        case decisionCriteria = "decision_criteria"
        case decisionProcess = "decision_process"
        case identifyPain = "identify_pain"
        case champion
    }
    
    init(
        metrics: MEDDICField? = nil,
        economicBuyer: MEDDICField? = nil,
        decisionCriteria: MEDDICField? = nil,
        decisionProcess: MEDDICField? = nil,
        identifyPain: MEDDICField? = nil,
        champion: MEDDICField? = nil
    ) {
        self.metrics = metrics
        self.economicBuyer = economicBuyer
        self.decisionCriteria = decisionCriteria
        self.decisionProcess = decisionProcess
        self.identifyPain = identifyPain
        self.champion = champion
    }
    
    /// Merge updates from another MEDDICData, keeping higher confidence values
    mutating func merge(with other: MEDDICData) {
        metrics = mergeField(current: metrics, new: other.metrics)
        economicBuyer = mergeField(current: economicBuyer, new: other.economicBuyer)
        decisionCriteria = mergeField(current: decisionCriteria, new: other.decisionCriteria)
        decisionProcess = mergeField(current: decisionProcess, new: other.decisionProcess)
        identifyPain = mergeField(current: identifyPain, new: other.identifyPain)
        champion = mergeField(current: champion, new: other.champion)
    }
    
    private func mergeField(current: MEDDICField?, new: MEDDICField?) -> MEDDICField? {
        guard let newField = new else { return current }
        guard let currentField = current else { return newField }
        
        // Keep the field with higher confidence, or prefer new if equal
        return newField.confidence >= currentField.confidence ? newField : currentField
    }
    
    /// All fields as an array for iteration
    var allFields: [(name: String, field: MEDDICField?)] {
        [
            ("Metrics", metrics),
            ("Economic Buyer", economicBuyer),
            ("Decision Criteria", decisionCriteria),
            ("Decision Process", decisionProcess),
            ("Identify Pain", identifyPain),
            ("Champion", champion)
        ]
    }
    
    /// Count of fields that have been filled
    var filledCount: Int {
        allFields.compactMap { $0.field }.count
    }
    
    /// Overall completion percentage
    var completionPercentage: Double {
        Double(filledCount) / 6.0
    }
}

/// Individual MEDDIC field with value, confidence, and evidence
struct MEDDICField: Codable, Equatable {
    let value: String
    let confidence: Double  // 0-1
    let evidence: [EvidenceQuote]?
    
    init(value: String, confidence: Double, evidence: [EvidenceQuote]? = nil) {
        self.value = value
        self.confidence = max(0, min(1, confidence))
        self.evidence = evidence
    }
}

/// Quote from transcript supporting a MEDDIC field
struct EvidenceQuote: Codable, Equatable, Identifiable {
    var id: String { "\(startMs)-\(endMs)" }
    let quote: String
    let startMs: Int64
    let endMs: Int64
    
    enum CodingKeys: String, CodingKey {
        case quote
        case startMs = "start_ms"
        case endMs = "end_ms"
    }
    
    /// Formatted timestamp range
    var formattedRange: String {
        let startSec = Int(startMs / 1000)
        let endSec = Int(endMs / 1000)
        return "\(formatTime(startSec)) - \(formatTime(endSec))"
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

