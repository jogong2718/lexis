import SwiftUI

struct LearnLanguageView: View {
    @AppStorage(PrefKey.targetLanguageCode, store: PreferencesStore.defaults)
    private var targetLanguageCode: String = ""

    @State private var searchText = ""
    @State private var isDropdownExpanded = false
    @State private var showDifficulty = false

    // use centralized language data
    let languages = Languages.all.filter { Languages.supportedTargetLanguages.contains($0.code) }

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

                Text("What language\ndo you want to learn?")
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
                                    targetLanguageCode = lang.code
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
                    // If searchText matches a known language (english or native), store its code.
                    if let match = Languages.match(forText: searchText) {
                        targetLanguageCode = match.code
                    } else {
                        // fallback: store the raw input (keeps previous behavior if user typed a custom value)
                        targetLanguageCode = searchText.isEmpty ? "" : searchText
                    }
                    showDifficulty = true
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
            if !targetLanguageCode.isEmpty {
                if let lang = Languages.language(forCode: targetLanguageCode) {
                    searchText = lang.english
                } else {
                    searchText = targetLanguageCode
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
                        Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                        Text("Back").font(Font.custom("InriaSerif-Regular", size: 16))
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .navigationDestination(isPresented: $showDifficulty) {
            DifficultyView()
        }
    }
}

#Preview {
    LearnLanguageView()
}
