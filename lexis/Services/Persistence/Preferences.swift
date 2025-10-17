import Foundation

enum PrefKey {
    static let isLearningNewLanguage = "isLearningNewLanguage"
    static let nativeLanguageCode = "nativeLanguageCode"
    static let targetLanguageCode = "targetLanguageCode"

    // New preference keys for difficulty & frequency
    static let difficultyHard = "difficultyHard"
    static let difficultyMedium = "difficultyMedium"
    static let difficultyEasy = "difficultyEasy"

    // preferred numeric storage
    static let frequencyMin = "frequencyMin"
    static let frequencyMax = "frequencyMax"
}

enum PreferencesStore {
    // Use the app group UserDefaults if available, otherwise fall back to standard to avoid force-unwrap crashes.
    static let defaults: UserDefaults =
        UserDefaults(suiteName: "group.com.anonymous.lexis") ?? .standard
}
