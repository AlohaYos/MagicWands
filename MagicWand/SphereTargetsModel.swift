//
//  SphereTargetsModel.swift
//  MagicWand
//
//  Created by Yos on 2026
//

import SwiftUI
import RealityKit

/// Manages floating sphere targets for wand interaction
@MainActor
@Observable
final class SphereTargetsModel {
    // Sphere configuration
    private let maxSpheres: Int = 10  // Maximum number of spheres
    private let sphereRadius: Float = 0.09  // 60% of original 0.15m = 0.09m (9cm)
    private let spawnDistance: Float = 0.8  // 0.8m from user
    private let spawnRadius: Float = 0.6  // 0.6m radius for spawn area

    // Sphere management
    private var spheres: [ModelEntity] = []
    private var sphereBasePositions: [SIMD3<Float>] = []  // Store base positions
    private var sphereAnimationOffsets: [Float] = []
    private var isInitialized = false  // Track initialization state
    private var sphereCounter: Int = 0  // Global counter for unique sphere names
    private var contentReference: RealityViewContent?  // Store content reference for respawning
    
    // Animation tracking
    private var animationTime: Float = 0.0
    
    // Color palette
    private let colors: [UIColor] = [
        .systemBlue, .systemGreen, .systemRed, .systemYellow,
        .systemPurple, .systemOrange, .systemPink, .systemTeal,
        .systemIndigo, .systemCyan
    ]

    /// Setup sphere targets in the immersive space
    func setupSpheres(in content: RealityViewContent) {
        guard !isInitialized else {
            print("⚠️ SphereTargetsModel already initialized, skipping setup")
            return
        }
        
        // Store content reference for later respawning
        contentReference = content
        
        // Create initial spheres
        for _ in 0..<maxSpheres {
            spawnNewSphere()
        }
        
        isInitialized = true
        print("✅ Created \(maxSpheres) sphere targets")
    }
    
    /// Remove sphere from list and spawn a new one
    func removeSphere(_ sphere: ModelEntity) {
        if let index = spheres.firstIndex(of: sphere) {
            spheres.remove(at: index)
            sphereBasePositions.remove(at: index)
            sphereAnimationOffsets.remove(at: index)
            
            print("🗑️ Removed sphere, count: \(spheres.count)")
            
            // Spawn a new sphere to maintain maxSpheres count
            spawnNewSphere()
        }
    }
    
    /// Spawn a new sphere at a random position
    private func spawnNewSphere() {
        guard let content = contentReference else {
            print("⚠️ Cannot spawn sphere: content reference is nil")
            return
        }
        
        // Create sphere mesh with fixed radius
        let sphereMesh = MeshResource.generateSphere(radius: sphereRadius)
        
        // Random color from palette
        let randomColor = colors.randomElement() ?? .systemBlue
        
        // Create material
        var material = SimpleMaterial(color: randomColor, isMetallic: false)
        
        let sphere = ModelEntity(mesh: sphereMesh, materials: [material])
        sphere.name = "Sphere_\(sphereCounter)"
        sphereCounter += 1
        
        // Random position in front of user
        let randomPosition = randomSpawnPosition()
        sphere.position = randomPosition
        
        // Store base position and animation offset
        sphereBasePositions.append(randomPosition)
        sphereAnimationOffsets.append(Float.random(in: 0...(2 * .pi)))
        
        // Add collision component
        sphere.components[CollisionComponent.self] = CollisionComponent(
            shapes: [.generateSphere(radius: sphereRadius)],
            mode: .default,
            filter: .init(group: .all, mask: .all)
        )
        
        // Add dynamic physics body
        sphere.components[PhysicsBodyComponent.self] = PhysicsBodyComponent(
            massProperties: .default,
            mode: .dynamic
        )
        
        // Lock position to prevent falling (freeze all axes)
        sphere.components[PhysicsBodyComponent.self]?.isTranslationLocked = (x: true, y: true, z: true)
        sphere.components[PhysicsBodyComponent.self]?.isRotationLocked = (x: true, y: true, z: true)
        
        content.add(sphere)
        spheres.append(sphere)
        
        print("🎯 Spawned new sphere \(sphere.name): position=\(randomPosition), count: \(spheres.count)")
    }



    /// Generate random spawn position in front of user
    private func randomSpawnPosition() -> SIMD3<Float> {
        // Random angle and position in hemisphere
        let angle = Float.random(in: 0...(2 * .pi))
        let height = Float.random(in: 1.2...1.6)  // Eye level
        let distance = spawnDistance + Float.random(in: -0.2...0.2)

        let x = cos(angle) * spawnRadius * Float.random(in: 0.3...1.0)
        let y = height
        let z = -distance + sin(angle) * spawnRadius * Float.random(in: 0.3...1.0)

        return SIMD3(x, y, z)
    }

    /// Update sphere animations
    func updateSpheres() {
        guard isInitialized else { return }  // Don't update until initialized

        animationTime += 0.016

        for (index, sphere) in spheres.enumerated() {
            guard index < sphereBasePositions.count else { continue }
            guard index < sphereAnimationOffsets.count else { continue }

            guard let physics = sphere.components[PhysicsBodyComponent.self],
                  physics.isTranslationLocked.x else {
                continue  // Skip if sphere is unlocked (hit)
            }

            // Use stored base position
            let basePosition = sphereBasePositions[index]

            // Gentle floating motion with individual phase offset
            let offset = sphereAnimationOffsets[index]
            let floatOffset: SIMD3<Float> = [
                sin(animationTime * 0.5 + offset) * 0.05,
                sin(animationTime * 0.7 + offset * 1.3) * 0.08,
                sin(animationTime * 0.3 + offset * 0.7) * 0.03
            ]

            sphere.position = basePosition + floatOffset
        }
    }
}
