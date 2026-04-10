//
//  ContentView.swift
//  MagicWand
//  
//  Created by Yos on 2026
//  
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @State private var enlarge = false

    var body: some View {
        ZStack {
            RealityView { content in
                // Add the initial RealityKit content
                if let scene = try? await Entity(named: "Scene", in: realityKitContentBundle) {
                    content.add(scene)
                }
            } update: { content in
                // Update the RealityKit content when SwiftUI state changes
                if let scene = content.entities.first {
                    let uniformScale: Float = enlarge ? 1.4 : 1.0
                    scene.transform.scale = [uniformScale, uniformScale, uniformScale]
                }
            }
            .gesture(TapGesture().targetedToAnyEntity().onEnded { _ in
                enlarge.toggle()
            })
            
            VStack {
                Spacer()
                ToggleImmersiveSpaceButton()
                    .controlSize(.extraLarge)
                    .font(.largeTitle)
                    .scaleEffect(1.5)
                    .padding(.bottom, 100)
            }
        }
        .toolbar {
            if appModel.immersiveSpaceState == .open {
                ToolbarItemGroup(placement: .bottomOrnament) {
                    HStack(spacing: 16) {
                        ToggleDebugButton()
                        TogglePositionLoggingButton()
                    }
                }
            }
        }
    }
}

#Preview(windowStyle: .volumetric) {
    ContentView()
        .environment(AppModel())
}
