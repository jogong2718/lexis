import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    // Language preferences
    @AppStorage(PrefKey.isLearningNewLanguage, store: PreferencesStore.defaults)
    private var isLearningNewLanguage: Bool = true

    @AppStorage(PrefKey.nativeLanguageCode, store: PreferencesStore.defaults)
    private var nativeLanguageCode: String = ""

    @AppStorage(PrefKey.targetLanguageCode, store: PreferencesStore.defaults)
    private var targetLanguageCode: String = ""

    // Difficulty preferences
    @AppStorage(PrefKey.difficultyEasy, store: PreferencesStore.defaults)
    private var difficultyEasy: Bool = false

    @AppStorage(PrefKey.difficultyMedium, store: PreferencesStore.defaults)
    private var difficultyMedium: Bool = false

    @AppStorage(PrefKey.difficultyHard, store: PreferencesStore.defaults)
    private var difficultyHard: Bool = false

    // Frequency preferences (in hours)
    @AppStorage(PrefKey.frequencyMin, store: PreferencesStore.defaults)
    private var frequencyMin: Int = 2

    @AppStorage(PrefKey.frequencyMax, store: PreferencesStore.defaults)
    private var frequencyMax: Int = 4

    // Time preferences
    @AppStorage(PrefKey.startHour, store: PreferencesStore.defaults)
    private var startHour: Int = 8

    @AppStorage(PrefKey.startMinute, store: PreferencesStore.defaults)
    private var startMinute: Int = 0

    @AppStorage(PrefKey.startIsPM, store: PreferencesStore.defaults)
    private var startIsPM: Bool = false

    @AppStorage(PrefKey.endHour, store: PreferencesStore.defaults)
    private var endHour: Int = 8

    @AppStorage(PrefKey.endMinute, store: PreferencesStore.defaults)
    private var endMinute: Int = 0

    @AppStorage(PrefKey.endIsPM, store: PreferencesStore.defaults)
    private var endIsPM: Bool = true

    // Local state for dropdowns
    @State private var nativeSearchText = ""
    @State private var targetSearchText = ""
    @State private var isNativeDropdownExpanded = false
    @State private var isTargetDropdownExpanded = false

    let nativeLanguages = Languages.all.filter {
        Languages.supportedNativeLanguages.contains($0.code)
    }
    let targetLanguages = Languages.all.filter {
        Languages.supportedTargetLanguages.contains($0.code)
    }

    var filteredNativeTop4: [Language] {
        let base =
            nativeSearchText.isEmpty
            ? nativeLanguages
            : nativeLanguages.filter {
                $0.english.localizedCaseInsensitiveContains(nativeSearchText)
                    || $0.native.localizedCaseInsensitiveContains(nativeSearchText)
            }
        return Array(base.prefix(4))
    }

    var filteredTargetTop4: [Language] {
        let base =
            targetSearchText.isEmpty
            ? targetLanguages
            : targetLanguages.filter {
                $0.english.localizedCaseInsensitiveContains(targetSearchText)
                    || $0.native.localizedCaseInsensitiveContains(targetSearchText)
            }
        return Array(base.prefix(4))
    }

    var body: some View {
        ZStack {
            // Base dark gray background
            Color(white: 0.2)
                .ignoresSafeArea()
                .onTapGesture {
                    isNativeDropdownExpanded = false
                    isTargetDropdownExpanded = false
                }

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
            .onTapGesture {
                isNativeDropdownExpanded = false
                isTargetDropdownExpanded = false
            }

            ScrollView {
                VStack(spacing: 24) {
                    // Learn your own language toggle button
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isLearningNewLanguage.toggle()
                            // Force vocabulary rotation when mode changes
                            VocabularyStore.shared.forceRotation()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(
                                isLearningNewLanguage
                                    ? "Learn another language" : "Learn your own language"
                            )
                            .font(Font.custom("InriaSerif-Regular", size: 16))
                            .foregroundColor(isLearningNewLanguage ? .white : .black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(isLearningNewLanguage ? Color.white.opacity(0.15) : Color.white)
                        .cornerRadius(25)
                        .scaleEffect(isLearningNewLanguage ? 1.0 : 1.02)
                        .animation(
                            .spring(response: 0.3, dampingFraction: 0.6),
                            value: isLearningNewLanguage)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 32)
                    .padding(.top, 20)

                    // Language input fields
                    HStack(spacing: 16) {
                        LanguageDropdownField(
                            label: "Native Language",
                            placeholder: "Input",
                            searchText: $nativeSearchText,
                            languageCode: $nativeLanguageCode,
                            isDropdownExpanded: $isNativeDropdownExpanded,
                            filteredLanguages: filteredNativeTop4
                        )

                        LanguageDropdownField(
                            label: "Target Language",
                            placeholder: "Input",
                            searchText: $targetSearchText,
                            languageCode: $targetLanguageCode,
                            isDropdownExpanded: $isTargetDropdownExpanded,
                            filteredLanguages: filteredTargetTop4
                        )
                    }
                    .padding(.horizontal, 32)
                    .zIndex(1)

                    // Difficulty section
                    VStack(spacing: 16) {
                        Text("Difficulty")
                            .font(Font.custom("InriaSerif-Bold", size: 20))
                            .foregroundColor(.white)

                        HStack(spacing: 12) {
                            DifficultyButton(title: "Easy", isSelected: $difficultyEasy)
                            DifficultyButton(title: "Medium", isSelected: $difficultyMedium)
                            DifficultyButton(title: "Hard", isSelected: $difficultyHard)
                        }
                        .padding(.horizontal, 32)
                    }

                    // Frequency section
                    VStack(spacing: 16) {
                        Text("Frequency")
                            .font(Font.custom("InriaSerif-Bold", size: 20))
                            .foregroundColor(.white)

                        HStack(spacing: 12) {
                            FrequencyButton(
                                title: "2-4", min: 2, max: 4, selectedMin: $frequencyMin,
                                selectedMax: $frequencyMax)
                            FrequencyButton(
                                title: "5-8", min: 5, max: 8, selectedMin: $frequencyMin,
                                selectedMax: $frequencyMax)
                            FrequencyButton(
                                title: "9-12", min: 9, max: 12, selectedMin: $frequencyMin,
                                selectedMax: $frequencyMax)
                        }
                        .padding(.horizontal, 32)
                    }

                    // Start Time section
                    TimesStyleTimePickerSection(
                        title: "Start Time (what time of day to start learning?)",
                        hour: $startHour,
                        minute: $startMinute,
                        isPM: $startIsPM
                    )
                    .padding(.horizontal, 32)

                    // End Time section
                    TimesStyleTimePickerSection(
                        title: "End Time (what time of day to stop learning?)",
                        hour: $endHour,
                        minute: $endMinute,
                        isPM: $endIsPM
                    )
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
            }
            .coordinateSpace(name: "scroll")
        }
        .onAppear {
            // Load stored language values
            if !nativeLanguageCode.isEmpty {
                if let lang = Languages.language(forCode: nativeLanguageCode) {
                    nativeSearchText = lang.english
                } else {
                    nativeSearchText = nativeLanguageCode
                }
            }
            if !targetLanguageCode.isEmpty {
                if let lang = Languages.language(forCode: targetLanguageCode) {
                    targetSearchText = lang.english
                } else {
                    targetSearchText = targetLanguageCode
                }
            }
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
}

// Language Dropdown Field Component
struct LanguageDropdownField: View {
    let label: String
    let placeholder: String
    @Binding var searchText: String
    @Binding var languageCode: String
    @Binding var isDropdownExpanded: Bool
    let filteredLanguages: [Language]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(Font.custom("InriaSerif-Regular", size: 13))
                .foregroundColor(.white.opacity(0.7))

            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.system(size: 14))

                    TextField(placeholder, text: $searchText)
                        .font(Font.custom("InriaSerif-Regular", size: 16))
                        .foregroundColor(.white)
                        .accentColor(.white)
                        .textInputAutocapitalization(.never)
                        .onChange(of: searchText) {
                            if !isDropdownExpanded { isDropdownExpanded = true }
                        }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.15))
                .cornerRadius(8, corners: isDropdownExpanded ? [.topLeft, .topRight] : .allCorners)
                .onTapGesture {
                    isDropdownExpanded = true
                }

                // Dropdown
                if isDropdownExpanded {
                    VStack(spacing: 0) {
                        ForEach(filteredLanguages.indices, id: \.self) { i in
                            let lang = filteredLanguages[i]
                            Button {
                                searchText = lang.english
                                languageCode = lang.code
                                isDropdownExpanded = false
                            } label: {
                                HStack {
                                    Text(lang.english)
                                        .font(Font.custom("InriaSerif-Regular", size: 16))
                                        .foregroundColor(.black)
                                    Spacer()
                                    Text(lang.native)
                                        .font(Font.custom("InriaSerif-Regular", size: 14))
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(red: 0.7, green: 0.7, blue: 0.7))
                            }
                            if i < filteredLanguages.count - 1 {
                                Divider().background(Color(red: 0.6, green: 0.6, blue: 0.6))
                            }
                        }
                    }
                    .cornerRadius(8, corners: [.bottomLeft, .bottomRight])
                }
            }
        }
    }
}

