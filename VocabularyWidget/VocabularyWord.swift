import Foundation

struct VocabularyWord: Identifiable, Codable, Equatable {
    let id: String
    let word: String
    let partOfSpeech: String
    let pronunciation: String?
    let languageCode: String  // The language this word is in

    // Native language mode: learning advanced words in your own language
    let definitions: [Definition]?
    let origin: String?
    let synonyms: [String]?

    // Target language mode: learning words in another language
    let alternateScript: String?  // kanji, cyrillic, etc.
    let translation: String?  // Translation in user's native language
    let translationLanguageCode: String?  // Language code of the translation
    let exampleSentences: [ExampleSentence]? // in target language with optional romanization & translation

    let difficulty: Difficulty

    enum Difficulty: String, Codable {
        case easy, medium, hard
    }

    struct Definition: Codable, Equatable {
        let text: String
        let number: Int?  // for ordering (1., 2., etc.)
    }

    struct ExampleSentence: Codable, Equatable {
        let original: String  // in the target language
        let romanization: String?  // pronunciation/romanization
        let translation: String?  // in native language
    }

    init(
        id: String,
        word: String,
        partOfSpeech: String,
        pronunciation: String? = nil,
        languageCode: String,
        definitions: [Definition]? = nil,
        origin: String? = nil,
        synonyms: [String]? = nil,
        alternateScript: String? = nil,
        translation: String? = nil,
        translationLanguageCode: String? = nil,
        exampleSentences: [ExampleSentence]? = nil,
        difficulty: Difficulty = .medium
    ) {
        self.id = id
        self.word = word
        self.partOfSpeech = partOfSpeech
        self.pronunciation = pronunciation
        self.languageCode = languageCode
        self.definitions = definitions
        self.origin = origin
        self.synonyms = synonyms
        self.alternateScript = alternateScript
        self.translation = translation
        self.translationLanguageCode = translationLanguageCode
        self.exampleSentences = exampleSentences
        self.difficulty = difficulty
    }
}

struct VocabularyHistory: Codable {
    var entries: [String]  // Array of vocabulary entry IDs
    var lastRotation: Date

    init(entries: [String] = [], lastRotation: Date = Date()) {
        self.entries = entries
        self.lastRotation = lastRotation
    }
}
