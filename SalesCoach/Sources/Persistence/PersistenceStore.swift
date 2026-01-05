import Foundation

/// Protocol for session persistence
protocol PersistenceStore {
    func saveSession(_ session: SessionData) async throws
    func loadSession(id: UUID) async throws -> SessionData?
    func listSessions() async throws -> [SessionMetadata]
    func deleteSession(id: UUID) async throws
    func exportSession(_ session: SessionData, format: ExportFormat) async throws -> URL
}

/// Errors that can occur during persistence operations
enum PersistenceError: LocalizedError {
    case directoryCreationFailed
    case fileWriteFailed(String)
    case fileReadFailed(String)
    case sessionNotFound
    case exportFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed:
            return "Failed to create storage directory"
        case .fileWriteFailed(let path):
            return "Failed to write file: \(path)"
        case .fileReadFailed(let path):
            return "Failed to read file: \(path)"
        case .sessionNotFound:
            return "Session not found"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        }
    }
}