// Difficulty Button Component
struct DifficultyButton: View {
    let title: String
    @Binding var isSelected: Bool

    var body: some View {
        Button {
            isSelected.toggle()
        } label: {
            Text(title)
                .font(Font.custom("InriaSerif-Regular", size: 16))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.white : Color.white.opacity(0.15))
                .cornerRadius(8)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

// Frequency Button Component
struct FrequencyButton: View {
    let title: String
    let min: Int
    let max: Int
    @Binding var selectedMin: Int
    @Binding var selectedMax: Int

    var isSelected: Bool {
        selectedMin == min && selectedMax == max
    }

    var body: some View {
        Button {
            selectedMin = min
            selectedMax = max
        } label: {
            Text(title)
                .font(Font.custom("InriaSerif-Regular", size: 16))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.white : Color.white.opacity(0.15))
                .cornerRadius(8)
        }
    }
}

// Times-style Time Picker Section Component
struct TimesStyleTimePickerSection: View {
    let title: String
    @Binding var hour: Int
    @Binding var minute: Int
    @Binding var isPM: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(Font.custom("InriaSerif-Bold", size: 13))
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                // Hour picker
                VStack(spacing: 4) {
                    Picker("", selection: $hour) {
                        ForEach(1...12, id: \.self) { h in
                            Text("\(h)")
                                .font(Font.custom("InriaSerif-Bold", size: 32))
                                .tag(h)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80, height: 100)
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text("Hour")
                        .font(Font.custom("InriaSerif-Regular", size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }

                Text(":")
                    .font(Font.custom("InriaSerif-Bold", size: 32))
                    .foregroundColor(.white)
                    .padding(.bottom, 20)

                // Minute picker
                VStack(spacing: 4) {
                    Picker("", selection: $minute) {
                        ForEach(0..<60, id: \.self) { m in
                            Text(String(format: "%02d", m))
                                .font(Font.custom("InriaSerif-Bold", size: 32))
                                .tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80, height: 100)
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text("Minute")
                        .font(Font.custom("InriaSerif-Regular", size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }

                // AM/PM toggle
                VStack(spacing: 8) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isPM = false
                        }
                    } label: {
                        Text("AM")
                            .font(Font.custom("InriaSerif-Bold", size: 14))
                            .foregroundColor(isPM ? .white.opacity(0.6) : .black)
                            .frame(width: 50, height: 35)
                            .background(isPM ? Color.white.opacity(0.15) : Color.white)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isPM = true
                        }
                    } label: {
                        Text("PM")
                            .font(Font.custom("InriaSerif-Bold", size: 14))
                            .foregroundColor(isPM ? .black : .white.opacity(0.6))
                            .frame(width: 50, height: 35)
                            .background(isPM ? Color.white : Color.white.opacity(0.15))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 20)
                .padding(.horizontal, 20)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
