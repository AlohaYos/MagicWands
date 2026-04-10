//
//  TogglePositionLoggingButton.swift
//  MagicWand
//
//  Created by Yos on 2026
//

import SwiftUI

struct TogglePositionLoggingButton: View {
    @Environment(AppModel.self) private var appModel
    
    var body: some View {
        Button {
            appModel.wandModel.togglePositionLogging()
        } label: {
            Text(appModel.wandModel.isPositionLoggingEnabled ? "Hide Position Logs" : "Show Position Logs")
        }
        .animation(.none, value: 0)
        .fontWeight(.semibold)
    }
}
