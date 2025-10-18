import SwiftUI

struct TimesView: View {
    // Start time
    @AppStorage(PrefKey.startHour, store: PreferencesStore.defaults) private var startHour: Int = 8
    @AppStorage(PrefKey.startMinute, store: PreferencesStore.defaults) private var startMinute:
        Int = 0
    @AppStorage(PrefKey.startIsPM, store: PreferencesStore.defaults) private var startIsPM: Bool =
        false

    // End time
    @AppStorage(PrefKey.endHour, store: PreferencesStore.defaults) private var endHour: Int = 8
    @AppStorage(PrefKey.endMinute, store: PreferencesStore.defaults) private var endMinute: Int = 0
    @AppStorage(PrefKey.endIsPM, store: PreferencesStore.defaults) private var endIsPM: Bool = true

    @AppStorage(PrefKey.onboardingCompleted, store: PreferencesStore.defaults) private
        var onboardingCompleted: Bool = false
    @State private var showHome = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // background
            Color(red: 0.12, green: 0.12, blue: 0.12)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // top content
                VStack(spacing: 40) {
                    // Start Time Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Start Time (what time of day to start learning?)")
                            .font(Font.custom("InriaSerif-Bold", size: 12))
                            .foregroundColor(.black)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            // Hour picker
                            VStack(spacing: 4) {
                                Picker("", selection: $startHour) {
                                    ForEach(1...12, id: \.self) { hour in
                                        Text("\(hour)")
                                            .font(Font.custom("InriaSerif-Bold", size: 32))
                                            .foregroundColor(.black)  // ensure black label
                                            .tag(hour)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 80, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .environment(\.colorScheme, .light)  // force light scheme so numbers render dark

                                Text("Hour")
                                    .font(Font.custom("InriaSerif-Regular", size: 12))
                                    .foregroundColor(.black.opacity(0.6))
                            }

                            Text(":")
                                .font(Font.custom("InriaSerif-Bold", size: 32))
                                .foregroundColor(.black)
                                .padding(.bottom, 20)

                            // Minute picker
                            VStack(spacing: 4) {
                                Picker("", selection: $startMinute) {
                                    ForEach(0..<60, id: \.self) { minute in
                                        Text(String(format: "%02d", minute))
                                            .font(Font.custom("InriaSerif-Bold", size: 32))
                                            .foregroundColor(.black)  // ensure black label
                                            .tag(minute)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 80, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .environment(\.colorScheme, .light)  // force light scheme

                                Text("Minute")
                                    .font(Font.custom("InriaSerif-Regular", size: 12))
                                    .foregroundColor(.black.opacity(0.6))
                            }

                            // AM/PM toggle
                            VStack(spacing: 8) {
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        startIsPM = false
                                    }
                                } label: {
                                    Text("AM")
                                        .font(Font.custom("InriaSerif-Bold", size: 14))
                                        .foregroundColor(startIsPM ? .black : .white)
                                        .frame(width: 50, height: 35)
                                        .background(startIsPM ? Color.white : Color.black)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        startIsPM = true
                                    }
                                } label: {
                                    Text("PM")
                                        .font(Font.custom("InriaSerif-Bold", size: 14))
                                        .foregroundColor(startIsPM ? .white : .black)
                                        .frame(width: 50, height: 35)
                                        .background(startIsPM ? Color.black : Color.white)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.bottom, 20)
                        }
                    }
                    .padding(20)
                    .background(Color(white: 0.86))
                    .cornerRadius(18)
                    .padding(.horizontal, 24)
                    .padding(.top, 80)

                    // End Time Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("End Time (what time of day to stop learning?)")
                            .font(Font.custom("InriaSerif-Bold", size: 12))
                            .foregroundColor(.black)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            // Hour picker
                            VStack(spacing: 4) {
                                Picker("", selection: $endHour) {
                                    ForEach(1...12, id: \.self) { hour in
                                        Text("\(hour)")
                                            .font(Font.custom("InriaSerif-Bold", size: 32))
                                            .foregroundColor(.black)  // ensure black label
                                            .tag(hour)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 80, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .environment(\.colorScheme, .light)  // force light scheme

                                Text("Hour")
                                    .font(Font.custom("InriaSerif-Regular", size: 12))
                                    .foregroundColor(.black.opacity(0.6))
                            }

                            Text(":")
                                .font(Font.custom("InriaSerif-Bold", size: 32))
                                .foregroundColor(.black)
                                .padding(.bottom, 20)

                            // Minute picker
                            VStack(spacing: 4) {
                                Picker("", selection: $endMinute) {
                                    ForEach(0..<60, id: \.self) { minute in
                                        Text(String(format: "%02d", minute))
                                            .font(Font.custom("InriaSerif-Bold", size: 32))
                                            .foregroundColor(.black)  // ensure black label
                                            .tag(minute)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 80, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .environment(\.colorScheme, .light)  // force light scheme

                                Text("Minute")
                                    .font(Font.custom("InriaSerif-Regular", size: 12))
                                    .foregroundColor(.black.opacity(0.6))
                            }

                            // AM/PM toggle
                            VStack(spacing: 8) {
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        endIsPM = false
                                    }
                                } label: {
                                    Text("AM")
                                        .font(Font.custom("InriaSerif-Bold", size: 14))
                                        .foregroundColor(endIsPM ? .black : .white)
                                        .frame(width: 50, height: 35)
                                        .background(endIsPM ? Color.white : Color.black)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        endIsPM = true
                                    }
                                } label: {
                                    Text("PM")
                                        .font(Font.custom("InriaSerif-Bold", size: 14))
                                        .foregroundColor(endIsPM ? .white : .black)
                                        .frame(width: 50, height: 35)
                                        .background(endIsPM ? Color.black : Color.white)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.bottom, 20)
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

            // Continue button anchored at the bottom
            VStack {
                Spacer()
                Button {
                    // Mark onboarding as complete and navigate to home
                    onboardingCompleted = true
                    showHome = true
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
        .navigationDestination(isPresented: $showHome) {
            HomeView()
        }
    }
}

#Preview {
    NavigationStack {
        TimesView()
    }
}
