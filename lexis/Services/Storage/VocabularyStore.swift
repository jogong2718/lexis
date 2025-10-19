import Combine
import Foundation
import WidgetKit

class VocabularyStore: ObservableObject {
    static let shared = VocabularyStore()

    // Add App Group identifier
    private static let appGroupIdentifier = "group.com.jogong2718.lexis"
    private let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier)

    // Remove @Published currentWord - make it computed from shared state
    var currentWord: VocabularyWord? {
        // Try to read shared index and map into our in-memory allVocabulary via the shared list's ids.
        let baseIndex = sharedDefaults?.integer(forKey: "lexis.currentIndex") ?? 0

        // If a shared JSON list exists, use it to map id -> allVocabulary.
        // IMPORTANT: if the shared list decodes successfully but is empty, treat that as "no current word".
        if let data = sharedDefaults?.data(forKey: "lexis.wordListJSON") {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let sharedList = try? decoder.decode([VocabularyWord].self, from: data) {
                if sharedList.isEmpty {
                    // Shared export intentionally empty (no candidates) — no current word.
                    print("APP: shared word list decoded and is empty -> no current word")
                    return nil
                }
                let safeIndex = (baseIndex % sharedList.count + sharedList.count) % sharedList.count
                let id = sharedList[safeIndex].id
                if let found = allVocabulary.first(where: { $0.id == id }) {
                    return found
                } else {
                    // fallback to legacy behavior if id not found
                    print("APP: shared id \(id) not found in allVocabulary; falling back to legacy index semantics")
                }
            } else {
                // If decode failed, continue to fallback behavior below
            }
        }

        // Fallback: legacy behavior — interpret baseIndex as index into allVocabulary
        guard let legacyBaseIndex = sharedDefaults?.integer(forKey: "lexis.currentIndex") else {
            return nil
        }
        guard !allVocabulary.isEmpty else { return nil }

        let baseDate = sharedDefaults?.object(forKey: "lexis.lastRotationDate") as? Date ?? Date()
        let rotationInterval = sharedDefaults?.double(forKey: "lexis.rotationInterval") ?? calculateRotationInterval()

        let currentIndex = indexFor(
            date: Date(),
            baseIndex: legacyBaseIndex,
            baseDate: baseDate,
            rotationInterval: rotationInterval,
            totalCount: allVocabulary.count
        )

        let safeIndex = (currentIndex % allVocabulary.count + allVocabulary.count) % allVocabulary.count
        return allVocabulary[safeIndex]
    }
    
    @Published var history: [VocabularyWord] = []

    private var allVocabulary: [VocabularyWord] = []
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

            // Initialize shared state if needed
            if sharedDefaults?.object(forKey: "lexis.currentIndex") == nil {
                persistRotationState(currentIndex: 0, lastRotationDate: Date(), rotationInterval: calculateRotationInterval())
            }

            checkAndRotateIfNeeded()
            observeLanguageModeChanges()
            return
        }

        vocabularyFileURL = containerURL.appendingPathComponent("vocabulary.json")
        historyFileURL = containerURL.appendingPathComponent("history.json")

        loadVocabulary()
        loadHistory()

        // Initialize shared state if needed
        if sharedDefaults?.object(forKey: "lexis.currentIndex") == nil {
            persistRotationState(currentIndex: 0, lastRotationDate: Date(), rotationInterval: calculateRotationInterval())
        }

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
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Try to decode a Data blob into [VocabularyWord] using multiple strategies
        func decodeVocabulary(from data: Data) -> [VocabularyWord]? {
            if let vocabulary = try? decoder.decode([VocabularyWord].self, from: data) {
                return vocabulary
            }
            if let wrapped = try? decoder.decode(VocabularyFile.self, from: data) {
                return wrapped.entries
            }
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let entriesArray = json["entries"] {
                if let entriesData = try? JSONSerialization.data(withJSONObject: entriesArray, options: []) {
                    if let vocabulary = try? decoder.decode([VocabularyWord].self, from: entriesData) {
                        return vocabulary
                    }
                }
            }
            return nil
        }

        // 1) Try to load from container/app-group file first (existing behavior) — capture decoded array and count
        print("Attempting to load vocabulary from app group container")
        var appVocabulary: [VocabularyWord]? = nil
        if let data = try? Data(contentsOf: vocabularyFileURL) {
            appVocabulary = decodeVocabulary(from: data)
            if appVocabulary == nil {
                print("Failed to decode app-group vocabulary file")
            } else {
                print("Loaded \(appVocabulary!.count) entries from app-group file")
            }
        } else {
            print("No app-group vocabulary file at \(vocabularyFileURL.path)")
        }

        // 2) Try to load the bundled resource vocabulary.json
        var bundleVocabulary: [VocabularyWord]? = nil
        let bundleCandidates: [URL?] = [
            Bundle.main.url(forResource: "vocabulary", withExtension: "json"),
            Bundle.main.url(forResource: "Data/vocabulary", withExtension: "json")
        ]

        for candidate in bundleCandidates.compactMap({ $0 }) {
            if let data = try? Data(contentsOf: candidate) {
                if let vocabulary = decodeVocabulary(from: data) {
                    bundleVocabulary = vocabulary
                    print("Loaded \(bundleVocabulary!.count) entries from bundled vocabulary at \(candidate.path)")
                    break
                } else {
                    print("Failed to decode bundled vocabulary at \(candidate.path)")
                }
            }
        }

        let appCount = appVocabulary?.count ?? 0
        let bundleCount = bundleVocabulary?.count ?? 0

        // 3) Decision: prefer bundle only when it has strictly more entries than app-group
        if bundleCount > appCount {
            print("Using bundled vocabulary (\(bundleCount)) because it has more entries than app-group (\(appCount))")
            allVocabulary = bundleVocabulary ?? []
            // Persist copy to app-group container so future launches use it
            saveVocabulary()
            return
        }

        // 4) Otherwise prefer app-group if available
        if appCount > 0 {
            print("Using app-group vocabulary with \(appCount) entries")
            allVocabulary = appVocabulary ?? []
            return
        }

        // 5) If no app-group but bundle exists, use bundle
        if bundleCount > 0 {
            print("App-group empty; using bundled vocabulary with \(bundleCount) entries")
            allVocabulary = bundleVocabulary ?? []
            saveVocabulary()
            return
        }

        // 6) Final fallback: existing sample data (safety net)
        print("No vocabulary found in app-group or bundle; falling back to sample data")
        allVocabulary = createSampleData()
        saveVocabulary()
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
            if sharedDefaults?.object(forKey: "lexis.currentIndex") == nil {
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

        // Rotate if enough time has passed OR if no word is set yet
        if timeSinceLastRotation >= rotationInterval - 1 || sharedDefaults?.object(forKey: "lexis.currentIndex") == nil {
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
        // Use the shared candidate list (language/difficulty/recent-history filtered)
        var candidates = sharedCandidateList()

        // Fallback: if sharedCandidateList returns empty, reproduce legacy filtering to avoid having no candidates
        if candidates.isEmpty {
            // Get difficulty preferences
            let difficultyEasy = PreferencesStore.defaults.bool(forKey: PrefKey.difficultyEasy)
            let difficultyMedium = PreferencesStore.defaults.bool(forKey: PrefKey.difficultyMedium)
            let difficultyHard = PreferencesStore.defaults.bool(forKey: PrefKey.difficultyHard)

            // Filter by language
            let isLearningNew = PreferencesStore.defaults.bool(forKey: PrefKey.isLearningNewLanguage)
            let targetCode = PreferencesStore.defaults.string(forKey: PrefKey.targetLanguageCode) ?? ""
            let nativeCode = PreferencesStore.defaults.string(forKey: PrefKey.nativeLanguageCode) ?? ""

            let languageCode = isLearningNew ? targetCode : nativeCode

            candidates = allVocabulary.filter { entry in
                entry.languageCode == languageCode
                    && ((entry.difficulty == .easy && difficultyEasy)
                        || (entry.difficulty == .medium && difficultyMedium)
                        || (entry.difficulty == .hard && difficultyHard))
            }

            // Remove recently shown words
            let recentIds = Set(vocabularyHistory.entries.suffix(2))
            candidates = candidates.filter { !recentIds.contains($0.id) }
        }

        // Pick random word if any candidates exist
        if let newWord = candidates.randomElement() {
            addToHistory(newWord)
            vocabularyHistory.lastRotation = Date()
            saveHistory()

            if let indexInAll = allVocabulary.firstIndex(where: { $0.id == newWord.id }) {
                let rotationInterval = calculateRotationInterval()
                persistRotationState(currentIndex: indexInAll, lastRotationDate: vocabularyHistory.lastRotation, rotationInterval: rotationInterval)
            }

            // Trigger UI update by posting notification
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("VocabularyWordChanged"), object: nil)
            }

            // Force widget reload
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                WidgetCenter.shared.reloadAllTimelines()
            }
        } else {
            print("DEBUG: rotateWord: no candidates available to choose from")
        }
    }

    // MARK: - History Management

    private func addToHistory(_ entry: VocabularyWord) {
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

    func getEntry(byId id: String) -> VocabularyWord? {
        allVocabulary.first { $0.id == id }
    }

    // MARK: - Shared State Management

    private func persistRotationState(currentIndex: Int, lastRotationDate: Date, rotationInterval: TimeInterval) {
        // Debug: print values being persisted
        print("APP: persistRotationState -> currentIndex(inAll)=\(currentIndex), lastRotationDate=\(lastRotationDate), rotationInterval=\(rotationInterval)")

        // Build the filtered shared list (language/difficulty + recent-history filtered) to export to the widget.
        let sharedList = sharedCandidateList()
        // Find index of the chosen word within the shared list (0 when not found / sharedList empty)
        let chosenId = allVocabulary.indices.contains(currentIndex) ? allVocabulary[currentIndex].id : ""
        let indexInShared = sharedList.firstIndex(where: { $0.id == chosenId }) ?? 0

        // Persist index relative to shared list (indexInShared may be 0 even when sharedList is empty)
        sharedDefaults?.set(indexInShared, forKey: "lexis.currentIndex")
        sharedDefaults?.set(lastRotationDate, forKey: "lexis.lastRotationDate")
        sharedDefaults?.set(rotationInterval, forKey: "lexis.rotationInterval")

        let isLearningNew = PreferencesStore.defaults.bool(forKey: PrefKey.isLearningNewLanguage)
        sharedDefaults?.set(isLearningNew, forKey: "lexis.isLearningNew")

        // Export time-window settings for the widget to respect
        let startHour = PreferencesStore.defaults.integer(forKey: PrefKey.startHour)
        let endHour = PreferencesStore.defaults.integer(forKey: PrefKey.endHour)
        let startIsPM = PreferencesStore.defaults.bool(forKey: PrefKey.startIsPM)
        let endIsPM = PreferencesStore.defaults.bool(forKey: PrefKey.endIsPM)
        sharedDefaults?.set(startHour, forKey: "lexis.startHour")
        sharedDefaults?.set(endHour, forKey: "lexis.endHour")
        sharedDefaults?.set(startIsPM, forKey: "lexis.startIsPM")
        sharedDefaults?.set(endIsPM, forKey: "lexis.endIsPM")

        // Export the filtered list for the widget to read — IMPORTANT: always write the filtered list (may be empty)
        saveSharedWordListJSON(sharedList: sharedList)

        // Debug: list keys after writing
        if let idx = sharedDefaults?.object(forKey: "lexis.currentIndex") {
            print("APP: shared lexis.currentIndex now = \(idx)")
        }
        if let date = sharedDefaults?.object(forKey: "lexis.lastRotationDate") as? Date {
            print("APP: shared lexis.lastRotationDate now = \(date)")
        }
        if let interval = sharedDefaults?.object(forKey: "lexis.rotationInterval") as? Double {
            print("APP: shared lexis.rotationInterval now = \(interval)")
        }
        if let learning = sharedDefaults?.object(forKey: "lexis.isLearningNew") {
            print("APP: shared lexis.isLearningNew now = \(learning)")
        }

        sharedDefaults?.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func saveSharedWordListJSON(sharedList: [VocabularyWord]?) {
        // Always write the filtered list. If sharedList == nil -> write empty array.
        let listToWrite = sharedList ?? []

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(listToWrite) {
            sharedDefaults?.set(data, forKey: "lexis.wordListJSON")
            print("APP: wrote lexis.wordListJSON bytes: \(data.count) (exporting \(listToWrite.count) entries)")
            if let preview = String(data: data.prefix(2048), encoding: .utf8) {
                print("APP: lexis.wordListJSON preview: \(preview.prefix(500))")
            }
        } else {
            // If encoding fails for some reason, explicitly write an empty JSON array to avoid exporting the full app list.
            let emptyData = Data("[]".utf8)
            sharedDefaults?.set(emptyData, forKey: "lexis.wordListJSON")
            print("APP: failed to encode shared list; wrote empty JSON array instead")
        }
    }

    // Build the same candidate list used when rotating a word (language + difficulty + recent history)
    private func sharedCandidateList() -> [VocabularyWord] {
        let difficultyEasy = PreferencesStore.defaults.bool(forKey: PrefKey.difficultyEasy)
        let difficultyMedium = PreferencesStore.defaults.bool(forKey: PrefKey.difficultyMedium)
        let difficultyHard = PreferencesStore.defaults.bool(forKey: PrefKey.difficultyHard)

        let isLearningNew = PreferencesStore.defaults.bool(forKey: PrefKey.isLearningNewLanguage)
        let targetCode = PreferencesStore.defaults.string(forKey: PrefKey.targetLanguageCode) ?? ""
        let nativeCode = PreferencesStore.defaults.string(forKey: PrefKey.nativeLanguageCode) ?? ""
        let languageCode = isLearningNew ? targetCode : nativeCode

        var candidates = allVocabulary.filter { entry in
            entry.languageCode == languageCode
                && ((entry.difficulty == .easy && difficultyEasy)
                    || (entry.difficulty == .medium && difficultyMedium)
                    || (entry.difficulty == .hard && difficultyHard))
        }

        // Remove recently shown words to match rotateWord behavior
        let recentIds = Set(vocabularyHistory.entries.suffix(2))
        candidates = candidates.filter { !recentIds.contains($0.id) }

        return candidates
    }

    // compute index for any date using base state
    private func indexFor(date: Date = .now, baseIndex: Int, baseDate: Date, rotationInterval: TimeInterval, totalCount: Int) -> Int {
        guard rotationInterval > 0, totalCount > 0 else { return baseIndex % max(1, totalCount) }
        let elapsed = date.timeIntervalSince(baseDate)
        let steps = Int(floor(elapsed / rotationInterval))
        return (baseIndex + steps) % totalCount
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

    // small wrapper matching the top-level shape of Resources/Data/vocabulary.json
    private struct VocabularyFile: Codable {
        let entries: [VocabularyWord]
    }
}