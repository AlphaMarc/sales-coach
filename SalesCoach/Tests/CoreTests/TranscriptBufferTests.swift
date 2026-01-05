import XCTest
@testable import SalesCoach

final class TranscriptBufferTests: XCTestCase {
    
    func testEmptyBuffer() {
        let buffer = TranscriptBuffer()
        
        XCTAssertTrue(buffer.isEmpty)
        XCTAssertTrue(buffer.segments.isEmpty)
        XCTAssertTrue(buffer.partialText.isEmpty)
        XCTAssertEqual(buffer.fullText, "")
    }
    
    func testAddSegment() {
        var buffer = TranscriptBuffer()
        
        let segment = TranscriptSegment(
            text: "Hello world",
            startMs: 0,
            endMs: 1000,
            speaker: "Speaker A"
        )
        
        buffer.addSegment(segment)
        
        XCTAssertFalse(buffer.isEmpty)
        XCTAssertEqual(buffer.segments.count, 1)
        XCTAssertEqual(buffer.fullText, "Hello world")
    }
    
    func testUpdatePartial() {
        var buffer = TranscriptBuffer()
        
        buffer.updatePartial("In progress...")
        
        XCTAssertFalse(buffer.isEmpty)
        XCTAssertEqual(buffer.partialText, "In progress...")
    }
    
    func testPartialClearedOnSegmentAdd() {
        var buffer = TranscriptBuffer()
        
        buffer.updatePartial("Partial text")
        XCTAssertEqual(buffer.partialText, "Partial text")
        
        let segment = TranscriptSegment(
            text: "Final text",
            startMs: 0,
            endMs: 1000
        )
        buffer.addSegment(segment)
        
        XCTAssertTrue(buffer.partialText.isEmpty)
    }
    
    func testWindowedText() {
        var buffer = TranscriptBuffer()
        
        // Add segments at different times
        buffer.addSegment(TranscriptSegment(text: "First", startMs: 0, endMs: 1000))
        buffer.addSegment(TranscriptSegment(text: "Second", startMs: 1000, endMs: 2000))
        buffer.addSegment(TranscriptSegment(text: "Third", startMs: 2000, endMs: 3000))
        buffer.addSegment(TranscriptSegment(text: "Fourth", startMs: 3000, endMs: 4000))
        
        // Get last 2 seconds (2000ms)
        let windowed = buffer.windowedText(lastMs: 2000)
        
        XCTAssertTrue(windowed.contains("Third"))
        XCTAssertTrue(windowed.contains("Fourth"))
    }
    
    func testDeltaText() {
        var buffer = TranscriptBuffer()
        
        let oldDate = Date()
        
        buffer.addSegment(TranscriptSegment(text: "Old segment", startMs: 0, endMs: 1000))
        
        // Wait a tiny bit
        Thread.sleep(forTimeInterval: 0.01)
        let newDate = Date()
        
        buffer.addSegment(TranscriptSegment(text: "New segment", startMs: 1000, endMs: 2000))
        
        let delta = buffer.deltaText(since: newDate)
        
        XCTAssertTrue(delta.contains("New segment"))
        XCTAssertFalse(delta.contains("Old segment"))
    }
    
    func testMaxSegmentsLimit() {
        var buffer = TranscriptBuffer(maxSegments: 3)
        
        for i in 0..<5 {
            buffer.addSegment(TranscriptSegment(
                text: "Segment \(i)",
                startMs: Int64(i * 1000),
                endMs: Int64((i + 1) * 1000)
            ))
        }
        
        XCTAssertEqual(buffer.segments.count, 3)
        XCTAssertTrue(buffer.fullText.contains("Segment 4"))
        XCTAssertFalse(buffer.fullText.contains("Segment 0"))
    }
    
    func testClear() {
        var buffer = TranscriptBuffer()
        
        buffer.addSegment(TranscriptSegment(text: "Test", startMs: 0, endMs: 1000))
        buffer.updatePartial("Partial")
        
        XCTAssertFalse(buffer.isEmpty)
        
        buffer.clear()
        
        XCTAssertTrue(buffer.isEmpty)
        XCTAssertTrue(buffer.segments.isEmpty)
        XCTAssertTrue(buffer.partialText.isEmpty)
    }
}

