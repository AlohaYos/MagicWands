//
//  AppModel.swift
//  
//  
//  Created by Yos on 2026
//  
//

import SwiftUI

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed
    
    // MUSE device and wand management
    var wandModel = WandModel()
    var hapticsModel = HapticsModel()
    var sphereTargetsModel = SphereTargetsModel()
}
