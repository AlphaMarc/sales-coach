import Foundation

/// File-based persistence for sessions
actor FileStore: PersistenceStore {
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    private var baseURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("SalesCoach", isDirectory: true)
    }
    
    private var sessionsURL: URL {
        baseURL.appendingPathComponent("sessions", isDirectory: true)
    }
    
    private var exportsURL: URL {
        baseURL.appendingPathComponent("exports", isDirectory: true)
    }
    
    init() {
        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // Ensure directories exist
        try? createDirectories()
    }
    
    private func createDirectories() throws {
        try fileManager.createDirectory(at: sessionsURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: exportsURL, withIntermediateDirectories: true)
    }
    
    // MARK: - PersistenceStore Protocol
    
    func saveSession(_ session: SessionData) async throws {
        let fileURL = sessionsURL.appendingPathComponent("\(session.id.uuidString).json")
        
        do {
            let data = try encoder.encode(session)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw PersistenceError.fileWriteFailed(fileURL.path)
        }
    }
    
    func loadSession(id: UUID) async throws -> SessionData? {
        let fileURL = sessionsURL.appendingPathComponent("\(id.uuidString).json")
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(SessionData.self, from: data)
        } catch {
            throw PersistenceError.fileReadFailed(fileURL.path)
        }
    }
    
    func listSessions() async throws -> [SessionMetadata] {
        guard fileManager.fileExists(atPath: sessionsURL.path) else {
            return []
        }
        
        let files = try fileManager.contentsOfDirectory(at: sessionsURL, includingPropertiesForKeys: [.creationDateKey])
        
        var sessions: [SessionMetadata] = []
        
        for file in files where file.pathExtension == "json" {
            do {
                let data = try Data(contentsOf: file)
                let session = try decoder.decode(SessionData.self, from: data)
                sessions.append(session.metadata)
            } catch {
                // Skip corrupted files
                continue
            }
        }
        
        // Sort by creation date, newest first
        return sessions.sorted { $0.createdAt > $1.createdAt }
    }
    
    func deleteSession(id: UUID) async throws {
        let fileURL = sessionsURL.appendingPathComponent("\(id.uuidString).json")
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw PersistenceError.sessionNotFound
        }
        
        try fileManager.removeItem(at: fileURL)
    }
    
    func exportSession(_ session: SessionData, format: ExportFormat) async throws -> URL {
        let timestamp = ISO8601DateFormatter().string(from: session.createdAt)
            .replacingOccurrences(of: ":", with: "-")
        let filename = "SalesCoach-\(timestamp).\(format.fileExtension)"
        let exportURL = exportsURL.appendingPathComponent(filename)
        
        let content: Data
        
        switch format {
        case .json:
            content = try exportAsJSON(session)
        case .plainText:
            content = exportAsPlainText(session)
        case .csv:
            content = exportAsCSV(session)
        }
        
        try content.write(to: exportURL, options: .atomic)
        return exportURL
    }
    
    // MARK: - Export Formats
    
    private func exportAsJSON(_ session: SessionData) throws -> Data {
        try encoder.encode(session)
    }
    
    private func exportAsPlainText(_ session: SessionData) -> Data {
        var text = """
        Sales Coach Session Export
        ==========================
        Date: \(session.metadata.formattedDate)
        Duration: \(session.formattedDuration)
        
        TRANSCRIPT
        ----------
        
        """
        
        for segment in session.transcript {
            text += "[\(segment.formattedTimestamp)] \(segment.speaker): \(segment.text)\n"
        }
        
        text += """
        
        MEDDIC SUMMARY
        --------------
        
        """
        
        for (name, field) in session.coachingState.meddic.allFields {
            if let f = field {
                text += "\(name): \(f.value) (Confidence: \(Int(f.confidence * 100))%)\n"
                if let evidence = f.evidence, !evidence.isEmpty {
                    for quote in evidence {
                        text += "  Evidence: \"\(quote.quote)\" [\(quote.formattedRange)]\n"
                    }
                }
            } else {
                text += "\(name): [Not captured]\n"
            }
        }
        
        return text.data(using: .utf8) ?? Data()
    }
    
    private func exportAsCSV(_ session: SessionData) -> Data {
        var csv = "Timestamp,Speaker,Text\n"
        
        for segment in session.transcript {
            let escapedText = segment.text.replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\"\(segment.formattedTimestamp)\",\"\(segment.speaker)\",\"\(escapedText)\"\n"
        }
        
        return csv.data(using: .utf8) ?? Data()
    }
}


