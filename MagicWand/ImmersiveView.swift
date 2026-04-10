//
//  ImmersiveView.swift
//  MagicWand
//
//  Created by Yos on 2026
//
//

import SwiftUI
import RealityKit
import RealityKitContent
import ARKit

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @State private var isInitialized = false
    @State private var collisionSubscription: EventSubscription?
    @State private var lastHitTime: Date = .distantPast

    var body: some View {
        RealityView { content in
            // Add the initial RealityKit content
            if let immersiveContentEntity = try? await Entity(named: "Immersive", in: realityKitContentBundle) {
                content.add(immersiveContentEntity)

                // Put skybox here.  See example in World project available at
                // https://developer.apple.com/
            }

            // Add wand anchor entity if available
            if let wandAnchor = appModel.wandModel.wandAnchorEntity {
                content.add(wandAnchor)
            }

            // Setup sphere targets
            appModel.sphereTargetsModel.setupSpheres(in: content)

            // Setup collision detection with hit handling
            collisionSubscription = content.subscribe(to: CollisionEvents.Began.self) { event in
                // Check if collision involves a sphere and wand
                let isWandCollision = (event.entityA.name == "WandModel" || event.entityB.name == "WandModel")
                let isSphereCollision = (event.entityA.name.starts(with: "Sphere_") ||
                                        event.entityB.name.starts(with: "Sphere_"))

                if isWandCollision && isSphereCollision {
                    // Debounce: only trigger once per 0.2 seconds
                    let now = Date()
                    if now.timeIntervalSince(lastHitTime) > 0.2 {
                        lastHitTime = now

                        // Find which entity is the sphere
                        let sphereEntity = event.entityA.name.starts(with: "Sphere_") ? event.entityA : event.entityB
                        if let sphere = sphereEntity as? ModelEntity {
                            print("💥 Collision detected with \(sphere.name)!")
                            handleSphereHit(sphere: sphere)
                        }
                    }
                }
            }
        } update: { content in
            // Update wand position if anchor is added after initial setup
            if let wandAnchor = appModel.wandModel.wandAnchorEntity,
               wandAnchor.parent == nil {
                content.add(wandAnchor)
            }
        }
        .task {
            // Start Spatial Tracking Session for accessory tracking (runs once per view lifecycle)
            let configuration = SpatialTrackingSession.Configuration(tracking: [.accessory])
            let session = SpatialTrackingSession()
            await session.run(configuration)
        }
        .task {
            // Update loop for tracking state and debug logging
            while true {
                appModel.wandModel.update()
                appModel.sphereTargetsModel.updateSpheres()
                try? await Task.sleep(for: .seconds(0.016))  // ~60fps
            }
        }
        .onAppear {
            // One-time initialization on view appearance
            guard !isInitialized else {
                print("⚠️ ImmersiveView already initialized, skipping setup")
                return
            }

            print("✅ ImmersiveView appeared, starting initialization")
            isInitialized = true

            // Setup MUSE device notifications
            appModel.wandModel.setupNotifications()

            // Setup existing devices
            Task {
                await appModel.wandModel.setupExistingDevices(hapticsModel: appModel.hapticsModel)
            }
        }
    }

    // MARK: - Helper Functions

    /// Handle sphere hit by wand
    private func handleSphereHit(sphere: ModelEntity) {
        guard var physics = sphere.components[PhysicsBodyComponent.self],
              physics.isTranslationLocked.x else {
            return  // Already hit
        }

        print("💥 Sphere hit!")

        // Play heavy impact haptic feedback
        appModel.hapticsModel.triggerImpact()

        // Mark as hit (unlock to indicate hit state)
        physics.isTranslationLocked = (x: false, y: false, z: false)
        sphere.components[PhysicsBodyComponent.self] = physics

        // Create particle effect
        createParticleEffect(at: sphere.position(relativeTo: nil), sphere: sphere)

        // Fade out and remove sphere
        Task {
            // Very quick fade out (5 frames, 0.05 seconds total)
            if var model = sphere.model {
                for i in 0..<5 {
                    let opacity = 1.0 - Float(i) / 5.0
                    if var material = model.materials.first as? SimpleMaterial {
                        material.color.tint = material.color.tint.withAlphaComponent(CGFloat(opacity))
                        model.materials = [material]
                        sphere.model = model
                    }
                    try? await Task.sleep(for: .seconds(0.01))
                }
            }

            // Remove from scene
            sphere.removeFromParent()
            appModel.sphereTargetsModel.removeSphere(sphere)
            print("🗑️ Sphere removed")
        }
    }

    /// Create particle explosion effect
    private func createParticleEffect(at position: SIMD3<Float>, sphere: ModelEntity) {

        // Get sphere color from material
        guard let material = sphere.model?.materials.first as? SimpleMaterial else { return }
        let sphereColor = material.color.tint

        // Create particle emitter entity
        let particleEntity = Entity()
        particleEntity.position = position

        // Use impact preset as base (burst effect)
        var particleEmitter = ParticleEmitterComponent.Presets.impact

        // Customize color to match sphere (convert UIColor to RealityKit Color)
        typealias ParticleColor = ParticleEmitterComponent.ParticleEmitter.ParticleColor
        typealias ColorValue = ParticleColor.ColorValue
        typealias RKColor = ParticleEmitterComponent.ParticleEmitter.Color

        // Convert UIColor to RGBA components for RealityKit Color
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        sphereColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let rkColor = RKColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))

        let particleColorValue = ColorValue.single(rkColor)
        particleEmitter.mainEmitter.color = ParticleColor.constant(particleColorValue)

        // Adjust speed and size
        particleEmitter.speed = 1.5
        particleEmitter.mainEmitter.birthRate = 200

        particleEntity.components[ParticleEmitterComponent.self] = particleEmitter

        // Add to content (find parent content)
        if let parent = sphere.parent {
            parent.addChild(particleEntity)

            // Remove after particles die
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                particleEntity.removeFromParent()
            }
        }

        print("✨ Particle effect created at \(position)")
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
