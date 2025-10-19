import Combine
import Foundation
import WidgetKit
import UIKit // added

class VocabularyStore: ObservableObject {
    static let shared = VocabularyStore()

    private static let appGroupIdentifier = "group.com.jogong2718.lexis"
    private let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier)!

    @Published var currentWord: VocabularyWord?
    @Published var history: [VocabularyWord] = []

    private var allVocabulary: [VocabularyWord] = []
    private var cancellables = Set<AnyCancellable>()

    // Snapshot to detect only meaningful settings changes
    private var lastSettingsSnapshot: String = ""

    private init() {
        loadVocabulary()
        // capture initial snapshot so our own writes won't trigger handling
        lastSettingsSnapshot = settingsSnapshot()
        refreshFromSharedState()
        observeSettingsChanges()

        // Observe app lifecycle to refresh state when app becomes active / foregrounded.
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.refreshFromSharedState()
            }
            .store(in: &cancellables)
    }

    // MARK: - Loading

    private func loadVocabulary() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        func decodeVocabulary(from data: Data) -> [VocabularyWord]? {
            if let vocabulary = try? decoder.decode([VocabularyWord].self, from: data) {
                return vocabulary
            }
            if let wrapped = try? decoder.decode(VocabularyFile.self, from: data) {
                return wrapped.entries
            }
            return nil
        }

        // Try App Group first
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier) {
            let fileURL = containerURL.appendingPathComponent("vocabulary.json")
            if let data = try? Data(contentsOf: fileURL), let vocab = decodeVocabulary(from: data) {
                allVocabulary = vocab
                print("Loaded \(vocab.count) entries from app group")
                return
            }
        }

        // Try bundled resources
        let bundleCandidates: [URL?] = [
            Bundle.main.url(forResource: "vocabulary", withExtension: "json"),
            Bundle.main.url(forResource: "Data/vocabulary", withExtension: "json")
        ]

        for candidate in bundleCandidates.compactMap({ $0 }) {
            if let data = try? Data(contentsOf: candidate), let vocab = decodeVocabulary(from: data) {
                allVocabulary = vocab
                print("Loaded \(vocab.count) entries from bundle")
                saveToAppGroup()
                return
            }
        }

        // Fallback to sample data
        allVocabulary = createSampleData()
        saveToAppGroup()
    }

    private func saveToAppGroup() {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier) else { return }
        let fileURL = containerURL.appendingPathComponent("vocabulary.json")
        if let data = try? JSONEncoder().encode(allVocabulary) {
            try? data.write(to: fileURL)
        }
    }

    // MARK: - Observe Settings Changes

    private func observeSettingsChanges() {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let snap = self.settingsSnapshot()
                // only act when relevant user-facing settings changed
                if snap != self.lastSettingsSnapshot {
                    self.lastSettingsSnapshot = snap
                    self.handleSettingsChange()
                } else {
                    // ignore changes caused by our own shared state writes
                }
            }
            .store(in: &cancellables)
    }

    // Build a compact snapshot string of the user-configurable settings
    private func settingsSnapshot() -> String {
        let d = PreferencesStore.defaults
        let parts: [String] = [
            String(d.bool(forKey: PrefKey.isLearningNewLanguage)),
            d.string(forKey: PrefKey.nativeLanguageCode) ?? "",
            d.string(forKey: PrefKey.targetLanguageCode) ?? "",
            String(d.bool(forKey: PrefKey.difficultyEasy)),
            String(d.bool(forKey: PrefKey.difficultyMedium)),
            String(d.bool(forKey: PrefKey.difficultyHard)),
            String(d.integer(forKey: PrefKey.frequencyMin)),
            String(d.integer(forKey: PrefKey.frequencyMax)),
            String(d.integer(forKey: PrefKey.startHour)),
            String(d.integer(forKey: PrefKey.startMinute)),
            String(d.bool(forKey: PrefKey.startIsPM)),
            String(d.integer(forKey: PrefKey.endHour)),
            String(d.integer(forKey: PrefKey.endMinute)),
            String(d.bool(forKey: PrefKey.endIsPM))
        ]
        return parts.joined(separator: "|")
    }

    private func handleSettingsChange() {
        regenerateWordList()
        forceRotation()
    }

    // MARK: - Deterministic Word Selection

    func refreshFromSharedState() {
        let wordList = loadSharedWordList()
        guard !wordList.isEmpty else {
            currentWord = nil
            return
        }

        let baseIndex = sharedDefaults.integer(forKey: PrefKey.currentIndex)
        let baseDate = sharedDefaults.object(forKey: PrefKey.lastRotationDate) as? Date ?? Date()
        let rotationInterval = sharedDefaults.double(forKey: PrefKey.rotationInterval)

        let currentIndex = calculateCurrentIndex(baseIndex: baseIndex, baseDate: baseDate, rotationInterval: rotationInterval, totalCount: wordList.count)
        currentWord = wordList[safe: currentIndex]

        loadHistory()
    }

    private func calculateCurrentIndex(baseIndex: Int, baseDate: Date, rotationInterval: TimeInterval, totalCount: Int) -> Int {
        guard rotationInterval > 0, totalCount > 0 else { return 0 }
        
        let now = Date()
        if !isInActiveWindow(now) { return baseIndex }
        
        let elapsed = now.timeIntervalSince(baseDate)
        let steps = Int(floor(elapsed / rotationInterval))
        return (baseIndex + steps) % totalCount
    }

    private func loadSharedWordList() -> [VocabularyWord] {
        guard let data = sharedDefaults.data(forKey: PrefKey.wordListJSON) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([VocabularyWord].self, from: data)) ?? []
    }

    private func loadHistory() {
        guard let data = sharedDefaults.data(forKey: PrefKey.historyJSON) else {
            history = []
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        history = (try? decoder.decode([VocabularyWord].self, from: data)) ?? []
    }

    // MARK: - Word Rotation

    func checkAndRotateIfNeeded() {
        let now = Date()
        print("DEBUG: Checking rotation at \(now)")
        guard isInActiveWindow(now) else {
            print("DEBUG: Not in active window")
            return
        }

        // Obtain timeRemaining first so we can log it safely (guard binding in else block can't access it).
        let timeRemaining = getTimeUntilNextRotation()
        if let remaining = timeRemaining {
            if remaining < 1 {
                print("DEBUG: Time to rotate word! (remaining: \(remaining))")
                rotateWord()
            } else {
                print("DEBUG: Time remaining: \(remaining)")
            }
        } else {
            print("DEBUG: getTimeUntilNextRotation returned nil")
        }
    }

    func forceRotation() {
        rotateWord()
    }

    private func rotateWord() {
        print("DEBUG: Rotating word...")
        let wordList = generateFilteredWordList()
        print("DEBUG: Generated word list with \(wordList.count) entries")
        guard !wordList.isEmpty else { 
            print("DEBUG: No words available for rotation")
            return
        }
        let currentIndex = sharedDefaults.integer(forKey: PrefKey.currentIndex)
        let nextIndex = (currentIndex + 1) % wordList.count
        let nextWord = wordList[nextIndex]

        print("DEBUG: Next word is \(nextWord.word) (index \(nextIndex))")
        print("DEBUG: Current word is \(currentWord?.word) (index \(currentIndex))")
        print("DEBUG: Rotating from \(currentWord?.word) to \(nextWord.word)")

        addToHistory(nextWord)
        updateSharedState(index: nextIndex, word: nextWord, wordList: wordList)

        print("DEBUG: Rotation complete. New current word is \(nextWord.word)")
        
        currentWord = nextWord
        
        WidgetCenter.shared.reloadAllTimelines()
        NotificationCenter.default.post(name: NSNotification.Name("VocabularyWordChanged"), object: nil)

        print("DEBUG: Posted VocabularyWordChanged notification")
    }

    private func regenerateWordList() {
        let wordList = generateFilteredWordList()
        let rotationInterval = calculateRotationInterval()
        
        guard !wordList.isEmpty else { return }
        
        let currentWord = wordList.first!
        addToHistory(currentWord)
        updateSharedState(index: 0, word: currentWord, wordList: wordList)
        
        self.currentWord = currentWord
    }

    private func updateSharedState(index: Int, word: VocabularyWord, wordList: [VocabularyWord]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        sharedDefaults.set(index, forKey: PrefKey.currentIndex)
        sharedDefaults.set(Date(), forKey: PrefKey.lastRotationDate)
        sharedDefaults.set(calculateRotationInterval(), forKey: PrefKey.rotationInterval)
        sharedDefaults.set(word.id, forKey: PrefKey.currentWordId)
        
        if let wordListData = try? encoder.encode(wordList) {
            sharedDefaults.set(wordListData, forKey: PrefKey.wordListJSON)
        }
        
        saveTimeWindowSettings()
        sharedDefaults.synchronize()
    }

    private func saveTimeWindowSettings() {
        let startHour = PreferencesStore.defaults.integer(forKey: PrefKey.startHour)
        let endHour = PreferencesStore.defaults.integer(forKey: PrefKey.endHour)
        let startIsPM = PreferencesStore.defaults.bool(forKey: PrefKey.startIsPM)
        let endIsPM = PreferencesStore.defaults.bool(forKey: PrefKey.endIsPM)
        let isLearningNew = PreferencesStore.defaults.bool(forKey: PrefKey.isLearningNewLanguage)
        
        sharedDefaults.set(startHour, forKey: "lexis.startHour")
        sharedDefaults.set(endHour, forKey: "lexis.endHour")
        sharedDefaults.set(startIsPM, forKey: "lexis.startIsPM")
        sharedDefaults.set(endIsPM, forKey: "lexis.endIsPM")
        sharedDefaults.set(isLearningNew, forKey: "lexis.isLearningNew")
    }

    private func addToHistory(_ word: VocabularyWord) {
        history.append(word)
        if history.count > 20 {
            history.removeFirst()
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(history) {
            sharedDefaults.set(data, forKey: PrefKey.historyJSON)
        }
    }

    private func generateFilteredWordList() -> [VocabularyWord] {
        let difficultyEasy = PreferencesStore.defaults.bool(forKey: PrefKey.difficultyEasy)
        let difficultyMedium = PreferencesStore.defaults.bool(forKey: PrefKey.difficultyMedium)
        let difficultyHard = PreferencesStore.defaults.bool(forKey: PrefKey.difficultyHard)
        let isLearningNew = PreferencesStore.defaults.bool(forKey: PrefKey.isLearningNewLanguage)
        let languageCode = isLearningNew 
            ? (PreferencesStore.defaults.string(forKey: PrefKey.targetLanguageCode) ?? "")
            : (PreferencesStore.defaults.string(forKey: PrefKey.nativeLanguageCode) ?? "")

        var filtered = allVocabulary.filter { word in
            word.languageCode == languageCode &&
            ((word.difficulty == .easy && difficultyEasy) ||
             (word.difficulty == .medium && difficultyMedium) ||
             (word.difficulty == .hard && difficultyHard))
        }

        let recentIds = Set(history.suffix(2).map { $0.id })
        filtered = filtered.filter { !recentIds.contains($0.id) }

        return filtered
    }

    // MARK: - Time Window Logic

    private func isInActiveWindow(_ date: Date) -> Bool {
        let startHour = PreferencesStore.defaults.integer(forKey: PrefKey.startHour)
        let endHour = PreferencesStore.defaults.integer(forKey: PrefKey.endHour)
        let startIsPM = PreferencesStore.defaults.bool(forKey: PrefKey.startIsPM)
        let endIsPM = PreferencesStore.defaults.bool(forKey: PrefKey.endIsPM)

        let start24 = convertTo24Hour(hour: startHour, isPM: startIsPM)
        let end24 = convertTo24Hour(hour: endHour, isPM: endIsPM)

        let currentHour = Calendar.current.component(.hour, from: date)

        if start24 <= end24 {
            return currentHour >= start24 && currentHour < end24
        } else {
            return currentHour >= start24 || currentHour < end24
        }
    }

    func getTimeUntilNextRotation() -> TimeInterval? {
        let rotationInterval = calculateRotationInterval()
        guard rotationInterval > 0 else { return nil }

        let now = Date()
        guard isInActiveWindow(now) else {
            return timeUntilWindowStart()
        }

        let baseDate = sharedDefaults.object(forKey: PrefKey.lastRotationDate) as? Date ?? now
        let elapsed = now.timeIntervalSince(baseDate)
        let timeToNext = rotationInterval - elapsed.truncatingRemainder(dividingBy: rotationInterval)
        
        return max(0, timeToNext)
    }

    private func timeUntilWindowStart() -> TimeInterval {
        let startHour = PreferencesStore.defaults.integer(forKey: PrefKey.startHour)
        let startIsPM = PreferencesStore.defaults.bool(forKey: PrefKey.startIsPM)
        let start24 = convertTo24Hour(hour: startHour, isPM: startIsPM)

        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = start24
        components.minute = 0
        components.second = 0

        if currentHour < start24 {
            let nextStart = calendar.date(from: components) ?? now
            return nextStart.timeIntervalSince(now)
        } else {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
            components.hour = start24
            components.minute = 0
            components.second = 0
            let nextStart = calendar.date(from: components) ?? now
            return nextStart.timeIntervalSince(now)
        }
    }

    func calculateRotationInterval() -> TimeInterval {
        let frequencyMin = PreferencesStore.defaults.integer(forKey: PrefKey.frequencyMin)
        let frequencyMax = PreferencesStore.defaults.integer(forKey: PrefKey.frequencyMax)
        let startHour = PreferencesStore.defaults.integer(forKey: PrefKey.startHour)
        let endHour = PreferencesStore.defaults.integer(forKey: PrefKey.endHour)
        let startIsPM = PreferencesStore.defaults.bool(forKey: PrefKey.startIsPM)
        let endIsPM = PreferencesStore.defaults.bool(forKey: PrefKey.endIsPM)

        guard frequencyMin > 0, frequencyMax > 0, frequencyMin <= frequencyMax else { return 3600.0 }

        let start24 = convertTo24Hour(hour: startHour, isPM: startIsPM)
        let end24 = convertTo24Hour(hour: endHour, isPM: endIsPM)

        let activeHours = Double(start24 <= end24 ? (end24 - start24) : (24 - start24 + end24))
        guard activeHours > 0 else { return 3600.0 }

        let avgFrequency = Double(frequencyMin + frequencyMax) / 2.0
        return (activeHours * 3600.0) / avgFrequency
    }

    private func convertTo24Hour(hour: Int, isPM: Bool) -> Int {
        if hour == 12 { return isPM ? 12 : 0 }
        return isPM ? hour + 12 : hour
    }

    // MARK: - Sample Data

    private func createSampleData() -> [VocabularyWord] {
        [
            VocabularyWord(
                id: UUID().uuidString,
                word: "やさい",
                partOfSpeech: "noun",
                pronunciation: "ya·sa·i",
                languageCode: "ja",
                alternateScript: "野菜",
                translation: "vegetable",
                translationLanguageCode: "en",
                exampleSentences: [
                    VocabularyWord.ExampleSentence(
                        original: "わたしはまいにちやさいをたべます。",
                        romanization: "Watashi wa mainichi yasai o tabemasu。",
                        translation: "I eat vegetables every day."
                    )
                ],
                difficulty: .easy
            ),
            VocabularyWord(
                id: UUID().uuidString,
                word: "わたし",
                partOfSpeech: "pronoun",
                pronunciation: "wa·ta·shi",
                languageCode: "ja",
                alternateScript: "私",
                translation: "I, me",
                translationLanguageCode: "en",
                exampleSentences: [
                    VocabularyWord.ExampleSentence(
                        original: "わたしはがくせいです。",
                        romanization: "Watashi wa gakusei desu。",
                        translation: "I am a student."
                    )
                ],
                difficulty: .easy
            ),
            VocabularyWord(
                id: UUID().uuidString,
                word: "あなた",
                partOfSpeech: "pronoun",
                pronunciation: "a·na·ta",
                languageCode: "ja",
                translation: "you",
                translationLanguageCode: "en",
                exampleSentences: [
                    VocabularyWord.ExampleSentence(
                        original: "あなたはだれですか。",
                        romanization: "Anata wa dare desu ka。",
                        translation: "Who are you?"
                    )
                ],
                difficulty: .easy
            ),
            VocabularyWord(
                id: UUID().uuidString,
                word: "ともだち",
                partOfSpeech: "noun",
                pronunciation: "to·mo·da·chi",
                languageCode: "ja",
                alternateScript: "友達",
                translation: "friend",
                translationLanguageCode: "en",
                exampleSentences: [
                    VocabularyWord.ExampleSentence(
                        original: "かのじょはわたしのともだちです。",
                        romanization: "Kanojo wa watashi no tomodachi desu。",
                        translation: "She is my friend."
                    )
                ],
                difficulty: .medium
            ),
            VocabularyWord(
                id: UUID().uuidString,
                word: "べんきょう",
                partOfSpeech: "noun",
                pronunciation: "ben·kyō",
                languageCode: "ja",
                alternateScript: "勉強",
                translation: "study",
                translationLanguageCode: "en",
                exampleSentences: [
                    VocabularyWord.ExampleSentence(
                        original: "まいにちべんきょうします。",
                        romanization: "Mainichi benkyō shimasu。",
                        translation: "I study every day."
                    )
                ],
                difficulty: .medium
            ),

            VocabularyWord(
                id: UUID().uuidString,
                word: "tergiversate",
                partOfSpeech: "verb",
                pronunciation: "ter·gi·ver·sate",
                languageCode: "en",
                definitions: [
                    VocabularyWord.Definition(
                        text: "make conflicting or evasive statements; equivocate.", number: 1),
                    VocabularyWord.Definition(
                        text: "change one's loyalties; be apostate.", number: 2),
                ],
                origin:
                    "mid 17th century: from Latin tergiversat- 'with one's back turned', from the verb tergiversari, from tergum 'back' + vertere 'to turn'.",
                synonyms: ["weasel", "beat about the bush", "equivocate"],
                difficulty: .hard
            ),
            VocabularyWord(
                id: UUID().uuidString,
                word: "esoteric",
                partOfSpeech: "adjective",
                pronunciation: "es·o·ter·ic",
                languageCode: "en",
                definitions: [
                    VocabularyWord.Definition(
                        text:
                            "intended for or likely to be understood by only a small number of people with a specialized knowledge or interest.",
                        number: 1)
                ],
                origin:
                    "mid 17th century: from Greek esōterikos, from esōterō, comparative of esō 'within'.",
                synonyms: ["abstruse", "obscure", "arcane", "recondite"],
                difficulty: .hard
            ),
            VocabularyWord(
                id: UUID().uuidString,
                word: "irrefutable",
                partOfSpeech: "adjective",
                pronunciation: "ir·ref·u·ta·ble",
                languageCode: "en",
                definitions: [
                    VocabularyWord.Definition(text: "impossible to deny or disprove.", number: 1)
                ],
                origin:
                    "early 17th century: from late Latin irrefutabilis, from in- 'not' + refutabilis (from refutare 'repel').",
                synonyms: ["indisputable", "undeniable", "unquestionable", "incontrovertible"],
                difficulty: .medium
            ),
            VocabularyWord(
                id: UUID().uuidString,
                word: "acquiesce",
                partOfSpeech: "verb",
                pronunciation: "ac·qui·esce",
                languageCode: "en",
                definitions: [
                    VocabularyWord.Definition(
                        text: "accept something reluctantly but without protest.", number: 1)
                ],
                origin:
                    "early 17th century: from Latin acquiescere, from ad- 'to, at' + quiescere 'to rest'.",
                synonyms: ["consent", "agree", "comply", "concur"],
                difficulty: .medium
            ),
            VocabularyWord(
                id: UUID().uuidString,
                word: "wanton",
                partOfSpeech: "adjective",
                pronunciation: "wan·ton",
                languageCode: "en",
                definitions: [
                    VocabularyWord.Definition(text: "deliberate and unprovoked.", number: 1),
                    VocabularyWord.Definition(text: "growing profusely; luxuriant.", number: 2),
                ],
                origin:
                    "Middle English wantowen 'rebellious, lacking discipline', from wan- 'badly' + Old English togen 'trained'.",
                synonyms: ["deliberate", "willful", "malicious", "gratuitous"],
                difficulty: .hard
            ),
            VocabularyWord(
                id: UUID().uuidString,
                word: "ken",
                partOfSpeech: "noun",
                pronunciation: "ken",
                languageCode: "en",
                definitions: [
                    VocabularyWord.Definition(
                        text: "one's range of knowledge or sight.", number: 1)
                ],
                origin:
                    "mid 16th century: from ken (verb), from Old English cennan 'tell, make known'.",
                synonyms: ["knowledge", "understanding", "awareness", "perception"],
                difficulty: .medium
            ),
        ]
    }

    private struct VocabularyFile: Codable {
        let entries: [VocabularyWord]
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
