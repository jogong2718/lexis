//
//  VocabularyWidgetBundle.swift
//  VocabularyWidget
//
//  Created by Jonathan Gong on 2025-10-17.
//

import WidgetKit
import SwiftUI

@main
struct VocabularyWidgetBundle: WidgetBundle {
    var body: some Widget {
        VocabularyWidget()
        VocabularyWidgetControl()
        VocabularyWidgetLiveActivity()
    }
}
