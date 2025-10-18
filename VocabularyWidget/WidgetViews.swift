import SwiftUI
import WidgetKit

// MARK: - Home Screen Widgets

struct SmallWidgetView: View {
    let word: VocabularyWord
    let isLearningNew: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(word.word)
                .font(.headline)
                .fontWeight(.bold)
                .lineLimit(1)

            if let pronunciation = word.pronunciation {
                Text(pronunciation)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(word.partOfSpeech)
                .font(.caption2)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.7))
                .cornerRadius(4)
        }
        .padding()
    }
}

struct MediumWidgetView: View {
    let word: VocabularyWord
    let isLearningNew: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(word.word)
                        .font(.title2)
                        .fontWeight(.bold)
                        .lineLimit(1)

                    if let alternateScript = word.alternateScript {
                        Text(alternateScript)
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(word.partOfSpeech)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.7))
                    .cornerRadius(6)
            }

            if let pronunciation = word.pronunciation {
                Text(pronunciation)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isLearningNew {
                if let translation = word.translation {
                    Text(translation)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }
            } else {
                if let definition = word.definitions?.first?.text {
                    Text(definition)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }
            }
        }
        .padding()
    }
}

struct LargeWidgetView: View {
    let word: VocabularyWord
    let isLearningNew: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(word.word)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .lineLimit(1)

                    if let alternateScript = word.alternateScript {
                        Text(alternateScript)
                            .font(.title2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(word.partOfSpeech)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue.opacity(0.7))
                        .cornerRadius(8)

                    if let difficulty = word.difficulty {
                        Text(difficulty.rawValue)
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(difficultyColor(difficulty))
                            .cornerRadius(6)
                    }
                }
            }

            if let pronunciation = word.pronunciation {
                Text(pronunciation)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Divider()

            if isLearningNew {
                if let translation = word.translation {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Translation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(translation)
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                }

                if let example = word.exampleSentences?.first {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Example")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(example.original)
                            .font(.footnote)
                            .lineLimit(2)
                        if let romanization = example.romanization {
                            Text(romanization)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Text(example.translation)
                            .font(.caption)
                            .italic()
                            .lineLimit(2)
                    }
                }
            } else {
                if let definitions = word.definitions {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(definitions.prefix(3), id: \.number) { def in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(def.number).")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(def.text)
                                    .font(.footnote)
                                    .lineLimit(3)
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
    }

    private func difficultyColor(_ difficulty: VocabularyWord.Difficulty) -> Color {
        switch difficulty {
        case .easy: return .green.opacity(0.7)
        case .medium: return .orange.opacity(0.7)
        case .hard: return .red.opacity(0.7)
        }
    }
}

// MARK: - Lock Screen Widgets

struct AccessoryCircularView: View {
    let word: VocabularyWord

    var body: some View {
        VStack(spacing: 2) {
            Text(word.word)
                .font(.caption2)
                .fontWeight(.bold)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(word.partOfSpeech)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct AccessoryRectangularView: View {
    let word: VocabularyWord
    let isLearningNew: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(word.word)
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text(word.partOfSpeech)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if isLearningNew {
                if let translation = word.translation {
                    Text(translation)
                        .font(.caption)
                        .lineLimit(2)
                }
            } else {
                if let definition = word.definitions?.first?.text {
                    Text(definition)
                        .font(.caption2)
                        .lineLimit(2)
                }
            }
        }
    }
}

struct AccessoryInlineView: View {
    let word: VocabularyWord

    var body: some View {
        Text("\(word.word) • \(word.partOfSpeech)")
    }
}
