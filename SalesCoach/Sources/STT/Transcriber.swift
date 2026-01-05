import Foundation
import AVFoundation

/// Protocol for speech-to-text transcription
protocol Transcriber: Actor {
    /// Start the transcription pipeline
    func start() async throws
    
    /// Stop transcription
    func stop() async
    
    /// Feed audio data for transcription
    func feedAudio(_ buffer: AVAudioPCMBuffer) async
    
    /// Stream of transcript events
    var transcriptStream: AsyncStream<TranscriptEvent> { get }
}

/// Configuration for the transcriber
struct TranscriberConfig {
    let modelPath: URL
    /// Language for transcription: "auto" for automatic detection, or specific language code (e.g., "en", "fr")
    let language: String
    let chunkDurationMs: Int
    let overlapMs: Int
    
    init(
        modelPath: URL,
        language: String = "auto",
        chunkDurationMs: Int = 3000,
        overlapMs: Int = 500
    ) {
        self.modelPath = modelPath
        self.language = language
        self.chunkDurationMs = chunkDurationMs
        self.overlapMs = overlapMs
    }
}

