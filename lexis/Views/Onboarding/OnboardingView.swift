import SwiftUI

// Add a pressable button style for tap animations
struct PressableButtonStyle: ButtonStyle {
    var scaleAmount: CGFloat = 0.96
    var pressedOpacity: Double = 0.95

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .opacity(configuration.isPressed ? pressedOpacity : 1.0)
            .animation(
                .spring(response: 0.28, dampingFraction: 0.7, blendDuration: 0),
                value: configuration.isPressed)
    }
}

struct OnboardingView: View {

    @AppStorage(PrefKey.isLearningNewLanguage, store: PreferencesStore.defaults)
    private var isLearningNewLanguage = true

    // navigation state to present NativeLanguageView
    @State private var showNativeLanguage = false

    var body: some View {
        // Use the root NavigationStack from the App (avoid nested NavigationStacks)
        ZStack {
            Color(red: 0.15, green: 0.15, blue: 0.15)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                // Lexis Logo
                Image("logo")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .padding(.top, 20)

                VStack(spacing: 16) {
                    Text("Welcome to Lexis!")
                        .font(Font.custom("InriaSerif-Bold", size: 40))
                        .foregroundColor(.white)

                    Text("What would you\nlike to do?")
                        .font(Font.custom("InriaSerif-Bold", size: 30))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Don't worry you can change this later")
                        .font(Font.custom("InriaSerif-Regular", size: 12))
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                }

                VStack(spacing: 16) {
                    Button(action: {
                        // choose to learn in your language, persist and navigate
                        isLearningNewLanguage = false
                        showNativeLanguage = true
                    }) {
                        Text("Learn words in your language")
                            .font(Font.custom("InriaSerif-Bold", size: 16))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 0.7, green: 0.7, blue: 0.7))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PressableButtonStyle())

                    Button(action: {
                        // choose to learn a new language, persist and navigate
                        isLearningNewLanguage = true
                        showNativeLanguage = true
                    }) {
                        Text("Learn words in another language")
                            .font(Font.custom("InriaSerif-Bold", size: 16))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 0.2, green: 0.2, blue: 0.2))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 60)
            }
        }
        // navigationDestination uses the ancestor NavigationStack provided by the App
        .navigationDestination(isPresented: $showNativeLanguage) {
            NativeLanguageView()
        }
    }
}

#Preview {
    OnboardingView()
}
