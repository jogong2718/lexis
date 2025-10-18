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

    // Time preferences
    static let startHour = "startHour"
    static let startMinute = "startMinute"
    static let startIsPM = "startIsPM"
    static let endHour = "endHour"
    static let endMinute = "endMinute"
    static let endIsPM = "endIsPM"

    // Onboarding completion
    static let onboardingCompleted = "onboardingCompleted"
}

enum PreferencesStore {
    // Use the app group UserDefaults if available, otherwise fall back to standard to avoid force-unwrap crashes.
    static let defaults: UserDefaults =
        UserDefaults(suiteName: "group.com.anonymous.lexis") ?? .standard
}
