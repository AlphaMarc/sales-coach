import XCTest
@testable import SalesCoach

final class PromptBuilderTests: XCTestCase {
    
    let builder = PromptBuilder()
    
    func testSystemPromptContainsSchema() {
        let prompt = builder.buildSystemPrompt()
        
        XCTAssertTrue(prompt.contains("stage"))
        XCTAssertTrue(prompt.contains("suggested_questions"))
        XCTAssertTrue(prompt.contains("meddic_updates"))
        XCTAssertTrue(prompt.contains("confidence"))
    }
    
    func testSystemPromptContainsChecklist() {
        let prompt = builder.buildSystemPrompt()
        
        XCTAssertTrue(prompt.contains("Opening"))
        XCTAssertTrue(prompt.contains("Discovery"))
        XCTAssertTrue(prompt.contains("Closing"))
    }
    
    func testUserPromptContainsTranscript() {
        let state = CoachingState()
        let prompt = builder.buildUserPrompt(
            currentState: state,
            windowedTranscript: "Hello, this is a test",
            deltaTranscript: "New content here",
            windowMs: 60000
        )
        
        XCTAssertTrue(prompt.contains("Hello, this is a test"))
        XCTAssertTrue(prompt.contains("New content here"))
        XCTAssertTrue(prompt.contains("60 seconds"))
    }
    
    func testUserPromptWithEmptyTranscript() {
        let state = CoachingState()
        let prompt = builder.buildUserPrompt(
            currentState: state,
            windowedTranscript: "",
            deltaTranscript: "",
            windowMs: 60000
        )
        
        XCTAssertTrue(prompt.contains("[No transcript yet]"))
        XCTAssertTrue(prompt.contains("[No new content]"))
    }
    
    func testBuildMessages() {
        let state = CoachingState()
        let messages = builder.buildMessages(
            currentState: state,
            windowedTranscript: "Test transcript",
            deltaTranscript: "Delta text",
            windowMs: 60000
        )
        
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].role, "system")
        XCTAssertEqual(messages[1].role, "user")
    }
    
    func testRepairPrompt() {
        let repairPrompt = builder.buildRepairPrompt(
            invalidJSON: "{ bad json }",
            error: "Unexpected token"
        )
        
        XCTAssertTrue(repairPrompt.contains("invalid JSON"))
        XCTAssertTrue(repairPrompt.contains("Unexpected token"))
        XCTAssertTrue(repairPrompt.contains("bad json"))
    }
    
    func testCustomChecklist() {
        let customChecklist = ProcessChecklist(
            name: "Custom Process",
            stages: [
                ProcessStage(name: "Intro", description: "Start", requiredTopics: ["greeting"]),
                ProcessStage(name: "Demo", description: "Show product", requiredTopics: ["features"])
            ]
        )
        
        let builder = PromptBuilder(checklist: customChecklist)
        let prompt = builder.buildSystemPrompt()
        
        XCTAssertTrue(prompt.contains("Intro"))
        XCTAssertTrue(prompt.contains("Demo"))
        XCTAssertTrue(prompt.contains("greeting"))
        XCTAssertTrue(prompt.contains("features"))
    }
}

