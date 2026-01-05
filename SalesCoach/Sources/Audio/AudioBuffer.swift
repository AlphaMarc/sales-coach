import Foundation
import AVFoundation

/// Ring buffer for accumulating audio frames before processing
actor AudioRingBuffer {
    private var buffer: Data
    private let maxSize: Int
    private let sampleRate: Double = 16000
    private let bytesPerSample: Int = 2  // 16-bit
    
    /// Chunk duration in milliseconds
    let chunkDurationMs: Int
    
    /// Overlap duration in milliseconds for continuity
    let overlapMs: Int
    
    /// Bytes needed for a chunk
    private var chunkBytes: Int {
        Int(Double(chunkDurationMs) / 1000.0 * sampleRate) * bytesPerSample
    }
    
    /// Bytes to overlap between chunks
    private var overlapBytes: Int {
        Int(Double(overlapMs) / 1000.0 * sampleRate) * bytesPerSample
    }
    
    init(chunkDurationMs: Int = 3000, overlapMs: Int = 500, maxDurationSeconds: Int = 30) {
        self.chunkDurationMs = chunkDurationMs
        self.overlapMs = overlapMs
        self.maxSize = maxDurationSeconds * Int(sampleRate) * bytesPerSample
        self.buffer = Data()
    }
    
    /// Append audio data from a PCM buffer
    func append(_ pcmBuffer: AVAudioPCMBuffer) {
        guard let channelData = pcmBuffer.int16ChannelData else { return }
        
        let frameLength = Int(pcmBuffer.frameLength)
        let data = Data(bytes: channelData[0], count: frameLength * bytesPerSample)
        
        buffer.append(data)
        
        // Trim if exceeding max size
        if buffer.count > maxSize {
            buffer.removeFirst(buffer.count - maxSize)
        }
    }
    
    /// Check if there's enough data for a chunk
    var hasChunk: Bool {
        buffer.count >= chunkBytes
    }
    
    /// Current buffer duration in milliseconds
    var durationMs: Int {
        Int(Double(buffer.count / bytesPerSample) / sampleRate * 1000)
    }
    
    /// Export current chunk as WAV file and advance buffer
    func exportChunkAsWAV() throws -> URL {
        guard hasChunk else {
            throw AudioBufferError.insufficientData
        }
        
        let chunkData = buffer.prefix(chunkBytes)
        
        // Create temporary WAV file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        
        let wavData = createWAVData(from: Data(chunkData))
        try wavData.write(to: tempURL)
        
        // Advance buffer, keeping overlap
        let advanceBytes = chunkBytes - overlapBytes
        if buffer.count > advanceBytes {
            buffer.removeFirst(advanceBytes)
        } else {
            buffer.removeAll()
        }
        
        return tempURL
    }
    
    /// Clear all buffered audio
    func clear() {
        buffer.removeAll()
    }
    
    /// Create WAV file data from raw PCM
    private func createWAVData(from pcmData: Data) -> Data {
        var wavData = Data()
        
        // WAV header
        let fileSize = UInt32(pcmData.count + 36)
        let numChannels: UInt16 = 1
        let sampleRateInt: UInt32 = 16000
        let bitsPerSample: UInt16 = 16
        let byteRate: UInt32 = sampleRateInt * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        let blockAlign: UInt16 = numChannels * (bitsPerSample / 8)
        let dataSize = UInt32(pcmData.count)
        
        // RIFF header
        wavData.append("RIFF".data(using: .ascii)!)
        wavData.append(withUnsafeBytes(of: fileSize.littleEndian) { Data($0) })
        wavData.append("WAVE".data(using: .ascii)!)
        
        // fmt chunk
        wavData.append("fmt ".data(using: .ascii)!)
        wavData.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })  // Subchunk1Size
        wavData.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })   // AudioFormat (PCM)
        wavData.append(withUnsafeBytes(of: numChannels.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: sampleRateInt.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
        
        // data chunk
        wavData.append("data".data(using: .ascii)!)
        wavData.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
        wavData.append(pcmData)
        
        return wavData
    }
}

/// Audio buffer errors
enum AudioBufferError: LocalizedError {
    case insufficientData
    case exportFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .insufficientData:
            return "Not enough audio data for a chunk"
        case .exportFailed(let reason):
            return "Failed to export audio: \(reason)"
        }
    }
}
