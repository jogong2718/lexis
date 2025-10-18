//
//  VocabularyWidgetLiveActivity.swift
//  VocabularyWidget
//
//  Created by Jonathan Gong on 2025-10-17.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct VocabularyWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct VocabularyWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: VocabularyWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension VocabularyWidgetAttributes {
    fileprivate static var preview: VocabularyWidgetAttributes {
        VocabularyWidgetAttributes(name: "World")
    }
}

extension VocabularyWidgetAttributes.ContentState {
    fileprivate static var smiley: VocabularyWidgetAttributes.ContentState {
        VocabularyWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: VocabularyWidgetAttributes.ContentState {
         VocabularyWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: VocabularyWidgetAttributes.preview) {
   VocabularyWidgetLiveActivity()
} contentStates: {
    VocabularyWidgetAttributes.ContentState.smiley
    VocabularyWidgetAttributes.ContentState.starEyes
}
