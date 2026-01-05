import Foundation

/// Utilities for formatting time values
struct TimeFormatter {
    /// Format milliseconds as MM:SS
    static func formatMs(_ ms: Int64) -> String {
        let seconds = Int(ms / 1000)
        return formatSeconds(seconds)
    }
    
    /// Format seconds as MM:SS
    static func formatSeconds(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
    
    /// Format seconds as HH:MM:SS if over an hour
    static func formatSecondsLong(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
    
    /// Format a time range from start to end milliseconds
    static func formatRange(startMs: Int64, endMs: Int64) -> String {
        "\(formatMs(startMs)) - \(formatMs(endMs))"
    }
    
    /// Format duration in a human-readable way
    static func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds) seconds"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        } else {
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            if minutes == 0 {
                return "\(hours) hour\(hours == 1 ? "" : "s")"
            } else {
                return "\(hours)h \(minutes)m"
            }
        }
    }
}

