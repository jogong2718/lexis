import SwiftUI

struct NativeLanguageView: View {
    @AppStorage(PrefKey.nativeLanguageCode, store: PreferencesStore.defaults)
    private var nativeLanguageCode: String = ""

    @State private var searchText = ""
    @State private var isDropdownExpanded = false

    let languages = [
        "English", "Spanish", "French", "German", "Italian",
        "Portuguese", "Russian", "Chinese", "Japanese", "Korean",
        "Arabic", "Hindi", "Dutch", "Swedish", "Norwegian",
    ].sorted()

    var filteredTop4: [String] {
        let base =
            searchText.isEmpty
            ? languages
            : languages.filter { $0.localizedCaseInsensitiveContains(searchText) }
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
                                if !isDropdownExpanded {
                                    isDropdownExpanded = true
                                }
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
                                let language = filteredTop4[i]
                                Button {
                                    searchText = language
                                    nativeLanguageCode = language
                                    isDropdownExpanded = false
                                } label: {
                                    Text(language)
                                        .font(Font.custom("InriaSerif-Regular", size: 16))
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity, alignment: .leading)
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
                    nativeLanguageCode = searchText.isEmpty ? "" : searchText
                    dismiss()
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
            if !nativeLanguageCode.isEmpty {
                searchText = nativeLanguageCode
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
    }
}

// Helper extension for corner radius on specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    NavigationStack {
        NativeLanguageView()
    }
}
