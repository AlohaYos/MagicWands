//
//  HapticsModel.swift
//  MagicWand
//
//  Created by Yos on 2026
//

import SwiftUI
import GameController
import CoreHaptics

/// Manages haptic feedback for MUSE device
@MainActor
@Observable
final class HapticsModel {
    var hapticEngine: CHHapticEngine? = nil
    var lightSwingPattern: CHHapticPattern? = nil  // Light haptic for wand swing
    var lightSwingPlayer: CHHapticPatternPlayer? = nil
    var impactPattern: CHHapticPattern? = nil      // Heavy haptic for collision
    var impactPlayer: CHHapticPatternPlayer? = nil
    
    /// Setup haptics engine and pattern
    func setupHaptics(haptics: GCDeviceHaptics) {
        // Initialize haptic engine
        if hapticEngine == nil {
            hapticEngine = haptics.createEngine(withLocality: .default)
            do {
                try hapticEngine?.start()
                print("✅ Haptic engine started")
            } catch {
                print("⚠️ Failed to start haptic engine: \(error)")
                return
            }
        }
        
        // Create light swing pattern (soft and quick)
        if lightSwingPattern == nil {
            do {
                lightSwingPattern = try CHHapticPattern(events: [
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),  // Light
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)   // Soft
                        ],
                        relativeTime: 0.0
                    )
                ], parameters: [])
                print("✅ Light swing haptic pattern created")
            } catch {
                print("⚠️ Failed to create light swing pattern: \(error)")
            }
        }
        
        // Create impact pattern (strong and sharp)
        if impactPattern == nil {
            do {
                impactPattern = try CHHapticPattern(events: [
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),  // Maximum
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)   // Sharp
                        ],
                        relativeTime: 0.0
                    )
                ], parameters: [])
                print("✅ Impact haptic pattern created")
            } catch {
                print("⚠️ Failed to create impact pattern: \(error)")
            }
        }
        
        // Create players
        if let lightSwingPattern = lightSwingPattern {
            do {
                lightSwingPlayer = try hapticEngine?.makePlayer(with: lightSwingPattern)
                print("✅ Light swing haptic player created")
            } catch {
                print("⚠️ Failed to create light swing player: \(error)")
            }
        }
        
        if let impactPattern = impactPattern {
            do {
                impactPlayer = try hapticEngine?.makePlayer(with: impactPattern)
                print("✅ Impact haptic player created")
            } catch {
                print("⚠️ Failed to create impact player: \(error)")
            }
        }
    }
    
    /// Trigger light swing haptic (for wand motion)
    func triggerLightSwing() {
        guard let player = lightSwingPlayer else {
            print("⚠️ Light swing haptic player not available")
            return
        }
        
        do {
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("⚠️ Failed to trigger light swing haptic: \(error)")
        }
    }
    
    /// Trigger impact haptic (for collision)
    func triggerImpact() {
        guard let player = impactPlayer else {
            print("⚠️ Impact haptic player not available")
            return
        }
        
        do {
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("⚠️ Failed to trigger impact haptic: \(error)")
        }
    }
}
