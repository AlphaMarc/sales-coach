import Foundation
import AVFoundation

/// Utilities for audio format conversion
struct AudioFormatConverter {
    /// Target format for whisper.cpp: 16kHz, mono, 16-bit PCM
    static let whisperFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16000,
        channels: 1,
        interleaved: true
    )!
    
    /// Convert an audio buffer to the target format
    static func convert(
        _ buffer: AVAudioPCMBuffer,
        from sourceFormat: AVAudioFormat,
        to targetFormat: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            return nil
        }
        
        let ratio = targetFormat.sampleRate / sourceFormat.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputFrameCapacity
        ) else {
            return nil
        }
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            print("Audio conversion error: \(error)")
            return nil
        }
        
        return outputBuffer
    }
    
    /// Create WAV file header for PCM data
    static func createWAVHeader(
        dataSize: UInt32,
        sampleRate: UInt32 = 16000,
        channels: UInt16 = 1,
        bitsPerSample: UInt16 = 16
    ) -> Data {
        var header = Data()
        
        let fileSize = dataSize + 36
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        
        // RIFF header
        header.append("RIFF".data(using: .ascii)!)
        header.append(withUnsafeBytes(of: fileSize.littleEndian) { Data($0) })
        header.append("WAVE".data(using: .ascii)!)
        
        // fmt chunk
        header.append("fmt ".data(using: .ascii)!)
        header.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })  // PCM
        header.append(withUnsafeBytes(of: channels.littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
        
        // data chunk header
        header.append("data".data(using: .ascii)!)
        header.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
        
        return header
    }
}


