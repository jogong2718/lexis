import SwiftUI

struct HomeView: View {
    @AppStorage(PrefKey.isLearningNewLanguage, store: PreferencesStore.defaults)
    private var isLearningNewLanguage: Bool = true

    @AppStorage(PrefKey.nativeLanguageCode, store: PreferencesStore.defaults)
    private var nativeLanguageCode: String = ""

    @AppStorage(PrefKey.targetLanguageCode, store: PreferencesStore.defaults)
    private var targetLanguageCode: String = ""

    // navigation to settings
    @State private var showSettings = false

    @StateObject private var vocabularyStore = VocabularyStore.shared
    @State private var selectedHistoryEntry: VocabularyEntry?
    @State private var showWordDetail = false
    @State private var timeUntilNextWord: String = ""
    @State private var timer: Timer?

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

            VStack(spacing: 0) {
                Spacer()

                if isLearningNewLanguage {
                    // Learning another language view
                    if let entry = vocabularyStore.currentWord {
                        learningNewLanguageCard(entry: entry)
                    } else {
                        Text("Loading...")
                            .foregroundColor(.white)
                    }
                } else {
                    // Learning native language view
                    if let entry = vocabularyStore.currentWord {
                        nativeLanguageCard(entry: entry)
                    } else {
                        Text("Loading...")
                            .foregroundColor(.white)
                    }
                }

                // Next word timer
                nextWordTimer

                Spacer()

                // History section
                historySection
            }
        }
        .onAppear {
            vocabularyStore.checkAndRotateIfNeeded()
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            // settings button top-left
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .navigationDestination(isPresented: $showSettings) {
            SettingsView()
        }
        .navigationDestination(isPresented: $showWordDetail) {
            if let entry = selectedHistoryEntry {
                WordDetailView(entry: entry)
            }
        }
    }

    // Learning new language card
    private func learningNewLanguageCard(entry: VocabularyEntry) -> some View {
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

                    // Show first definition if available
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
            if let examples = entry.exampleSentences, let example = examples.first {
                VStack(spacing: 10) {
                    Text("In a sentence")
                        .font(Font.custom("InriaSerif-Bold", size: 16))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.top, 20)

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
            }
        }
        .padding(.horizontal, 32)
    }

    // Native language card
    private func nativeLanguageCard(entry: VocabularyEntry) -> some View {
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
        .padding(.horizontal, 32)
    }

    // Next word timer display
    private var nextWordTimer: some View {
        VStack(spacing: 4) {
            Text("Next word in")
                .font(Font.custom("InriaSerif-Regular", size: 12))
                .foregroundColor(.white.opacity(0.5))

            Text(timeUntilNextWord)
                .font(Font.custom("InriaSerif-Bold", size: 16))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.top, 20)
    }

    // Shared history section
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(Font.custom("InriaSerif-Bold", size: 22))
                .foregroundColor(.white)
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(vocabularyStore.history.reversed()) { entry in
                        Button {
                            selectedHistoryEntry = entry
                            showWordDetail = true
                        } label: {
                            Text(entry.word)
                                .font(Font.custom("InriaSerif-Regular", size: 15))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                                .underline()
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.bottom, 50)
    }

    // Timer functions
    private func startTimer() {
        updateTimeUntilNextWord()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateTimeUntilNextWord()
        }
    }

    private func updateTimeUntilNextWord() {
        guard let timeRemaining = vocabularyStore.getTimeUntilNextRotation() else {
            timeUntilNextWord = "Configure settings"
            return
        }

        if timeRemaining <= 0 {
            timeUntilNextWord = "Soon"
            vocabularyStore.checkAndRotateIfNeeded()
        } else {
            timeUntilNextWord = formatTimeInterval(timeRemaining)
        }
    }

    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %02ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

// Use standard PreviewProvider — more robust across Xcode versions.
#Preview {
    NavigationStack {
        HomeView()
    }
}
