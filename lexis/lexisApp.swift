//
//  lexisApp.swift
//  lexis
//
//  Created by Jonathan Gong on 2025-10-16.
//

import SwiftUI

@main
struct lexisApp: App {
    // read onboarding completion from the shared preferences store
    @AppStorage(PrefKey.onboardingCompleted, store: PreferencesStore.defaults)
    private var onboardingCompleted: Bool = false

    var body: some Scene {
        WindowGroup {
            // single root NavigationStack for the whole app
            NavigationStack {
                if onboardingCompleted {
                    HomeView()
                } else {
                    OnboardingView()
                }
            }
        }
    }
}
