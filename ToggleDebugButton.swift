//
//  ToggleDebugButton.swift
//  MagicWand
//
//  Created by Yos on 2026
//

import SwiftUI

struct ToggleDebugButton: View {
    @Environment(AppModel.self) private var appModel
    
    var body: some View {
        Button {
            appModel.wandModel.toggleDebug()
        } label: {
            Text(appModel.wandModel.isDebugEnabled ? "Hide Debug Cubes" : "Show Debug Cubes")
        }
        .animation(.none, value: 0)
        .fontWeight(.semibold)
    }
}
