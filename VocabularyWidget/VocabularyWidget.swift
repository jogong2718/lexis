//
//  VocabularyWidget.swift
//  VocabularyWidget
//
//  Created by Jonathan Gong on 2025-10-17.
//

import SwiftUI
import WidgetKit

private let appGroupIdentifier = "group.com.jogong2718.lexis"
private let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier)

struct Provider: TimelineProvider {
    typealias Entry = VocabularyEntry

    func placeholder(in context: Context) -> VocabularyEntry {
        VocabularyEntry(date: Date(), word: sampleWord(), isLearningNew: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (VocabularyEntry) -> Void) {
        let entry = makeEntry(for: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VocabularyEntry>) -> Void) {
        let now = Date()
        let baseIndex = sharedDefaults?.integer(forKey: "lexis.currentIndex") ?? 0
        let baseDate = sharedDefaults?.object(forKey: "lexis.lastRotationDate") as? Date ?? now
        let rotationInterval = sharedDefaults?.double(forKey: "lexis.rotationInterval") ?? 3600
        let wordList = loadWordList() ?? []

        guard !wordList.isEmpty else {
            let entry = VocabularyEntry(date: now, word: nil, isLearningNew: sharedDefaults?.bool(forKey: "lexis.isLearningNew") ?? true)
            completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(300))))
            return
        }

        // Calculate current index based on elapsed time
        let elapsed = now.timeIntervalSince(baseDate)
        let stepsSinceBase = Int(floor(elapsed / rotationInterval))
        let currentIndex = (baseIndex + stepsSinceBase) % wordList.count
        
        // Calculate when the NEXT rotation should happen
        let timeToNextRotation = rotationInterval - (elapsed.truncatingRemainder(dividingBy: rotationInterval))
        let nextRotationDate = now.addingTimeInterval(timeToNextRotation)
        
        // Current word entry
        let currentWord = loadWordForIndex(currentIndex, from: wordList)
        let isLearning = sharedDefaults?.bool(forKey: "lexis.isLearningNew") ?? true
        let currentEntry = VocabularyEntry(date: now, word: currentWord, isLearningNew: isLearning)
        
        // Next word entry (for preloading)
        let nextIndex = (currentIndex + 1) % wordList.count
        let nextWord = loadWordForIndex(nextIndex, from: wordList)
        let nextEntry = VocabularyEntry(date: nextRotationDate, word: nextWord, isLearningNew: isLearning)
        
        // Refresh more frequently (every 5 minutes) to catch any state changes
        let refreshDate = min(nextRotationDate, now.addingTimeInterval(300))
        
        let timeline = Timeline(entries: [currentEntry, nextEntry], policy: .after(refreshDate))
        completion(timeline)
    }

    // Build a single entry for snapshot/placeholder
    private func makeEntry(for date: Date) -> VocabularyEntry {
        let baseIndex = sharedDefaults?.integer(forKey: "lexis.currentIndex") ?? 0
        let baseDate = sharedDefaults?.object(forKey: "lexis.lastRotationDate") as? Date ?? Date()
        let rotationInterval = sharedDefaults?.double(forKey: "lexis.rotationInterval") ?? 3600
        let wordList = loadWordList() ?? []
        let totalCount = max(1, wordList.count)
        let idx = indexFor(date: date, baseIndex: baseIndex, baseDate: baseDate, rotationInterval: rotationInterval, totalCount: totalCount)
        let word = loadWordForIndex(idx, from: wordList)
        let isLearning = sharedDefaults?.bool(forKey: "lexis.isLearningNew") ?? true
        return VocabularyEntry(date: date, word: word, isLearningNew: isLearning)
    }

    // Load decoded VocabularyWord list from App Group. Supports two formats:
    // 1) JSON-encoded [VocabularyWord] under "lexis.wordListJSON"
    // 2) Simple string array under "lexis.wordList" (backwards compatibility)
    private func loadWordList() -> [VocabularyWord]? {
        // Try JSON first
        if let data = sharedDefaults?.data(forKey: "lexis.wordListJSON") {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let decoded = try? decoder.decode([VocabularyWord].self, from: data) {
                return decoded
            }
        }

        // Fallback to simple string array
        if let strings = sharedDefaults?.stringArray(forKey: "lexis.wordList"), !strings.isEmpty {
            return strings.enumerated().map { idx, wordStr in
                VocabularyWord(
                    id: "w\(idx)",
                    word: wordStr,
                    partOfSpeech: "",
                    pronunciation: nil,
                    languageCode: "",
                    alternateScript: nil,
                    translation: nil,
                    translationLanguageCode: nil,
                    definitions: nil,
                    exampleSentences: nil,
                    difficulty: nil
                )
            }
        }

        return nil
    }

    private func loadWordForIndex(_ index: Int, from list: [VocabularyWord]) -> VocabularyWord? {
        guard !list.isEmpty else { return nil }
        let safeIndex = (index % list.count + list.count) % list.count
        return list[safeIndex]
    }

    // compute index for any date using base state
    private func indexFor(date: Date = .now, baseIndex: Int, baseDate: Date, rotationInterval: TimeInterval, totalCount: Int) -> Int {
        guard rotationInterval > 0, totalCount > 0 else { return baseIndex % max(1, totalCount) }
        let elapsed = date.timeIntervalSince(baseDate)
        let steps = Int(floor(elapsed / rotationInterval))
        return (baseIndex + steps) % totalCount
    }

    // small sample word used for placeholder previews
    private func sampleWord() -> VocabularyWord {
        VocabularyWord(
            id: "sample",
            word: "sample",
            partOfSpeech: "n.",
            pronunciation: "ˈsampəl",
            languageCode: "en",
            alternateScript: nil,
            translation: "ejemplo",
            translationLanguageCode: "es",
            definitions: [VocabularyWord.Definition(text: "A small example.", number: 1)],
            exampleSentences: [VocabularyWord.ExampleSentence(original: "This is a sample.", romanization: nil, translation: "Esta es una muestra.")],
            difficulty: .easy
        )
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let word: String
}

