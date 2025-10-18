import Foundation

// Simplified model for widget use
struct VocabularyWord: Codable, Identifiable {
    let id: String
    let word: String
    let partOfSpeech: String
    let pronunciation: String?
    let languageCode: String
    let alternateScript: String?
    let translation: String?
    let translationLanguageCode: String?
    let definitions: [Definition]?
    let exampleSentences: [ExampleSentence]?
    let difficulty: Difficulty?

    struct Definition: Codable {
        let text: String
        let number: Int
    }

    struct ExampleSentence: Codable {
        let original: String
        let romanization: String?
        let translation: String
    }

    enum Difficulty: String, Codable {
        case easy, medium, hard
    }
}

struct VocabularyHistory: Codable {
    var entries: [String] = []
    var lastRotation: Date = Date()
}
