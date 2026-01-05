import Foundation

/// Suggested question from the coaching engine
struct SuggestedQuestion: Identifiable, Codable, Equatable {
    let id: UUID
    let question: String
    let why: String
    let priority: Int  // 1-3 (1 = highest priority)
    
    init(
        id: UUID = UUID(),
        question: String,
        why: String,
        priority: Int
    ) {
        self.id = id
        self.question = question
        self.why = why
        self.priority = max(1, min(3, priority))
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case question
        case why
        case priority
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.question = try container.decode(String.self, forKey: .question)
        // Use defaults for optional fields that LLM may omit
        self.why = try container.decodeIfPresent(String.self, forKey: .why) ?? ""
        let rawPriority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 2
        self.priority = max(1, min(3, rawPriority))
    }
    
    /// Priority display string
    var priorityDisplay: String {
        switch priority {
        case 1: return "High"
        case 2: return "Medium"
        case 3: return "Low"
        default: return "Normal"
        }
    }
    
    /// Priority color name for SwiftUI
    var priorityColorName: String {
        switch priority {
        case 1: return "red"
        case 2: return "orange"
        case 3: return "blue"
        default: return "gray"
        }
    }
}

