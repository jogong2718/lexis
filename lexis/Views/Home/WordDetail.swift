import SwiftUI

struct WordDetailView: View {
    let entry: VocabularyWord
    @Environment(\.dismiss) private var dismiss

    @AppStorage(PrefKey.isLearningNewLanguage, store: PreferencesStore.defaults)
    private var isLearningNewLanguage: Bool = true

    var body: some View {
        ZStack {
            // Base dark gray background
            Color(white: 0.2)
                .ignoresSafeArea()

            // Radial gradient vignette overlay
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.3),
                    Color.black.opacity(0.8),
                ]),
                center: .center,
                startRadius: 100,
                endRadius: 500
            )
            .ignoresSafeArea()
            .blendMode(.multiply)

            VStack(spacing: 16) {
                if isLearningNewLanguage {
                    learningNewLanguageContent
                } else {
                    nativeLanguageContent
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
    }

    private var learningNewLanguageContent: some View {
        VStack(spacing: 16) {
            // Word with alternate script and part of speech
            VStack(spacing: 4) {
                if let alternateScript = entry.alternateScript {
                    Text("\(entry.word) (\(alternateScript))")
                        .font(Font.custom("InriaSerif-Bold", size: 52))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                } else {
                    Text(entry.word)
                        .font(Font.custom("InriaSerif-Bold", size: 52))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }

                Text(entry.partOfSpeech)
                    .font(Font.custom("InriaSerif-Regular", size: 11))
                    .foregroundColor(.white.opacity(0.5))
            }

            // Pronunciation
            if let pronunciation = entry.pronunciation {
                Text(pronunciation)
                    .font(Font.custom("InriaSerif-Regular", size: 18))
                    .foregroundColor(.white.opacity(0.7))
            }

            // Translation section
            if let translation = entry.translation {
                VStack(spacing: 12) {
                    Text("Translation")
                        .font(Font.custom("InriaSerif-Bold", size: 16))
                        .foregroundColor(.white.opacity(0.9))

                    Text(translation)
                        .font(Font.custom("InriaSerif-Bold", size: 22))
                        .foregroundColor(.white)

                    if let definitions = entry.definitions, let firstDef = definitions.first {
                        Text(firstDef.text)
                            .font(Font.custom("InriaSerif-Regular", size: 15))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
                .padding(.top, 16)
            }

            // In a sentence section
            if let examples = entry.exampleSentences, !examples.isEmpty {
                VStack(spacing: 10) {
                    Text("In a sentence")
                        .font(Font.custom("InriaSerif-Bold", size: 16))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.top, 20)

                    ForEach(examples.indices, id: \.self) { index in
                        let example = examples[index]
                        VStack(spacing: 6) {
                            Text(example.original)
                                .font(Font.custom("InriaSerif-Regular", size: 16))
                                .foregroundColor(.white.opacity(0.9))

                            if let romanization = example.romanization {
                                Text(romanization)
                                    .font(Font.custom("InriaSerif-Regular", size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            if let translation = example.translation {
                                Text(translation)
                                    .font(Font.custom("InriaSerif-Regular", size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding(.bottom, index < examples.count - 1 ? 12 : 0)
                    }
                }
            }
        }
    }

    private var nativeLanguageContent: some View {
        VStack(spacing: 16) {
            // Word with part of speech
            VStack(spacing: 4) {
                Text(entry.word)
                    .font(Font.custom("InriaSerif-Bold", size: 52))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(entry.partOfSpeech)
                    .font(Font.custom("InriaSerif-Regular", size: 11))
                    .foregroundColor(.white.opacity(0.5))
            }

            // Pronunciation
            if let pronunciation = entry.pronunciation {
                Text(pronunciation)
                    .font(Font.custom("InriaSerif-Regular", size: 18))
                    .foregroundColor(.white.opacity(0.7))
            }

            // Definition section
            if let definitions = entry.definitions, !definitions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(definitions.indices, id: \.self) { index in
                        let def = definitions[index]
                        let number = def.number ?? (index + 1)
                        Text("\(number). \(def.text)")
                            .font(Font.custom("InriaSerif-Regular", size: 15))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 40)
                .padding(.top, 16)
            }

            // Origin section
            if let origin = entry.origin {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Origin")
                        .font(Font.custom("InriaSerif-Bold", size: 16))
                        .foregroundColor(.white.opacity(0.9))

                    Text(origin)
                        .font(Font.custom("InriaSerif-Regular", size: 13))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 40)
                .padding(.top, 20)
            }

            // Synonyms section
            if let synonyms = entry.synonyms, !synonyms.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Synonyms")
                        .font(Font.custom("InriaSerif-Bold", size: 16))
                        .foregroundColor(.white.opacity(0.9))

                    Text(synonyms.joined(separator: ", "))
                        .font(Font.custom("InriaSerif-Regular", size: 13))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 40)
                .padding(.top, 16)
            }
        }
    }
}
