import Foundation

/// Validates and repairs LLM JSON responses
struct JSONSchemaValidator {
    private let decoder: JSONDecoder
    
    init() {
        self.decoder = JSONDecoder()
    }
    
    /// Validate and parse a coaching response
    func validate(_ jsonString: String) -> Result<CoachingResponse, ValidationError> {
        // Try to clean the JSON first
        let cleanedJSON = cleanJSON(jsonString)
        
        guard let data = cleanedJSON.data(using: .utf8) else {
            return .failure(.invalidEncoding)
        }
        
        do {
            let response = try decoder.decode(CoachingResponse.self, from: data)
            
            // Additional validation
            if let validationError = validateResponse(response) {
                return .failure(validationError)
            }
            
            return .success(response)
        } catch let decodingError as DecodingError {
            return .failure(.decodingError(describeDecodingError(decodingError)))
        } catch {
            return .failure(.unknownError(error.localizedDescription))
        }
    }
    
    /// Attempt to extract valid JSON from a potentially malformed response
    func extractJSON(from text: String) -> String? {
        // Try to find JSON object boundaries
        guard let startIndex = text.firstIndex(of: "{") else { return nil }
        
        var depth = 0
        var endIndex: String.Index?
        
        for (index, char) in text[startIndex...].enumerated() {
            let currentIndex = text.index(startIndex, offsetBy: index)
            if char == "{" {
                depth += 1
            } else if char == "}" {
                depth -= 1
                if depth == 0 {
                    endIndex = currentIndex
                    break
                }
            }
        }
        
        guard let end = endIndex else { return nil }
        
        return String(text[startIndex...end])
    }
    
    private func cleanJSON(_ json: String) -> String {
        var cleaned = json.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown code blocks if present
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func validateResponse(_ response: CoachingResponse) -> ValidationError? {
        // Validate confidence scores are in range
        if let stage = response.stage {
            if stage.confidence < 0 || stage.confidence > 1 {
                return .invalidConfidence("stage confidence out of range")
            }
        }
        
        // Validate question priorities
        for question in response.suggestedQuestions {
            if question.priority < 1 || question.priority > 3 {
                return .invalidPriority("question priority must be 1-3")
            }
        }
        
        return nil
    }
    
    private func describeDecodingError(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            return "Missing key '\(key.stringValue)' at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .typeMismatch(let type, let context):
            return "Type mismatch for \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .valueNotFound(let type, let context):
            return "Value not found for \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .dataCorrupted(let context):
            return "Data corrupted at \(context.codingPath.map { $0.stringValue }.joined(separator: ".")): \(context.debugDescription)"
        @unknown default:
            return "Unknown decoding error"
        }
    }
}

/// Validation errors
enum ValidationError: LocalizedError {
    case invalidEncoding
    case decodingError(String)
    case invalidConfidence(String)
    case invalidPriority(String)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidEncoding:
            return "Invalid text encoding"
        case .decodingError(let message):
            return "JSON decoding error: \(message)"
        case .invalidConfidence(let message):
            return "Invalid confidence value: \(message)"
        case .invalidPriority(let message):
            return "Invalid priority value: \(message)"
        case .unknownError(let message):
            return "Unknown error: \(message)"
        }
    }
}

