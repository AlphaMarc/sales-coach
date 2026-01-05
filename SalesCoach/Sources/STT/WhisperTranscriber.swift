import Foundation
import AVFoundation

/// Transcriber implementation using whisper.cpp CLI
actor WhisperTranscriber: Transcriber {
    private let whisperPath: URL
    private let modelPath: URL
    private let language: String
    private let audioBuffer: AudioRingBuffer
    private var isRunning = false
    private var processTask: Task<Void, Never>?
    private var cumulativeTimeMs: Int64 = 0
    
    private var continuation: AsyncStream<TranscriptEvent>.Continuation?
    private(set) var transcriptStream: AsyncStream<TranscriptEvent>
    
    init(config: TranscriberConfig) {
        self.modelPath = config.modelPath
        self.language = config.language
        self.audioBuffer = AudioRingBuffer(
            chunkDurationMs: config.chunkDurationMs,
            overlapMs: config.overlapMs
        )
        
        // Get whisper-cli from app bundle
        if let bundlePath = Bundle.main.path(forResource: "whisper-cli", ofType: nil) {
            self.whisperPath = URL(fileURLWithPath: bundlePath)
            print("[WhisperTranscriber] Found whisper-cli in bundle at: \(bundlePath)")
        } else {
            // Fallback for development
            self.whisperPath = URL(fileURLWithPath: "/usr/local/bin/whisper")
            print("[WhisperTranscriber] WARNING: whisper-cli not found in bundle, using fallback: /usr/local/bin/whisper")
            Self.logBundleDiagnostics()
        }
        
        var streamContinuation: AsyncStream<TranscriptEvent>.Continuation?
        self.transcriptStream = AsyncStream { continuation in
            streamContinuation = continuation
        }
        self.continuation = streamContinuation
    }
    
    private static func logBundleDiagnostics() {
        print(getDiagnosticsString())
    }
    
    private static func getDiagnosticsString() -> String {
        var lines: [String] = []
        lines.append("=== Bundle Diagnostics ===")
        lines.append("Bundle path: \(Bundle.main.bundlePath)")
        lines.append("Resource path: \(Bundle.main.resourcePath ?? "nil")")
        
        // List contents of Resources folder if it exists
        if let resourcePath = Bundle.main.resourcePath {
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                lines.append("Resource folder contents: \(contents)")
                
                // Check for whisper-cli specifically
                let whisperPath = (resourcePath as NSString).appendingPathComponent("whisper-cli")
                let exists = FileManager.default.fileExists(atPath: whisperPath)
                lines.append("whisper-cli exists at \(whisperPath): \(exists)")
                
                // Check in Resources subfolder (folder reference case)
                let resourcesSubfolder = (resourcePath as NSString).appendingPathComponent("Resources")
                if FileManager.default.fileExists(atPath: resourcesSubfolder) {
                    let subContents = try FileManager.default.contentsOfDirectory(atPath: resourcesSubfolder)
                    lines.append("Resources subfolder contents: \(subContents)")
                    
                    // Check for whisper-cli in subfolder
                    let whisperInSubfolder = (resourcesSubfolder as NSString).appendingPathComponent("whisper-cli")
                    let existsInSubfolder = FileManager.default.fileExists(atPath: whisperInSubfolder)
                    lines.append("whisper-cli in Resources subfolder: \(existsInSubfolder)")
                }
            } catch {
                lines.append("Error listing resource folder: \(error)")
            }
        }
        lines.append("=== End Diagnostics ===")
        return lines.joined(separator: "\n")
    }
    
    func start() async throws {
        guard !isRunning else { return }
        
        // Verify whisper binary exists
        guard FileManager.default.fileExists(atPath: whisperPath.path) else {
            let diagnostics = Self.getDiagnosticsString()
            throw TranscriberError.whisperNotFound(path: whisperPath.path, diagnostics: diagnostics)
        }
        
        // Verify model exists
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw TranscriberError.modelNotFound(modelPath.path)
        }
        
        isRunning = true
        cumulativeTimeMs = 0
        
        // Start processing loop
        processTask = Task {
            await processLoop()
        }
    }
    
    func stop() async {
        isRunning = false
        processTask?.cancel()
        processTask = nil
        await audioBuffer.clear()
    }
    
    func feedAudio(_ buffer: AVAudioPCMBuffer) async {
        await audioBuffer.append(buffer)
    }
    
    private func processLoop() async {
        while isRunning && !Task.isCancelled {
            // Wait for enough audio
            while await !audioBuffer.hasChunk && isRunning {
                try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
            }
            
            guard isRunning else { break }
            
            do {
                let segments = try await processNextChunk()
                for segment in segments {
                    continuation?.yield(.final(segment: segment))
                }
            } catch {
                continuation?.yield(.error(error))
            }
        }
    }
    
    private func processNextChunk() async throws -> [TranscriptSegment] {
        let wavFile = try await audioBuffer.exportChunkAsWAV()
        
        // Check for JSON output file (whisper -oj writes to .wav.json file)
        let jsonFile = wavFile.appendingPathExtension("json")
        
        defer {
            try? FileManager.default.removeItem(at: wavFile)
            try? FileManager.default.removeItem(at: jsonFile)
        }
        
        let output = try await runWhisperCLI(input: wavFile)
        
        // Use JSON file content if it exists, otherwise use stdout
        var jsonFileContent = ""
        let jsonFileExists = FileManager.default.fileExists(atPath: jsonFile.path)
        if jsonFileExists {
            jsonFileContent = (try? String(contentsOf: jsonFile, encoding: .utf8)) ?? ""
        }
        
        let jsonToParse = jsonFileExists ? jsonFileContent : output
        let segments = parseWhisperJSON(jsonToParse, baseTimeMs: cumulativeTimeMs)
        
        // Update cumulative time
        let chunkMs = Int64(await audioBuffer.chunkDurationMs - audioBuffer.overlapMs)
        cumulativeTimeMs += chunkMs
        
        return segments
    }
    
    private func runWhisperCLI(input: URL) async throws -> String {
        let process = Process()
        process.executableURL = whisperPath
        process.arguments = [
            "-m", modelPath.path,
            "-f", input.path,
            "-oj",  // Output JSON
            "-l", language  // Language: "auto" for auto-detect, or specific like "en", "fr"
        ]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try process.run()
                
                process.waitUntilExit()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                
                if process.terminationStatus != 0 {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: TranscriberError.processFailed(errorMessage))
                    return
                }
                
                let output = String(data: outputData, encoding: .utf8) ?? ""
                continuation.resume(returning: output)
            } catch {
                continuation.resume(throwing: TranscriberError.processStartFailed(error.localizedDescription))
            }
        }
    }
    
    private func parseWhisperJSON(_ json: String, baseTimeMs: Int64) -> [TranscriptSegment] {
        // whisper.cpp outputs JSON with segments
        // Try to find and parse the JSON output file
        
        guard let data = json.data(using: .utf8) else { return [] }
        
        do {
            let response = try JSONDecoder().decode(WhisperOutput.self, from: data)
            
            return response.transcription.map { segment in
                TranscriptSegment(
                    text: segment.text.trimmingCharacters(in: .whitespacesAndNewlines),
                    startMs: baseTimeMs + segment.offsets.from,
                    endMs: baseTimeMs + segment.offsets.to,
                    speaker: "Speaker",
                    isFinal: true
                )
            }
        } catch {
            // Try alternative parsing for simpler output
            return parseSimpleOutput(json, baseTimeMs: baseTimeMs)
        }
    }
    
    private func parseSimpleOutput(_ output: String, baseTimeMs: Int64) -> [TranscriptSegment] {
        // Fallback: parse line-by-line output
        var segments: [TranscriptSegment] = []
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            // Try to parse timestamp format: [00:00.000 --> 00:05.000] text
            if let match = parseTimestampLine(trimmed) {
                segments.append(TranscriptSegment(
                    text: match.text,
                    startMs: baseTimeMs + match.startMs,
                    endMs: baseTimeMs + match.endMs,
                    speaker: "Speaker",
                    isFinal: true
                ))
            }
        }
        
        return segments
    }
    
    private func parseTimestampLine(_ line: String) -> (text: String, startMs: Int64, endMs: Int64)? {
        // Pattern: [00:00.000 --> 00:05.000] text
        let pattern = #"\[(\d{2}):(\d{2})\.(\d{3})\s*-->\s*(\d{2}):(\d{2})\.(\d{3})\]\s*(.+)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }
        
        guard match.numberOfRanges >= 8,
              let startMinRange = Range(match.range(at: 1), in: line),
              let startSecRange = Range(match.range(at: 2), in: line),
              let startMsRange = Range(match.range(at: 3), in: line),
              let endMinRange = Range(match.range(at: 4), in: line),
              let endSecRange = Range(match.range(at: 5), in: line),
              let endMsRange = Range(match.range(at: 6), in: line),
              let textRange = Range(match.range(at: 7), in: line) else {
            return nil
        }
        
        let startMin = Int64(line[startMinRange]) ?? 0
        let startSec = Int64(line[startSecRange]) ?? 0
        let startMs = Int64(line[startMsRange]) ?? 0
        let endMin = Int64(line[endMinRange]) ?? 0
        let endSec = Int64(line[endSecRange]) ?? 0
        let endMs = Int64(line[endMsRange]) ?? 0
        
        let totalStartMs = startMin * 60000 + startSec * 1000 + startMs
        let totalEndMs = endMin * 60000 + endSec * 1000 + endMs
        let text = String(line[textRange])
        
        return (text, totalStartMs, totalEndMs)
    }
}

// MARK: - Whisper Output Models

struct WhisperOutput: Codable {
    let transcription: [WhisperSegment]
}

struct WhisperSegment: Codable {
    let text: String
    let offsets: WhisperOffsets
}

struct WhisperOffsets: Codable {
    let from: Int64
    let to: Int64
}

// MARK: - Errors

enum TranscriberError: LocalizedError {
    case whisperNotFound(path: String, diagnostics: String)
    case modelNotFound(String)
    case processFailed(String)
    case processStartFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .whisperNotFound(let path, let diagnostics):
            return """
                Whisper binary not found at: \(path)
                
                \(diagnostics)
                
                Please ensure whisper-cli is included in the app bundle Resources.
                """
        case .modelNotFound(let path):
            return "Whisper model not found at: \(path)"
        case .processFailed(let error):
            return "Whisper process failed: \(error)"
        case .processStartFailed(let error):
            return "Failed to start whisper process: \(error)"
        }
    }
}
