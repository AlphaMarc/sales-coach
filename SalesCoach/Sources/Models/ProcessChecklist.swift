import Foundation

/// User-defined process checklist for sales call stages
struct ProcessChecklist: Codable, Equatable {
    let name: String
    let stages: [ProcessStage]
    
    init(name: String, stages: [ProcessStage]) {
        self.name = name
        self.stages = stages
    }
    
    /// Default MEDDIC-based checklist
    static var defaultChecklist: ProcessChecklist {
        ProcessChecklist(
            name: "MEDDIC Sales Process",
            stages: [
                ProcessStage(
                    name: "Opening",
                    description: "Establish rapport and set agenda",
                    requiredTopics: ["introduction", "agenda", "time check"]
                ),
                ProcessStage(
                    name: "Discovery",
                    description: "Understand customer pain points and needs",
                    requiredTopics: ["current challenges", "pain points", "impact"]
                ),
                ProcessStage(
                    name: "Qualification",
                    description: "Identify decision makers and process",
                    requiredTopics: ["decision maker", "budget", "timeline"]
                ),
                ProcessStage(
                    name: "Value Proposition",
                    description: "Present solution and value",
                    requiredTopics: ["solution overview", "benefits", "differentiation"]
                ),
                ProcessStage(
                    name: "Objection Handling",
                    description: "Address concerns and objections",
                    requiredTopics: ["concerns", "competitor comparison", "risk mitigation"]
                ),
                ProcessStage(
                    name: "Closing",
                    description: "Agree on next steps and close",
                    requiredTopics: ["next steps", "timeline", "commitment"]
                )
            ]
        )
    }
    
    /// Export as JSON string for LLM prompt
    func toPromptString() -> String {
        stages.enumerated().map { index, stage in
            "\(index + 1). \(stage.name): \(stage.description) (Topics: \(stage.requiredTopics.joined(separator: ", ")))"
        }.joined(separator: "\n")
    }
}

/// Individual stage in the sales process
struct ProcessStage: Codable, Equatable, Identifiable {
    var id: String { name }
    let name: String
    let description: String
    let requiredTopics: [String]
    
    init(name: String, description: String, requiredTopics: [String]) {
        self.name = name
        self.description = description
        self.requiredTopics = requiredTopics
    }
}


