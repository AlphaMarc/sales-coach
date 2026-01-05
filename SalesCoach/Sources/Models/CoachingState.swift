import Foundation

/// Complete coaching state updated by the LLM
struct CoachingState: Codable, Equatable {
    var stage: StageInfo?
    var suggestedQuestions: [SuggestedQuestion]
    var meddic: MEDDICData
    var lastUpdated: Date?
    
    init(
        stage: StageInfo? = nil,
        suggestedQuestions: [SuggestedQuestion] = [],
        meddic: MEDDICData = MEDDICData(),
        lastUpdated: Date? = nil
    ) {
        self.stage = stage
        self.suggestedQuestions = suggestedQuestions
        self.meddic = meddic
        self.lastUpdated = lastUpdated
    }
    
    /// Merge updates from LLM response
    mutating func applyUpdates(from response: CoachingResponse) {
        if let newStage = response.stage {
            self.stage = newStage
        }
        
        // Replace suggested questions
        self.suggestedQuestions = response.suggestedQuestions
        
        // Merge MEDDIC updates
        self.meddic.merge(with: response.meddicUpdates)
        
        self.lastUpdated = Date()
    }
}

/// Information about the current sales stage
struct StageInfo: Codable, Equatable {
    let name: String
    let confidence: Double  // 0-1
    let rationale: String
    
    init(name: String, confidence: Double, rationale: String) {
        self.name = name
        self.confidence = max(0, min(1, confidence))
        self.rationale = rationale
    }
}

/// LLM response structure matching the expected JSON schema
struct CoachingResponse: Codable {
    let stage: StageInfo?
    let suggestedQuestions: [SuggestedQuestion]
    let meddicUpdates: MEDDICData
    
    enum CodingKeys: String, CodingKey {
        case stage
        case suggestedQuestions = "suggested_questions"
        case meddicUpdates = "meddic_updates"
    }
}