// Keep the existing VocabularyEntry TimelineEntry (used by views)
struct VocabularyEntry: TimelineEntry {
    let date: Date
    let word: VocabularyWord?
    let isLearningNew: Bool
}

struct VocabularyWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if let word = entry.word {
            switch family {
            case .systemSmall:
                SmallWidgetView(word: word, isLearningNew: entry.isLearningNew)
            case .systemMedium:
                MediumWidgetView(word: word, isLearningNew: entry.isLearningNew)
            case .systemLarge:
                LargeWidgetView(word: word, isLearningNew: entry.isLearningNew)
            case .accessoryCircular:
                AccessoryCircularView(word: word)
            case .accessoryRectangular:
                AccessoryRectangularView(word: word, isLearningNew: entry.isLearningNew)
            case .accessoryInline:
                AccessoryInlineView(word: word)
            default:
                MediumWidgetView(word: word, isLearningNew: entry.isLearningNew)
            }
        } else {
            Text("No word available")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct VocabularyWidget: Widget {
    let kind: String = "VocabularyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            VocabularyWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Vocabulary Word")
        .description("Display your current vocabulary word.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}

#Preview(as: .systemSmall) {
    VocabularyWidget()
} timeline: {
    VocabularyEntry(date: .now, word: VocabularyWord(
        id: "preview",
        word: "preview",
        partOfSpeech: "n.",
        pronunciation: nil,
        languageCode: "en",
        alternateScript: nil,
        translation: "vista previa",
        translationLanguageCode: "es",
        definitions: [VocabularyWord.Definition(text: "A preview item.", number: 1)],
        exampleSentences: nil,
        difficulty: .easy
    ), isLearningNew: true)
}
