# Lexis

A lightweight SwiftUI vocabulary learning app and widget. Lexis helps learners discover and review words in different languages using a compact, modern UI and an accompanying widget and Live Activity. Made so I can learn Japanese to prepare for my work term there!

**Video 1 — Onboarding**  
[![Onboarding](https://img.youtube.com/vi/HHwvt4r3vlA/0.jpg)](https://www.youtube.com/watch?v=HHwvt4r3vlA)

**Video 2 — App walkthrough**  
[![App walkthrough](https://img.youtube.com/vi/He1UdsS6sss/0.jpg)](https://www.youtube.com/watch?v=He1UdsS6sss)

## Features

- SwiftUI app using a simple vocabulary store (JSON) in `Resources/Data/vocabulary.json`.
- Widget and Live Activity bundles in `VocabularyWidget/` with a companion App Intent and persistence helpers.
- Onboarding flow for choosing languages and difficulty.
- Local persistence for preferences and vocabulary progress.

## Project structure (important files)

- `lexis/` — main app target
  - `Models/` — data models (`Languages.swift`, `Vocabulary.swift`)
  - `ViewModels/` and `Views/` — UI and view models
  - `Resources/Data/vocabulary.json` — initial vocabulary data
  - `Services/` — network and persistence helpers
- `VocabularyWidget/` — widget target and Live Activity
  - `VocabularyWord.swift`, `WidgetViews.swift`, `AppIntent.swift`

## Requirements

- macOS with Xcode 14+ (project targets iOS/tvOS/watchOS depending on your setup). Build and run using Xcode.
- Swift 5.7+ (use the Swift toolchain provided by Xcode).

## Running locally

1. Open `lexis.xcodeproj` or `lexis.xcworkspace` in Xcode.
2. Select the `lexis` scheme (or `VocabularyWidget` to run the widget target).
3. Build and run on a simulator or device.

Notes:

- The widget and Live Activity targets require entitlements (see `lexis/lexis.entitlements` and `VocabularyWidget/` entitlements). Ensure you have the appropriate signing setup in Xcode.
- If you add or update demo videos, place them in the repo's `demos/` folder and commit.

## Contributing

Contributions are welcome. Please open issues or PRs for bug reports and feature requests.

## Extras

Gna put this on the appstore if enough ppl like it and if I can afford the apple dev fee lol
