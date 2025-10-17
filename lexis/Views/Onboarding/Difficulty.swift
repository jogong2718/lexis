import SwiftUI

struct DifficultyView: View {
    // Difficulty toggles (multi-select)
    @AppStorage(PrefKey.difficultyHard, store: PreferencesStore.defaults) private
        var difficultyHard: Bool = true
    @AppStorage(PrefKey.difficultyMedium, store: PreferencesStore.defaults) private
        var difficultyMedium: Bool = true
    @AppStorage(PrefKey.difficultyEasy, store: PreferencesStore.defaults) private
        var difficultyEasy: Bool = true

    // Frequency stored as two numbers (preferred)
    @AppStorage(PrefKey.frequencyMin, store: PreferencesStore.defaults) private
        var frequencyMin: Int = 2
    @AppStorage(PrefKey.frequencyMax, store: PreferencesStore.defaults) private
        var frequencyMax: Int = 4

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // background
            Color(red: 0.12, green: 0.12, blue: 0.12)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // top content
                VStack(spacing: 40) {
                    // Difficulty Card
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Difficulty")
                            .font(Font.custom("InriaSerif-Bold", size: 20))
                            .foregroundColor(.black)

                        Text(
                            "The difficulty of the vocabulary to learn. Select all levels you want. We'll mix and match for you!"
                        )
                        .font(Font.custom("InriaSerif-Regular", size: 14))
                        .foregroundColor(.black.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)

                        Divider().padding(.vertical, 4)

                        // Hard
                        HStack(spacing: 12) {
                            Image("L_pfp")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))

                            Text("Hard")
                                .font(Font.custom("InriaSerif-Regular", size: 16))
                                .foregroundColor(.black)

                            Spacer()

                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    difficultyHard.toggle()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    if difficultyHard {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                    Text(difficultyHard ? "Selected" : "Select")
                                        .font(Font.custom("InriaSerif-Bold", size: 14))
                                        .foregroundColor(difficultyHard ? .white : .black)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .frame(minWidth: difficultyHard ? 110 : 80)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(difficultyHard ? Color.black : Color.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .scaleEffect(difficultyHard ? 1.05 : 1.0)
                                .animation(
                                    .spring(response: 0.3, dampingFraction: 0.6),
                                    value: difficultyHard)
                            }
                            .buttonStyle(.plain)
                        }

                        Divider().padding(.vertical, 2)

                        // Medium
                        HStack(spacing: 12) {
                            Image("stark_pfp")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))

                            Text("Medium")
                                .font(Font.custom("InriaSerif-Regular", size: 16))
                                .foregroundColor(.black)

                            Spacer()

                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    difficultyMedium.toggle()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    if difficultyMedium {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                    Text(difficultyMedium ? "Selected" : "Select")
                                        .font(Font.custom("InriaSerif-Bold", size: 14))
                                        .foregroundColor(difficultyMedium ? .white : .black)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .frame(minWidth: difficultyMedium ? 110 : 80)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(difficultyMedium ? Color.black : Color.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .scaleEffect(difficultyMedium ? 1.05 : 1.0)
                                .animation(
                                    .spring(response: 0.3, dampingFraction: 0.6),
                                    value: difficultyMedium)
                            }
                            .buttonStyle(.plain)
                        }

                        Divider().padding(.vertical, 2)

                        // Easy
                        HStack(spacing: 12) {
                            Image("aqua_pfp")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))

                            Text("Easy")
                                .font(Font.custom("InriaSerif-Regular", size: 16))
                                .foregroundColor(.black)

                            Spacer()

                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    difficultyEasy.toggle()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    if difficultyEasy {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                    Text(difficultyEasy ? "Selected" : "Select")
                                        .font(Font.custom("InriaSerif-Bold", size: 14))
                                        .foregroundColor(difficultyEasy ? .white : .black)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .frame(minWidth: difficultyEasy ? 110 : 80)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(difficultyEasy ? Color.black : Color.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .scaleEffect(difficultyEasy ? 1.05 : 1.0)
                                .animation(
                                    .spring(response: 0.3, dampingFraction: 0.6),
                                    value: difficultyEasy)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                    .background(Color(white: 0.86))
                    .cornerRadius(18)
                    .padding(.horizontal, 24)

                    // Frequency Card
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Frequency")
                            .font(Font.custom("InriaSerif-Bold", size: 20))
                            .foregroundColor(.black)

                        Text("How many words do you want to learn in a day? Select one.")
                            .font(Font.custom("InriaSerif-Regular", size: 14))
                            .foregroundColor(.black.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)

                        Divider().padding(.vertical, 0)

                        let ranges: [(Int, Int)] = [(2, 4), (5, 8), (9, 12)]
                        ForEach(ranges.indices, id: \.self) { idx in
                            let (minVal, maxVal) = ranges[idx]
                            let isSelected = (frequencyMin == minVal && frequencyMax == maxVal)
                            HStack {
                                Text("\(minVal)-\(maxVal)")
                                    .font(Font.custom("InriaSerif-Regular", size: 16))
                                    .foregroundColor(.black)
                                Spacer()

                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        frequencyMin = minVal
                                        frequencyMax = maxVal
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.white)
                                                .transition(.scale.combined(with: .opacity))
                                        }
                                        Text(isSelected ? "Selected" : "Select")
                                            .font(Font.custom("InriaSerif-Bold", size: 14))
                                            .foregroundColor(isSelected ? .white : .black)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .frame(minWidth: isSelected ? 110 : 80)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(isSelected ? Color.black : Color.white)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                    .scaleEffect(isSelected ? 1.05 : 1.0)
                                    .animation(
                                        .spring(response: 0.3, dampingFraction: 0.6),
                                        value: isSelected)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 2)
                            if idx < ranges.count - 1 {
                                Divider().padding(.vertical, 2)
                            }
                        }
                    }
                    .padding(20)
                    .background(Color(white: 0.86))
                    .cornerRadius(18)
                    .padding(.horizontal, 24)

                    Spacer(minLength: 24)
                }
            }
            .padding(.top, 20)

            Spacer()

            // Continue button anchored at the bottom
            VStack {
                Spacer()
                Button {
                    // validate at least one difficulty is selected
                    if !(difficultyHard || difficultyMedium || difficultyEasy) {
                        difficultyHard = true
                        difficultyMedium = true
                        difficultyEasy = true
                    }
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
                .padding(.bottom, 40)
            }
        }
        .onAppear {

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

#Preview {
    DifficultyView()
}
