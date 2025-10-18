import Combine
import Foundation
import WidgetKit

class VocabularyStore: ObservableObject {
    static let shared = VocabularyStore()

    // Add App Group identifier
    private static let appGroupIdentifier = "group.com.jogong2718.lexis"
    private let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier)


    @Published var currentWord: VocabularyEntry?
    @Published var history: [VocabularyEntry] = []

    private var allVocabulary: [VocabularyEntry] = []
    private var vocabularyHistory: VocabularyHistory = VocabularyHistory()

    private let vocabularyFileURL: URL
    private let historyFileURL: URL
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Setup file URLs using App Group
        guard
            let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: VocabularyStore.appGroupIdentifier
            )
        else {
            // Fallback to documents directory if App Group not configured yet
            let documentsPath = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask)[0]
            vocabularyFileURL = documentsPath.appendingPathComponent("vocabulary.json")
            historyFileURL = documentsPath.appendingPathComponent("history.json")

            loadVocabulary()
            loadHistory()

            reconcileFromSharedState()
            
            checkAndRotateIfNeeded()
            observeLanguageModeChanges()
            return
        }

        vocabularyFileURL = containerURL.appendingPathComponent("vocabulary.json")
        historyFileURL = containerURL.appendingPathComponent("history.json")

        loadVocabulary()
        loadHistory()

        reconcileFromSharedState()

        checkAndRotateIfNeeded()
        observeLanguageModeChanges()
    }

    // MARK: - Observe Language Mode Changes

    private func observeLanguageModeChanges() {
        // Listen for changes to isLearningNewLanguage
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                self?.checkAndRotateIfNeeded()
            }
            .store(in: &cancellables)
    }

    // MARK: - Loading

    private func loadVocabulary() {
        // Try to load from file
        if let data = try? Data(contentsOf: vocabularyFileURL),
            let vocabulary = try? JSONDecoder().decode([VocabularyEntry].self, from: data)
        {
            allVocabulary = vocabulary
        } else {
            // Load sample data if no file exists
            allVocabulary = createSampleData()
            saveVocabulary()
        }
    }

    private func loadHistory() {
        if let data = try? Data(contentsOf: historyFileURL),
            let loadedHistory = try? JSONDecoder().decode(VocabularyHistory.self, from: data)
        {
            vocabularyHistory = loadedHistory

            // Populate history array
            history = vocabularyHistory.entries.compactMap { id in
                allVocabulary.first { $0.id == id }
            }
        }
    }

    // MARK: - Saving

    private func saveVocabulary() {
        if let data = try? JSONEncoder().encode(allVocabulary) {
            try? data.write(to: vocabularyFileURL)
        }
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(vocabularyHistory) {
            try? data.write(to: historyFileURL)
        }
    }

    // MARK: - Public Methods

    func forceRotation() {
        rotateWord()
    }

    func getLastRotation() -> Date {
        return vocabularyHistory.lastRotation
    }

    func getTimeUntilNextRotation() -> TimeInterval? {
        let frequencyMin = PreferencesStore.defaults.integer(forKey: PrefKey.frequencyMin)
        let frequencyMax = PreferencesStore.defaults.integer(forKey: PrefKey.frequencyMax)
        let startHour = PreferencesStore.defaults.integer(forKey: PrefKey.startHour)
        let endHour = PreferencesStore.defaults.integer(forKey: PrefKey.endHour)
        let startIsPM = PreferencesStore.defaults.bool(forKey: PrefKey.startIsPM)
        let endIsPM = PreferencesStore.defaults.bool(forKey: PrefKey.endIsPM)

        guard frequencyMin > 0 && frequencyMax > 0 else {
            return nil
        }

        let rotationInterval = calculateRotationInterval()
        guard rotationInterval > 0, rotationInterval.isFinite else {
            return nil
        }

        let start24 = convertTo24Hour(hour: startHour, isPM: startIsPM)
        let end24 = convertTo24Hour(hour: endHour, isPM: endIsPM)
        
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        
        // Check if we're in the active window
        let isInTimeWindow: Bool
        if start24 <= end24 {
            isInTimeWindow = currentHour >= start24 && currentHour < end24
        } else {
            isInTimeWindow = currentHour >= start24 || currentHour < end24
        }
        
        // If outside window, calculate time until window starts
        if !isInTimeWindow {
            let startOfTomorrow = calendar.startOfDay(for: now.addingTimeInterval(86400))
            let nextWindowStart: Date
            
            if currentHour < start24 {
                // Window starts later today
                var components = calendar.dateComponents([.year, .month, .day], from: now)
                components.hour = start24
                components.minute = 0
                nextWindowStart = calendar.date(from: components) ?? now
            } else {
                // Window starts tomorrow
                var components = calendar.dateComponents([.year, .month, .day], from: startOfTomorrow)
                components.hour = start24
                components.minute = 0
                nextWindowStart = calendar.date(from: components) ?? now
            }
            
            return nextWindowStart.timeIntervalSince(now)
        }
        
        // We're in the window - calculate based on today's window start
        var windowStartComponents = calendar.dateComponents([.year, .month, .day], from: now)
        windowStartComponents.hour = start24
        windowStartComponents.minute = 0
        windowStartComponents.second = 0
        
        guard let todayWindowStart = calendar.date(from: windowStartComponents) else {
            return nil
        }
        
        // Calculate how much time has passed since window started
        let timeSinceWindowStart = now.timeIntervalSince(todayWindowStart)
        
        // Calculate which rotation we're on
        let rotationsSinceWindowStart = floor(timeSinceWindowStart / rotationInterval)
        
        // Calculate when the next rotation should occur
        let nextRotationTime = todayWindowStart.addingTimeInterval((rotationsSinceWindowStart + 1) * rotationInterval)
        
        let timeRemaining = nextRotationTime.timeIntervalSince(now)
        
        return max(0, timeRemaining)
    }

    func calculateRotationInterval() -> TimeInterval {
        let frequencyMin = PreferencesStore.defaults.integer(forKey: PrefKey.frequencyMin)
        let frequencyMax = PreferencesStore.defaults.integer(forKey: PrefKey.frequencyMax)
        let startHour = PreferencesStore.defaults.integer(forKey: PrefKey.startHour)
        let endHour = PreferencesStore.defaults.integer(forKey: PrefKey.endHour)
        let startIsPM = PreferencesStore.defaults.bool(forKey: PrefKey.startIsPM)
        let endIsPM = PreferencesStore.defaults.bool(forKey: PrefKey.endIsPM)

        // Validate frequency values
        guard frequencyMin > 0 && frequencyMax > 0 && frequencyMin <= frequencyMax else {
            return 3600.0
        }

        let start24 = convertTo24Hour(hour: startHour, isPM: startIsPM)
        let end24 = convertTo24Hour(hour: endHour, isPM: endIsPM)

        // Calculate hours in the active window
        let activeHours: Double
        if start24 <= end24 {
            activeHours = Double(end24 - start24)
        } else {
            // Crosses midnight
            activeHours = Double(24 - start24 + end24)
        }

        guard activeHours > 0 else {
            return 3600.0
        }

        let avgFrequency = Double(frequencyMin + frequencyMax) / 2.0
        
        let interval = (activeHours * 3600.0) / avgFrequency
        
        return interval
    }
    // MARK: - Rotation Logic

    func checkAndRotateIfNeeded() {
        let lastRotation = vocabularyHistory.lastRotation
        let now = Date()

        // Get user preferences
        let startHour = PreferencesStore.defaults.integer(forKey: PrefKey.startHour)
        let endHour = PreferencesStore.defaults.integer(forKey: PrefKey.endHour)
        let startIsPM = PreferencesStore.defaults.bool(forKey: PrefKey.startIsPM)
        let endIsPM = PreferencesStore.defaults.bool(forKey: PrefKey.endIsPM)

        // Convert to 24-hour format
        let start24 = convertTo24Hour(hour: startHour, isPM: startIsPM)
        let end24 = convertTo24Hour(hour: endHour, isPM: endIsPM)

        // Check if we're in the allowed time window
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)

        let isInTimeWindow: Bool
        if start24 <= end24 {
            isInTimeWindow = currentHour >= start24 && currentHour < end24
        } else {
            isInTimeWindow = currentHour >= start24 || currentHour < end24
        }

        guard isInTimeWindow else {
            print("DEBUG checkAndRotateIfNeeded: Outside time window")
            if currentWord == nil {
                // Show a word even outside the window on first load
                rotateWord()
            }
            return
        }

        // Calculate today's window start
        var windowStartComponents = calendar.dateComponents([.year, .month, .day], from: now)
        windowStartComponents.hour = start24
        windowStartComponents.minute = 0
        windowStartComponents.second = 0
        
        guard let todayWindowStart = calendar.date(from: windowStartComponents) else {
            return
        }

        let rotationInterval = calculateRotationInterval()
        guard rotationInterval > 0, rotationInterval.isFinite else {
            return
        }

        // Calculate time since today's window started
        let timeSinceWindowStart = now.timeIntervalSince(todayWindowStart)
        
        // Calculate which rotation number we should be on
        let expectedRotationNumber = Int(floor(timeSinceWindowStart / rotationInterval))
        
        // Calculate time since last rotation
        let timeSinceLastRotation = now.timeIntervalSince(lastRotation)
        
        print("DEBUG checkAndRotateIfNeeded:")
        print("  - Current time: \(now)")
        print("  - Window start: \(todayWindowStart)")
        print("  - Time since window start: \(timeSinceWindowStart)s")
        print("  - Expected rotation #: \(expectedRotationNumber)")
        print("  - Last rotation: \(lastRotation)")
        print("  - Time since last rotation: \(timeSinceLastRotation)s")
        print("  - Rotation interval: \(rotationInterval)s")

        // Rotate if enough time has passed OR if this is the first word
        if timeSinceLastRotation >= rotationInterval || currentWord == nil {
            print("DEBUG: Rotating word now")
            rotateWord()
        } else {
            print("DEBUG: Not time to rotate yet")
        }
    }

    private func convertTo24Hour(hour: Int, isPM: Bool) -> Int {
        if hour == 12 {
            return isPM ? 12 : 0
        }
        return isPM ? hour + 12 : hour
    }

    private func rotateWord() {
        // Get difficulty preferences
        let difficultyEasy = PreferencesStore.defaults.bool(forKey: PrefKey.difficultyEasy)
        let difficultyMedium = PreferencesStore.defaults.bool(forKey: PrefKey.difficultyMedium)
        let difficultyHard = PreferencesStore.defaults.bool(forKey: PrefKey.difficultyHard)

        // Filter by language - FIXED
        let isLearningNew = PreferencesStore.defaults.bool(forKey: PrefKey.isLearningNewLanguage)
        let targetCode = PreferencesStore.defaults.string(forKey: PrefKey.targetLanguageCode) ?? ""
        let nativeCode = PreferencesStore.defaults.string(forKey: PrefKey.nativeLanguageCode) ?? ""

        // When learning a new language, show words in the TARGET language
        // When learning native language, show words in the NATIVE language
        let languageCode = isLearningNew ? targetCode : nativeCode

        // Filter vocabulary
        var candidates = allVocabulary.filter { entry in
            entry.languageCode == languageCode
                && ((entry.difficulty == .easy && difficultyEasy)
                    || (entry.difficulty == .medium && difficultyMedium)
                    || (entry.difficulty == .hard && difficultyHard))
        }

        // Remove recently shown words
        let recentIds = Set(vocabularyHistory.entries.suffix(5))
        candidates = candidates.filter { !recentIds.contains($0.id) }

        // Pick random word
        if let newWord = candidates.randomElement() {
            currentWord = newWord
            addToHistory(newWord)
            vocabularyHistory.lastRotation = Date()
            saveHistory()

            if let indexInAll = allVocabulary.firstIndex(where: { $0.id == newWord.id }) {
                let rotationInterval = calculateRotationInterval()
                persistRotationState(currentIndex: indexInAll, lastRotationDate: vocabularyHistory.lastRotation, rotationInterval: rotationInterval)
            }

            // Force immediate widget reload with shorter delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    // MARK: - History Management

    private func addToHistory(_ entry: VocabularyEntry) {
        vocabularyHistory.entries.append(entry.id)

        // Keep last 20 entries
        if vocabularyHistory.entries.count > 20 {
            vocabularyHistory.entries.removeFirst(vocabularyHistory.entries.count - 20)
        }

        // Update published history
        history = vocabularyHistory.entries.compactMap { id in
            allVocabulary.first { $0.id == id }
        }
    }

    func getEntry(byId id: String) -> VocabularyEntry? {
        allVocabulary.first { $0.id == id }
    }

    // MARK: - Shared State Management

    private func persistRotationState(currentIndex: Int, lastRotationDate: Date, rotationInterval: TimeInterval) {
        sharedDefaults?.set(currentIndex, forKey: "lexis.currentIndex")
        sharedDefaults?.set(lastRotationDate, forKey: "lexis.lastRotationDate")
        sharedDefaults?.set(rotationInterval, forKey: "lexis.rotationInterval")

        let isLearningNew = PreferencesStore.defaults.bool(forKey: PrefKey.isLearningNewLanguage)
        sharedDefaults?.set(isLearningNew, forKey: "lexis.isLearningNew")

        // Export JSON-encoded minimal word list for the widget to read
        saveSharedWordListJSON()

        sharedDefaults?.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func saveSharedWordListJSON() {
        struct SharedDefinition: Codable {
            let text: String
            let number: Int
        }
        struct SharedExample: Codable {
            let original: String
            let romanization: String?
            let translation: String?
        }
        struct SharedWord: Codable {
            let id: String
            let word: String
            let partOfSpeech: String
            let pronunciation: String?
            let languageCode: String
            let alternateScript: String?
            let translation: String?
            let translationLanguageCode: String?
            let definitions: [SharedDefinition]?
            let exampleSentences: [SharedExample]?
            let difficulty: String?
        }

        let sharedList: [SharedWord] = allVocabulary.map { v in
            let defs = v.definitions?.map { SharedDefinition(text: $0.text, number: $0.number ?? 0) }
            let examples = v.exampleSentences?.map { SharedExample(original: $0.original, romanization: $0.romanization, translation: $0.translation) }
            let diff = String(describing: v.difficulty)
            return SharedWord(
                id: v.id,
                word: v.word,
                partOfSpeech: v.partOfSpeech,
                pronunciation: v.pronunciation,
                languageCode: v.languageCode,
                alternateScript: v.alternateScript,
                translation: v.translation,
                translationLanguageCode: v.translationLanguageCode,
                definitions: defs,
                exampleSentences: examples,
                difficulty: diff
            )
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(sharedList) {
            sharedDefaults?.set(data, forKey: "lexis.wordListJSON")
        } else {
            // fallback to simple string array if encoding fails
            let words = allVocabulary.map { $0.word }
            sharedDefaults?.set(words, forKey: "lexis.wordList")
        }
    }

    // compute index for any date using base state
    private func indexFor(date: Date = .now, baseIndex: Int, baseDate: Date, rotationInterval: TimeInterval, totalCount: Int) -> Int {
        guard rotationInterval > 0, totalCount > 0 else { return baseIndex % max(1, totalCount) }
        let elapsed = date.timeIntervalSince(baseDate)
        let steps = Int(floor(elapsed / rotationInterval))
        return (baseIndex + steps) % totalCount
    }

    // on init / app launch, read shared state and catch up
    private func reconcileFromSharedState() {
        // If widget/app shared state exists, advance currentWord to the appropriate index.
        guard
            let baseDate = sharedDefaults?.object(forKey: "lexis.lastRotationDate") as? Date,
            let baseIndex = sharedDefaults?.object(forKey: "lexis.currentIndex") as? Int
        else { return }

        let rotationInterval = sharedDefaults?.double(forKey: "lexis.rotationInterval") ?? calculateRotationInterval()
        guard rotationInterval > 0, !allVocabulary.isEmpty else { return }

        let elapsed = Date().timeIntervalSince(baseDate)
        let steps = Int(floor(elapsed / rotationInterval))
        let newIndex = (baseIndex + steps) % max(1, allVocabulary.count)

        // Update currentWord and history to reflect the shared index
        let newWord = allVocabulary[newIndex]
        currentWord = newWord
        addToHistory(newWord)
        // move lastRotation forward to the most recent boundary
        vocabularyHistory.lastRotation = baseDate.addingTimeInterval(Double(steps) * rotationInterval)
        saveHistory()
    }

    // MARK: - Sample Data

    private func createSampleData() -> [VocabularyEntry] {
        [
            // Japanese words (for learning Japanese)
            VocabularyEntry(
                word: "やさい",
                partOfSpeech: "noun",
                pronunciation: "ya·sa·i",
                languageCode: "ja",
                alternateScript: "野菜",
                translation: "vegetable",
                translationLanguageCode: "en",
                exampleSentences: [
                    VocabularyEntry.ExampleSentence(
                        original: "わたしはまいにちやさいをたべます。",
                        romanization: "Watashi wa mainichi yasai o tabemasu。",
                        translation: "I eat vegetables every day."
                    )
                ],
                difficulty: .easy
            ),
            VocabularyEntry(
                word: "わたし",
                partOfSpeech: "pronoun",
                pronunciation: "wa·ta·shi",
                languageCode: "ja",
                alternateScript: "私",
                translation: "I, me",
                translationLanguageCode: "en",
                exampleSentences: [
                    VocabularyEntry.ExampleSentence(
                        original: "わたしはがくせいです。",
                        romanization: "Watashi wa gakusei desu。",
                        translation: "I am a student."
                    )
                ],
                difficulty: .easy
            ),
            VocabularyEntry(
                word: "あなた",
                partOfSpeech: "pronoun",
                pronunciation: "a·na·ta",
                languageCode: "ja",
                translation: "you",
                translationLanguageCode: "en",
                exampleSentences: [
                    VocabularyEntry.ExampleSentence(
                        original: "あなたはだれですか。",
                        romanization: "Anata wa dare desu ka。",
                        translation: "Who are you?"
                    )
                ],
                difficulty: .easy
            ),
            VocabularyEntry(
                word: "ともだち",
                partOfSpeech: "noun",
                pronunciation: "to·mo·da·chi",
                languageCode: "ja",
                alternateScript: "友達",
                translation: "friend",
                translationLanguageCode: "en",
                exampleSentences: [
                    VocabularyEntry.ExampleSentence(
                        original: "かのじょはわたしのともだちです。",
                        romanization: "Kanojo wa watashi no tomodachi desu。",
                        translation: "She is my friend."
                    )
                ],
                difficulty: .medium
            ),
            VocabularyEntry(
                word: "べんきょう",
                partOfSpeech: "noun",
                pronunciation: "ben·kyō",
                languageCode: "ja",
                alternateScript: "勉強",
                translation: "study",
                translationLanguageCode: "en",
                exampleSentences: [
                    VocabularyEntry.ExampleSentence(
                        original: "まいにちべんきょうします。",
                        romanization: "Mainichi benkyō shimasu。",
                        translation: "I study every day."
                    )
                ],
                difficulty: .medium
            ),

            // English words (for learning advanced English vocabulary)
            VocabularyEntry(
                word: "tergiversate",
                partOfSpeech: "verb",
                pronunciation: "ter·gi·ver·sate",
                languageCode: "en",
                definitions: [
                    VocabularyEntry.Definition(
                        text: "make conflicting or evasive statements; equivocate.", number: 1),
                    VocabularyEntry.Definition(
                        text: "change one's loyalties; be apostate.", number: 2),
                ],
                origin:
                    "mid 17th century: from Latin tergiversat- 'with one's back turned', from the verb tergiversari, from tergum 'back' + vertere 'to turn'.",
                synonyms: ["weasel", "beat about the bush", "equivocate"],
                difficulty: .hard
            ),
            VocabularyEntry(
                word: "esoteric",
                partOfSpeech: "adjective",
                pronunciation: "es·o·ter·ic",
                languageCode: "en",
                definitions: [
                    VocabularyEntry.Definition(
                        text:
                            "intended for or likely to be understood by only a small number of people with a specialized knowledge or interest.",
                        number: 1)
                ],
                origin:
                    "mid 17th century: from Greek esōterikos, from esōterō, comparative of esō 'within'.",
                synonyms: ["abstruse", "obscure", "arcane", "recondite"],
                difficulty: .hard
            ),
            VocabularyEntry(
                word: "irrefutable",
                partOfSpeech: "adjective",
                pronunciation: "ir·ref·u·ta·ble",
                languageCode: "en",
                definitions: [
                    VocabularyEntry.Definition(text: "impossible to deny or disprove.", number: 1)
                ],
                origin:
                    "early 17th century: from late Latin irrefutabilis, from in- 'not' + refutabilis (from refutare 'repel').",
                synonyms: ["indisputable", "undeniable", "unquestionable", "incontrovertible"],
                difficulty: .medium
            ),
            VocabularyEntry(
                word: "acquiesce",
                partOfSpeech: "verb",
                pronunciation: "ac·qui·esce",
                languageCode: "en",
                definitions: [
                    VocabularyEntry.Definition(
                        text: "accept something reluctantly but without protest.", number: 1)
                ],
                origin:
                    "early 17th century: from Latin acquiescere, from ad- 'to, at' + quiescere 'to rest'.",
                synonyms: ["consent", "agree", "comply", "concur"],
                difficulty: .medium
            ),
            VocabularyEntry(
                word: "wanton",
                partOfSpeech: "adjective",
                pronunciation: "wan·ton",
                languageCode: "en",
                definitions: [
                    VocabularyEntry.Definition(text: "deliberate and unprovoked.", number: 1),
                    VocabularyEntry.Definition(text: "growing profusely; luxuriant.", number: 2),
                ],
                origin:
                    "Middle English wantowen 'rebellious, lacking discipline', from wan- 'badly' + Old English togen 'trained'.",
                synonyms: ["deliberate", "willful", "malicious", "gratuitous"],
                difficulty: .hard
            ),
            VocabularyEntry(
                word: "ken",
                partOfSpeech: "noun",
                pronunciation: "ken",
                languageCode: "en",
                definitions: [
                    VocabularyEntry.Definition(
                        text: "one's range of knowledge or sight.", number: 1)
                ],
                origin:
                    "mid 16th century: from ken (verb), from Old English cennan 'tell, make known'.",
                synonyms: ["knowledge", "understanding", "awareness", "perception"],
                difficulty: .medium
            ),
        ]
    }
}
