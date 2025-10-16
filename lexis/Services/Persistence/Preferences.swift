import Foundation

enum PrefKey {
    static let isLearningNewLanguage = "isLearningNewLanguage"
    static let nativeLanguageCode = "nativeLanguageCode"
    static let targetLanguageCode = "targetLanguageCode"
}

enum PreferencesStore {
    // Use the app group UserDefaults if available, otherwise fall back to standard to avoid force-unwrap crashes.
    static let defaults: UserDefaults =
        UserDefaults(suiteName: "group.com.anonymous.lexis") ?? .standard
}
