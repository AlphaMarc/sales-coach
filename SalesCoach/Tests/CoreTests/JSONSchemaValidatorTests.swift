import XCTest
@testable import SalesCoach

final class JSONSchemaValidatorTests: XCTestCase {
    
    let validator = JSONSchemaValidator()
    
    func testValidCompleteResponse() {
        let json = """
        {
            "stage": {"name": "Discovery", "confidence": 0.85, "rationale": "Customer is describing pain points"},
            "suggested_questions": [
                {"question": "What is your timeline?", "why": "Need to understand urgency", "priority": 1}
            ],
            "meddic_updates": {
                "metrics": null,
                "economic_buyer": null,
                "decision_criteria": null,
                "decision_process": null,
                "identify_pain": {"value": "Manual data entry", "confidence": 0.9, "evidence": []},
                "champion": null
            }
        }
        """
        
        let result = validator.validate(json)
        
        switch result {
        case .success(let response):
            XCTAssertEqual(response.stage?.name, "Discovery")
            XCTAssertEqual(response.stage?.confidence, 0.85)
            XCTAssertEqual(response.suggestedQuestions.count, 1)
            XCTAssertNotNil(response.meddicUpdates.identifyPain)
        case .failure(let error):
            XCTFail("Validation should succeed: \(error)")
        }
    }
    
    func testValidMinimalResponse() {
        let json = """
        {
            "stage": null,
            "suggested_questions": [],
            "meddic_updates": {
                "metrics": null,
                "economic_buyer": null,
                "decision_criteria": null,
                "decision_process": null,
                "identify_pain": null,
                "champion": null
            }
        }
        """
        
        let result = validator.validate(json)
        
        switch result {
        case .success(let response):
            XCTAssertNil(response.stage)
            XCTAssertTrue(response.suggestedQuestions.isEmpty)
        case .failure(let error):
            XCTFail("Validation should succeed: \(error)")
        }
    }
    
    func testInvalidJSON() {
        let json = "{ invalid json }"
        
        let result = validator.validate(json)
        
        switch result {
        case .success:
            XCTFail("Should fail for invalid JSON")
        case .failure:
            // Expected
            break
        }
    }
    
    func testMissingRequiredField() {
        let json = """
        {
            "stage": null,
            "suggested_questions": []
        }
        """
        
        let result = validator.validate(json)
        
        switch result {
        case .success:
            XCTFail("Should fail for missing meddic_updates")
        case .failure:
            // Expected
            break
        }
    }
    
    func testExtractJSONFromMarkdown() {
        let markdown = """
        Here's the analysis:
        
        ```json
        {
            "stage": {"name": "Opening", "confidence": 0.7, "rationale": "Just started"},
            "suggested_questions": [],
            "meddic_updates": {
                "metrics": null,
                "economic_buyer": null,
                "decision_criteria": null,
                "decision_process": null,
                "identify_pain": null,
                "champion": null
            }
        }
        ```
        
        Let me know if you need more details.
        """
        
        let extracted = validator.extractJSON(from: markdown)
        
        XCTAssertNotNil(extracted)
        
        if let json = extracted {
            let result = validator.validate(json)
            switch result {
            case .success(let response):
                XCTAssertEqual(response.stage?.name, "Opening")
            case .failure(let error):
                XCTFail("Extracted JSON should be valid: \(error)")
            }
        }
    }
    
}

