//
//  VocabularyWidget.swift
//  VocabularyWidget
//
//  Created by Jonathan Gong on 2025-10-17.
//

import SwiftUI
import WidgetKit

struct Provider: TimelineProvider {
    private let appGroupIdentifier = "group.com.jogong2718.lexis"

    func placeholder(in context: Context) -> VocabularyEntry {
        VocabularyEntry(date: Date(), word: nil, isLearningNew: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (VocabularyEntry) -> Void) {
        let entry = VocabularyEntry(
            date: Date(), word: loadCurrentWord(), isLearningNew: loadIsLearningNew())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let currentDate = Date()
        let word = loadCurrentWord()
        let isLearningNew = loadIsLearningNew()

        let entry = VocabularyEntry(date: currentDate, word: word, isLearningNew: isLearningNew)

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))

        completion(timeline)
    }

    private func loadCurrentWord() -> VocabularyWord? {
        guard
            let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupIdentifier
            )
        else { return nil }

        let historyURL = containerURL.appendingPathComponent("history.json")
        let vocabularyURL = containerURL.appendingPathComponent("vocabulary.json")

        guard let historyData = try? Data(contentsOf: historyURL),
            let history = try? JSONDecoder().decode(VocabularyHistory.self, from: historyData),
            let lastWordId = history.entries.last,
            let vocabData = try? Data(contentsOf: vocabularyURL),
            let allWords = try? JSONDecoder().decode([VocabularyWord].self, from: vocabData),
            let word = allWords.first(where: { $0.id == lastWordId })
        else { return nil }

        return word
    }

    private func loadIsLearningNew() -> Bool {
        UserDefaults(suiteName: appGroupIdentifier)?.bool(forKey: "isLearningNewLanguage") ?? true
    }
}

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
    VocabularyEntry(date: .now, word: nil, isLearningNew: true)
}
