import SwiftUI

struct NativeLanguageView: View {
    @AppStorage(PrefKey.nativeLanguageCode, store: PreferencesStore.defaults)
    private var nativeLanguageCode: String = ""
    @AppStorage(PrefKey.isLearningNewLanguage, store: PreferencesStore.defaults)
    private var isLearningNewLanguage: Bool = true

    @State private var showLearnLanguage = false
    @State private var showDifficulty = false

    @State private var searchText = ""
    @State private var isDropdownExpanded = false

    // use centralized language data
    let languages = Languages.all.filter { Languages.supportedNativeLanguages.contains($0.code) }

    // Filter by english OR native name, return top 4 Language entries
    var filteredTop4: [Language] {
        let base =
            searchText.isEmpty
            ? languages
            : languages.filter {
                $0.english.localizedCaseInsensitiveContains(searchText)
                    || $0.native.localizedCaseInsensitiveContains(searchText)
            }
        return Array(base.prefix(4))
    }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // Use the parent's NavigationStack (don't create a new one)
        ZStack {
            // Background with tap to dismiss dropdown
            Color(red: 0.15, green: 0.15, blue: 0.15)
                .ignoresSafeArea()
                .onTapGesture {
                    if isDropdownExpanded {
                        isDropdownExpanded = false
                    }
                }

            VStack(spacing: 40) {
                Spacer()

                Text("What is your native\nlanguage?")
                    .font(Font.custom("InriaSerif-Bold", size: 32))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                VStack(spacing: 0) {
                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray)

                        TextField("Input", text: $searchText)
                            .font(Font.custom("InriaSerif-Regular", size: 16))
                            .foregroundColor(.white)
                            .textInputAutocapitalization(.never)
                            .onChange(of: searchText) {
                                if !isDropdownExpanded { isDropdownExpanded = true }
                            }

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                    .background(Color(red: 0.2, green: 0.2, blue: 0.2))
                    .cornerRadius(
                        8, corners: isDropdownExpanded ? [.topLeft, .topRight] : .allCorners
                    )
                    .onTapGesture {
                        isDropdownExpanded = true
                    }

                    // Dropdown
                    if isDropdownExpanded {
                        VStack(spacing: 0) {
                            ForEach(filteredTop4.indices, id: \.self) { i in
                                let lang = filteredTop4[i]
                                Button {
                                    // store the language code, show english name in field
                                    searchText = lang.english
                                    nativeLanguageCode = lang.code
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
                                if i < filteredTop4.count - 1 {
                                    Divider().background(Color(red: 0.6, green: 0.6, blue: 0.6))
                                }
                            }
                        }
                        .cornerRadius(8, corners: [.bottomLeft, .bottomRight])
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                Button {
                    // Save chosen native language (store code when possible).
                    if let match = Languages.match(forText: searchText) {
                        nativeLanguageCode = match.code
                    } else {
                        nativeLanguageCode = searchText.isEmpty ? "" : searchText
                    }
                    if isLearningNewLanguage {
                        // navigate to LearnLanguageView (pushes on ancestor NavigationStack)
                        showLearnLanguage = true
                    } else {
                        // TODO: implement flow when user is NOT learning a new language (e.g. finish onboarding)
                        showDifficulty = true
                    }
                } label: {
                    Text("Continue")
                        .font(Font.custom("InriaSerif-Bold", size: 16))
                        .foregroundColor(.white)
                        .frame(width: 120)
                        .padding()
                        .background(Color(red: 0.2, green: 0.2, blue: 0.2))
                        .cornerRadius(8)
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            // If stored value is a recognized code, show the English name; otherwise show stored text.
            if !nativeLanguageCode.isEmpty {
                if let lang = Languages.language(forCode: nativeLanguageCode) {
                    searchText = lang.english
                } else {
                    searchText = nativeLanguageCode
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left").font(
                            .system(size: 16, weight: .semibold))
                        Text("Back").font(Font.custom("InriaSerif-Regular", size: 16))
                    }
                    .foregroundColor(.white)
                }
            }
        }
        // Push LearnLanguageView on the ancestor NavigationStack (OnboardingView)
        .navigationDestination(isPresented: $showLearnLanguage) {
            LearnLanguageView()
        }
        .navigationDestination(isPresented: $showDifficulty) {
            DifficultyView()
        }
    }
}

#Preview {
    NativeLanguageView()
}
