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
        VocabularyEntry(date: Date(), word: sampleWord(), isLearningNew: true, timeUntilWindowStart: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (VocabularyEntry) -> Void) {
        let entry = makeEntry(for: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VocabularyEntry>) -> Void) {
        print("WIDGET: Generating timeline for VocabularyWidget")
        let now = Date()
        
        // Read time-window settings from shared defaults
        let startHour = sharedDefaults?.integer(forKey: "lexis.startHour") ?? 8
        let endHour = sharedDefaults?.integer(forKey: "lexis.endHour") ?? 10
        let startIsPM = sharedDefaults?.bool(forKey: "lexis.startIsPM") ?? false
        let endIsPM = sharedDefaults?.bool(forKey: "lexis.endIsPM") ?? true
        
        let start24 = convertTo24Hour(hour: startHour, isPM: startIsPM)
        let end24 = convertTo24Hour(hour: endHour, isPM: endIsPM)
        
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        
        let isInTimeWindow: Bool
        if start24 <= end24 {
            isInTimeWindow = currentHour >= start24 && currentHour < end24
        } else {
            isInTimeWindow = currentHour >= start24 || currentHour < end24
        }
        
        // If outside the active window, create an entry showing time until window starts
        if !isInTimeWindow {
            let nextWindowStart = calculateNextWindowStart(now: now, start24: start24, calendar: calendar)
            let timeUntilStart = nextWindowStart.timeIntervalSince(now)
            let isLearning = sharedDefaults?.bool(forKey: "lexis.isLearningNew") ?? true
            let entry = VocabularyEntry(date: now, word: nil, isLearningNew: isLearning, timeUntilWindowStart: timeUntilStart)
            
            // Refresh every minute to update the countdown
            let nextRefresh = now.addingTimeInterval(60)
            let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
            completion(timeline)
            return
        }
        
        // Inside active window — proceed with normal word rotation logic
        let baseIndex = sharedDefaults?.integer(forKey: "lexis.currentIndex") ?? 0
        let baseDate = sharedDefaults?.object(forKey: "lexis.lastRotationDate") as? Date ?? now
        let rotationInterval = sharedDefaults?.double(forKey: "lexis.rotationInterval") ?? 3600

        print("WIDGET: shared lexes.currentIndex = \(baseIndex)")
        print("WIDGET: shared lexis.lastRotationDate = \(String(describing: sharedDefaults?.object(forKey: "lexis.lastRotationDate"))) (interpreted: \(baseDate))")
        print("WIDGET: shared lexis.rotationInterval = \(rotationInterval)")

        let wordList = loadWordList() ?? []

        guard !wordList.isEmpty else {
            let entry = VocabularyEntry(date: now, word: nil, isLearningNew: sharedDefaults?.bool(forKey: "lexis.isLearningNew") ?? true, timeUntilWindowStart: nil)
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
        let currentEntry = VocabularyEntry(date: now, word: currentWord, isLearningNew: isLearning, timeUntilWindowStart: nil)
        
        // Next word entry (for preloading)
        let nextIndex = (currentIndex + 1) % wordList.count
        let nextWord = loadWordForIndex(nextIndex, from: wordList)
        let nextEntry = VocabularyEntry(date: nextRotationDate, word: nextWord, isLearningNew: isLearning, timeUntilWindowStart: nil)
        
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
        return VocabularyEntry(date: date, word: word, isLearningNew: isLearning, timeUntilWindowStart: nil)
    }

    // Load decoded VocabularyWord list from App Group. Supports two formats:
    // 1) JSON-encoded [VocabularyWord] under "lexis.wordListJSON"
    // 2) Simple string array under "lexis.wordList" (backwards compatibility)
    private func loadWordList() -> [VocabularyWord]? {
        // Try JSON first
        if let data = sharedDefaults?.data(forKey: "lexis.wordListJSON") {
            print("WIDGET: found lexis.wordListJSON bytes: \(data.count)")
            // print truncated preview of JSON (safe)
            if let preview = String(data: data.prefix(2048), encoding: .utf8) {
                let previewTrimmed = preview.trimmingCharacters(in: .whitespacesAndNewlines)
                print("WIDGET: wordListJSON preview: \(previewTrimmed.prefix(500))")
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            do {
                let decoded = try decoder.decode([VocabularyWord].self, from: data)
                print("WIDGET: decoded wordListJSON -> \(decoded.count) entries")
                return decoded
            } catch let DecodingError.typeMismatch(type, ctx) {
                print("WIDGET: typeMismatch \(type) at \(ctx.codingPath): \(ctx.debugDescription)")
            } catch let DecodingError.valueNotFound(type, ctx) {
                print("WIDGET: valueNotFound \(type) at \(ctx.codingPath): \(ctx.debugDescription)")
            } catch let DecodingError.keyNotFound(key, ctx) {
                print("WIDGET: keyNotFound \(key) at \(ctx.codingPath): \(ctx.debugDescription)")
            } catch let DecodingError.dataCorrupted(ctx) {
                print("WIDGET: dataCorrupted at \(ctx.codingPath): \(ctx.debugDescription)")
            } catch {
                print("WIDGET: decode error: \(error)")
            }
        } else {
            print("WIDGET: no lexis.wordListJSON found in shared defaults")
        }

        // Fallback to simple string array
        if let strings = sharedDefaults?.stringArray(forKey: "lexis.wordList"), !strings.isEmpty {
            print("WIDGET: found lexis.wordList string array -> \(strings.count) words")
            return strings.enumerated().map { idx, wordStr in
                VocabularyWord(
                    id: "w\(idx)",
                    word: wordStr,
                    partOfSpeech: "",
                    pronunciation: nil,
                    languageCode: "",
                    definitions: nil,
                    origin: nil,
                    synonyms: nil,
                    alternateScript: nil,
                    translation: nil,
                    translationLanguageCode: nil,
                    exampleSentences: nil,
                    difficulty: .medium
                )
            }
        } else {
            print("WIDGET: no lexis.wordList string array in shared defaults")
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
            definitions: [VocabularyWord.Definition(text: "A small example.", number: 1)],
            origin: nil,
            synonyms: nil,
            alternateScript: nil,
            translation: "ejemplo",
            translationLanguageCode: "es",
            exampleSentences: [VocabularyWord.ExampleSentence(original: "This is a sample.", romanization: nil, translation: "Esta es una muestra.")],
            difficulty: .easy
        )
    }
    
    // Convert 12-hour to 24-hour format
    private func convertTo24Hour(hour: Int, isPM: Bool) -> Int {
        if hour == 12 {
            return isPM ? 12 : 0
        }
        return isPM ? hour + 12 : hour
    }
    
    // Calculate when the next active window starts
    private func calculateNextWindowStart(now: Date, start24: Int, calendar: Calendar) -> Date {
        let currentHour = calendar.component(.hour, from: now)
        
        if currentHour < start24 {
            // Window starts later today
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = start24
            components.minute = 0
            components.second = 0
            return calendar.date(from: components) ?? now
        } else {
            // Window starts tomorrow
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
            components.hour = start24
            components.minute = 0
            components.second = 0
            return calendar.date(from: components) ?? now
        }
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
    let timeUntilWindowStart: TimeInterval? // nil when inside active window
}

struct VocabularyWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        // If timeUntilWindowStart is set, show "outside hours" message
        if let timeUntil = entry.timeUntilWindowStart {
            OutsideWindowView(timeUntilStart: timeUntil, family: family)
        } else if let word = entry.word {
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

// View shown when outside the active time window
struct OutsideWindowView: View {
    let timeUntilStart: TimeInterval
    let family: WidgetFamily
    
    var body: some View {
        // Lock screen accessory widgets need very compact layouts
        if family == .accessoryCircular {
            VStack(spacing: 2) {
                Image(systemName: "clock")
                    .font(.system(size: 16))
                Text(formatTimeInterval(timeUntilStart))
                    .font(.system(size: 10, weight: .semibold))
            }
        } else if family == .accessoryRectangular {
            VStack(alignment: .leading, spacing: 2) {
                Text("Outside hours")
                    .font(.system(size: 11, weight: .semibold))
                Text("Next: \(formatTimeInterval(timeUntilStart))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        } else if family == .accessoryInline {
            Text("Outside hours • \(formatTimeInterval(timeUntilStart))")
                .font(.system(size: 10))
        } else {
            // Home screen widgets (systemSmall, systemMedium, systemLarge)
            VStack(spacing: family == .systemSmall ? 4 : 8) {
                if family != .systemSmall {
                    Image(systemName: "clock")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                }
                
                Text("Outside active hours")
                    .font(family == .systemSmall ? .system(size: 10) : .headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text("Next word in")
                    .font(family == .systemSmall ? .system(size: 8) : .caption2)
                    .foregroundColor(.secondary)
                
                Text(formatTimeInterval(timeUntilStart))
                    .font(family == .systemSmall ? .system(size: 11, weight: .semibold) : .subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            .padding(family == .systemSmall ? 4 : 8)
        }
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm", minutes)
        } else {
            return "Soon"
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
