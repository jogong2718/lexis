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
        Language("es", "Spanish", "Español"),
        Language("fr", "French", "Français"),
        Language("de", "German", "Deutsch"),
        Language("it", "Italian", "Italiano"),
        Language("pt", "Portuguese", "Português"),
        Language("ru", "Russian", "Русский"),
        Language("zh", "Chinese", "中文"),
        Language("ja", "Japanese", "日本語"),
        Language("ko", "Korean", "한국어"),
        Language("ar", "Arabic", "العربية"),
        Language("hi", "Hindi", "हिन्दी"),
        Language("nl", "Dutch", "Nederlands"),
        Language("sv", "Swedish", "Svenska"),
        Language("no", "Norwegian", "Norsk"),
    ].sorted { $0.english < $1.english }

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
