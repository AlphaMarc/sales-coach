import XCTest
@testable import SalesCoach

final class MEDDICDataTests: XCTestCase {
    
    func testEmptyMEDDIC() {
        let meddic = MEDDICData()
        
        XCTAssertNil(meddic.metrics)
        XCTAssertNil(meddic.economicBuyer)
        XCTAssertNil(meddic.decisionCriteria)
        XCTAssertNil(meddic.decisionProcess)
        XCTAssertNil(meddic.identifyPain)
        XCTAssertNil(meddic.champion)
        XCTAssertEqual(meddic.filledCount, 0)
        XCTAssertEqual(meddic.completionPercentage, 0)
    }
    
    func testFilledCount() {
        var meddic = MEDDICData()
        
        meddic.metrics = MEDDICField(value: "20% reduction", confidence: 0.8)
        XCTAssertEqual(meddic.filledCount, 1)
        
        meddic.champion = MEDDICField(value: "John Smith", confidence: 0.9)
        XCTAssertEqual(meddic.filledCount, 2)
        
        XCTAssertEqual(meddic.completionPercentage, 2.0 / 6.0)
    }
    
    func testMergeWithHigherConfidence() {
        var meddic = MEDDICData()
        meddic.metrics = MEDDICField(value: "Old value", confidence: 0.5)
        
        let update = MEDDICData(
            metrics: MEDDICField(value: "New value", confidence: 0.8)
        )
        
        meddic.merge(with: update)
        
        XCTAssertEqual(meddic.metrics?.value, "New value")
        XCTAssertEqual(meddic.metrics?.confidence, 0.8)
    }
    
    func testMergeWithLowerConfidence() {
        var meddic = MEDDICData()
        meddic.metrics = MEDDICField(value: "Original", confidence: 0.9)
        
        let update = MEDDICData(
            metrics: MEDDICField(value: "Updated", confidence: 0.5)
        )
        
        meddic.merge(with: update)
        
        // Should keep original because it has higher confidence
        XCTAssertEqual(meddic.metrics?.value, "Original")
        XCTAssertEqual(meddic.metrics?.confidence, 0.9)
    }
    
    func testMergeWithEqualConfidence() {
        var meddic = MEDDICData()
        meddic.metrics = MEDDICField(value: "Original", confidence: 0.7)
        
        let update = MEDDICData(
            metrics: MEDDICField(value: "Updated", confidence: 0.7)
        )
        
        meddic.merge(with: update)
        
        // Should use new value when confidence is equal
        XCTAssertEqual(meddic.metrics?.value, "Updated")
    }
    
    func testMergeNewField() {
        var meddic = MEDDICData()
        meddic.metrics = MEDDICField(value: "Existing", confidence: 0.8)
        
        let update = MEDDICData(
            economicBuyer: MEDDICField(value: "CEO", confidence: 0.6)
        )
        
        meddic.merge(with: update)
        
        XCTAssertEqual(meddic.metrics?.value, "Existing")
        XCTAssertEqual(meddic.economicBuyer?.value, "CEO")
        XCTAssertEqual(meddic.filledCount, 2)
    }
    
    func testMergeNilDoesNotOverwrite() {
        var meddic = MEDDICData()
        meddic.metrics = MEDDICField(value: "Keep this", confidence: 0.8)
        
        let update = MEDDICData(metrics: nil)
        
        meddic.merge(with: update)
        
        XCTAssertEqual(meddic.metrics?.value, "Keep this")
    }
    
    func testAllFields() {
        let meddic = MEDDICData(
            metrics: MEDDICField(value: "M", confidence: 0.1),
            economicBuyer: MEDDICField(value: "E", confidence: 0.2),
            decisionCriteria: MEDDICField(value: "D", confidence: 0.3),
            decisionProcess: MEDDICField(value: "D", confidence: 0.4),
            identifyPain: MEDDICField(value: "I", confidence: 0.5),
            champion: MEDDICField(value: "C", confidence: 0.6)
        )
        
        let allFields = meddic.allFields
        
        XCTAssertEqual(allFields.count, 6)
        XCTAssertEqual(allFields[0].name, "Metrics")
        XCTAssertEqual(allFields[5].name, "Champion")
        XCTAssertEqual(meddic.filledCount, 6)
        XCTAssertEqual(meddic.completionPercentage, 1.0)
    }
    
    func testConfidenceClamping() {
        let field = MEDDICField(value: "Test", confidence: 1.5)
        XCTAssertEqual(field.confidence, 1.0)
        
        let field2 = MEDDICField(value: "Test", confidence: -0.5)
        XCTAssertEqual(field2.confidence, 0.0)
    }
}

