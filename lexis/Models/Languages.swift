import Foundation

// Minimal language model used app-wide
struct Language: Identifiable, Codable, Equatable {
    let id: String
    let code: String
    let english: String
    let native: String

    init(_ code: String, _ english: String, _ native: String) {
        self.code = code
        self.english = english
        self.native = native
        self.id = code
    }
}

enum Languages {
    // Replace/extend this static array or load from JSON later
    static let all: [Language] = [
        Language("en", "English", "English"),
        Language("ja", "Japanese", "日本語"),
    ].sorted { $0.english < $1.english }

    // Supported languages (easily expandable in the future)
    static let supportedNativeLanguages: [String] = ["en"]
    static let supportedTargetLanguages: [String] = ["ja"]

    static func language(forCode code: String) -> Language? {
        all.first { $0.code == code }
    }

    static func match(forText text: String) -> Language? {
        all.first {
            $0.english.compare(text, options: .caseInsensitive) == .orderedSame
                || $0.native.compare(text, options: .caseInsensitive) == .orderedSame
        }
    }
}
