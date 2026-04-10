//
//  WandModel.swift
//  MagicWand
//
//  Created by Yos on 2026
//

import SwiftUI
import RealityKit
import GameController
import ARKit

/// Manages MUSE device tracking and wand entity state
@MainActor
@Observable
final class WandModel {
    // MUSE physical dimensions
    private let museLength: Float = 0.16  // total length of MUSE stylus
    private let debugCubeSize: Float = 0.015  // 1.5cm cube size
    
    // Wand dimensions and state
	private let maxWandLength: Float = 1.0  // Maximum wand extension (1m)
	private let minWandLength: Float = 0.001  // Minimum wand extension (1mm)
    private let wandAnimationDuration: Double = 1.0  // Extension/retraction animation duration
    var isWandExtended: Bool = false
    
    // Wand color cycling
    enum WandColor: CaseIterable {
        case white, blue, green, red, purple, yellow
        
        var color: UIColor {
            switch self {
            case .white: return UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            case .blue: return UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0)
            case .green: return UIColor(red: 0.3, green: 1.0, blue: 0.3, alpha: 1.0)
            case .red: return UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0)
            case .purple: return UIColor(red: 0.8, green: 0.3, blue: 1.0, alpha: 1.0)
            case .yellow: return UIColor(red: 1.0, green: 1.0, blue: 0.3, alpha: 1.0)
            }
        }
    }
    private var currentColorIndex: Int = 0
    private var wandColors: [WandColor] = WandColor.allCases
    
    // MUSE tracking
    var museDevice: GCDevice? = nil
    var wandAnchorEntity: AnchorEntity? = nil
    var wandEntity: ModelEntity? = nil
    
    // Motion detection for haptic feedback
    var motionHapticsEnabled: Bool = true
    private var lastPosition: SIMD3<Float>? = nil
    private var lastUpdateTime: TimeInterval = 0
    private let velocityThreshold: Float = 0.8  // m/s threshold for triggering haptics (lowered for more sensitive detection)
    private var hapticsModel: HapticsModel? = nil
    
    // Debug visualization
    var isDebugEnabled: Bool = false
    var isPositionLoggingEnabled: Bool = false
    var tipDebugCube: ModelEntity? = nil
    var centerDebugCube: ModelEntity? = nil
    var tailDebugCube: ModelEntity? = nil
    
    // Debug counters
    private var setupSpatialAccessoryCallCount = 0
    private var handleDeviceConnectionCallCount = 0
    private var setupExistingDevicesCallCount = 0
    
    /// Setup MUSE device connection notifications
    func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            Task { @MainActor in
                try? await self?.handleDeviceConnection(device: controller)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.GCStylusDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let stylus = notification.object as? GCStylus else { return }
            Task { @MainActor in
                try? await self?.handleDeviceConnection(device: stylus)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleDeviceDisconnection()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.GCStylusDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleDeviceDisconnection()
            }
        }
    }
    
    /// Setup existing devices at app launch
    func setupExistingDevices(hapticsModel: HapticsModel) async {
        setupExistingDevicesCallCount += 1
        print("🔢 setupExistingDevices called (count: \(setupExistingDevicesCallCount))")
        
        // Skip if already setup (prevent duplicate setup)
        guard wandAnchorEntity == nil else {
            print("⚠️ Wand already setup, skipping device scan")
            return
        }
        
        let controllers = GCController.controllers()
        let styluses = GCStylus.styli
        
        print("🔍 Scanning for existing MUSE devices...")
        
        // Check existing controllers
        for controller in controllers {
            if controller.productCategory == GCProductCategorySpatialController {
                try? await setupSpatialAccessory(device: controller, hapticsModel: hapticsModel)
                return  // Only setup one device
            }
        }
        
        // Check existing styluses
        for stylus in styluses {
            if stylus.productCategory == GCProductCategorySpatialStylus {
                try? await setupSpatialAccessory(device: stylus, hapticsModel: hapticsModel)
                return  // Only setup one device
            }
        }
        
        print("ℹ️ No MUSE devices found at startup")
    }
    
    /// Handle device connection
    private func handleDeviceConnection(device: GCDevice) async throws {
        handleDeviceConnectionCallCount += 1
        print("🔢 handleDeviceConnection called (count: \(handleDeviceConnectionCallCount))")
        
        guard device.productCategory == GCProductCategorySpatialController ||
              device.productCategory == GCProductCategorySpatialStylus else {
            return
        }
        
        // Initialize haptics if needed
        let hapticsModel = HapticsModel()
        
        // Get haptics from specific device types
        if let controller = device as? GCController, let haptics = controller.haptics {
            hapticsModel.setupHaptics(haptics: haptics)
        } else if let stylus = device as? GCStylus, let haptics = stylus.haptics {
            hapticsModel.setupHaptics(haptics: haptics)
        }
        
        try await setupSpatialAccessory(device: device, hapticsModel: hapticsModel)
    }
    
    /// Handle device disconnection
    private func handleDeviceDisconnection() {
        museDevice = nil
        wandAnchorEntity?.removeFromParent()
        wandAnchorEntity = nil
    }
    
    /// Setup spatial accessory anchoring
    func setupSpatialAccessory(device: GCDevice, hapticsModel: HapticsModel) async throws {
        setupSpatialAccessoryCallCount += 1
        print("🔢 setupSpatialAccessory called (count: \(setupSpatialAccessoryCallCount))")
        print("   📱 Device: \(device.vendorName ?? "Unknown") - \(device.productCategory)")
        
        // Create anchoring source
        let source = try await AnchoringComponent.AccessoryAnchoringSource(device: device)
        
        // Get location (priority: "aim" > "tip")
        guard let location = source.locationName(named: "aim") ?? source.locationName(named: "tip") else {
            print("⚠️ No suitable location found for MUSE device")
            return
        }
        
        // Create anchor entity with predicted tracking
        let anchorEntity = AnchorEntity(
            .accessory(from: source, location: location),
            trackingMode: .predicted,
            physicsSimulation: .none
        )
        anchorEntity.name = "WandAnchor"
        
        // Create wand entity (fixed 1m mesh, use scale for animation)
        let wandMesh = MeshResource.generateCylinder(height: maxWandLength, radius: 0.005)
        // Use UnlitMaterial for glowing effect
        var wandMaterial = UnlitMaterial()
        wandMaterial.color = .init(tint: .white)
        let wandModel = ModelEntity(mesh: wandMesh, materials: [wandMaterial])
        
        // Rotate cylinder to point forward (default cylinder is Y-up, we want Z-forward)
        wandModel.transform.rotation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        // Position at MUSE tip
        wandModel.position = [0, 0, 0]
        // Start with minimal scale (collapsed state)
        wandModel.scale = [1, minWandLength/maxWandLength, 1]  // Y-scale controls length after rotation
        
        // Add collision component (will be enabled when wand extends)
        let wandCollisionShape = ShapeResource.generateCapsule(height: maxWandLength, radius: 0.01)
        wandModel.components[CollisionComponent.self] = CollisionComponent(
            shapes: [wandCollisionShape],
            mode: .default,
            filter: .init(group: [], mask: .all)  // Start disabled (empty group)
        )
        
        // Add kinematic physics body (moves with code, not physics simulation)
        wandModel.components[PhysicsBodyComponent.self] = PhysicsBodyComponent(
            massProperties: .default,
            mode: .kinematic
        )
        wandModel.name = "WandModel"
        		
        anchorEntity.addChild(wandModel)
        
        // Create debug visualization cubes
        createDebugCubes(parent: anchorEntity)
        
        // Store references
        museDevice = device
        wandAnchorEntity = anchorEntity
        wandEntity = wandModel
        self.hapticsModel = hapticsModel
        
//		setWandOpacity(0.0)

        // Setup button inputs
        setupButtonInputs(device: device, hapticsModel: hapticsModel)
        
        print("✅ MUSE device connected and wand setup complete")
    }
    
    /// Create debug visualization cubes at MUSE tip, center, and tail positions
    private func createDebugCubes(parent: Entity) {
        // Calculate positions: cube center should align with MUSE tip/center/tail
        // Tip cube center at MUSE tip (0)
        let tipPosition: Float = 0.0
        
        // Tail cube center at MUSE tail
        let tailPosition: Float = museLength
        
        // Center cube center at midpoint between tip and tail cube centers
        let centerPosition: Float = (tipPosition + tailPosition) / 2.0
        
        // Tip cube (red) - cube center at MUSE tip
        let tipMesh = MeshResource.generateBox(size: debugCubeSize)
        let tipMaterial = SimpleMaterial(color: .red, isMetallic: false)
        let tipCube = ModelEntity(mesh: tipMesh, materials: [tipMaterial])
        tipCube.position = [0, 0, tipPosition]
        tipCube.name = "TipDebugCube"
        tipCube.isEnabled = isDebugEnabled
        parent.addChild(tipCube)
        tipDebugCube = tipCube
        
        // Center cube (green) - cube center at midpoint
        let centerMesh = MeshResource.generateBox(size: debugCubeSize)
        let centerMaterial = SimpleMaterial(color: .green, isMetallic: false)
        let centerCube = ModelEntity(mesh: centerMesh, materials: [centerMaterial])
        centerCube.position = [0, 0, centerPosition]
        centerCube.name = "CenterDebugCube"
        centerCube.isEnabled = isDebugEnabled
        parent.addChild(centerCube)
        centerDebugCube = centerCube
        
        // Tail cube (blue) - cube center at MUSE tail
        let tailMesh = MeshResource.generateBox(size: debugCubeSize)
        let tailMaterial = SimpleMaterial(color: .blue, isMetallic: false)
        let tailCube = ModelEntity(mesh: tailMesh, materials: [tailMaterial])
        tailCube.position = [0, 0, tailPosition]
        tailCube.name = "TailDebugCube"
        tailCube.isEnabled = isDebugEnabled
        parent.addChild(tailCube)
        tailDebugCube = tailCube
    }
    
    /// Cycle wand color (white → blue → green → red → purple → yellow → white)
    func cycleWandColor() {
        guard let wandModel = wandEntity else { return }
        
        // Move to next color
        currentColorIndex = (currentColorIndex + 1) % wandColors.count
        let newColor = wandColors[currentColorIndex]
        
        // Create glowing material with emissive color
        var material = UnlitMaterial()
        material.color = .init(tint: newColor.color)
        wandModel.model?.materials = [material]
        
        print("🎨 Wand color changed to: \(newColor)")
    }
    
    /// Toggle debug visualization
    func toggleDebug() {
        isDebugEnabled.toggle()
        tipDebugCube?.isEnabled = isDebugEnabled
        centerDebugCube?.isEnabled = isDebugEnabled
        tailDebugCube?.isEnabled = isDebugEnabled
        print("🐛 Debug visualization: \(isDebugEnabled ? "ON" : "OFF")")
    }
    
    /// Toggle position logging
    func togglePositionLogging() {
        isPositionLoggingEnabled.toggle()
        print("📍 Position logging: \(isPositionLoggingEnabled ? "ON" : "OFF")")
    }
    
    /// Log debug positions to console
    func logDebugPositions() {
        guard isDebugEnabled,
              isPositionLoggingEnabled,
              let tipCube = tipDebugCube,
              let centerCube = centerDebugCube,
              let tailCube = tailDebugCube else {
            return
        }
        
        let tipPos = tipCube.position(relativeTo: nil)
        let centerPos = centerCube.position(relativeTo: nil)
        let tailPos = tailCube.position(relativeTo: nil)
        
        print("📍 Tip: (\(String(format: "%.3f", tipPos.x)), \(String(format: "%.3f", tipPos.y)), \(String(format: "%.3f", tipPos.z)))")
        print("📍 Center: (\(String(format: "%.3f", centerPos.x)), \(String(format: "%.3f", centerPos.y)), \(String(format: "%.3f", centerPos.z)))")
        print("📍 Tail: (\(String(format: "%.3f", tailPos.x)), \(String(format: "%.3f", tailPos.y)), \(String(format: "%.3f", tailPos.z)))")
    }
    
    /// Toggle wand extension (extend/retract)
    func toggleWandExtension() {
        guard let wandModel = wandEntity else { return }
        
        isWandExtended.toggle()
        
        // Toggle collision detection
        if var collision = wandModel.components[CollisionComponent.self] {
            collision.filter = isWandExtended ? 
                CollisionFilter(group: .all, mask: .all) :  // Enable collision
                CollisionFilter(group: [], mask: .all)       // Disable collision
            wandModel.components[CollisionComponent.self] = collision
            print("🔷 Collision \(isWandExtended ? "enabled" : "disabled")")
        }
        
        // A点 = MUSE tip + 0.5m forward = [0, 0, -0.5]
        // Extended: scale [1, 1, 1], position moves to A点 [0, 0, -0.5]
        // Retracted: scale [1, 0.001, 1], position stays at A点 (no position animation)

		let targetScale: SIMD3<Float> = isWandExtended ? [1, 1, 1] : [1, minWandLength/maxWandLength, 1]
		let targetPosition: SIMD3<Float> = isWandExtended ? [0, 0, -maxWandLength / 2] : [0, 0, 0]
		var positionTransform = wandModel.transform
		if isWandExtended {
			// extend - make visible before animation starts
			setWandOpacity(1.0)
			positionTransform.translation = targetPosition
			positionTransform.scale = targetScale
			wandModel.move(to: positionTransform, relativeTo: wandModel.parent, duration: wandAnimationDuration)
		}
		else{
			// retract
			positionTransform.translation = targetPosition
			wandModel.move(to: positionTransform, relativeTo: wandModel.parent, duration: wandAnimationDuration)
			positionTransform.scale = targetScale
			wandModel.move(to: positionTransform, relativeTo: wandModel.parent, duration: wandAnimationDuration)
			
			// Wait for animation to complete, then make invisible
			Task {
				try? await Task.sleep(for: .seconds(wandAnimationDuration))
				setWandOpacity(0.0)
			}
		}

        print("✨ Wand \(isWandExtended ? "extended" : "retracted")")
    }
    
    /// Set wand opacity
    private func setWandOpacity(_ opacity: Float) {
        guard let wandModel = wandEntity else { return }
        
        // Get current material and color
        guard var material = wandModel.model?.materials.first as? UnlitMaterial else { return }
        
        // Set opacity using blending mode
        if opacity < 1.0 {
            material.blending = .transparent(opacity: .init(floatLiteral: opacity))
        } else {
            material.blending = .opaque
        }
        
        wandModel.model?.materials = [material]
        
        print("👻 Wand opacity set to: \(opacity)")
    }
    
    /// Setup button input handlers
    private func setupButtonInputs(device: GCDevice, hapticsModel: HapticsModel) {
        if let stylus = device as? GCStylus {
            setupStylusInputs(stylus: stylus, hapticsModel: hapticsModel)
        } else if let controller = device as? GCController {
            setupControllerInputs(controller: controller, hapticsModel: hapticsModel)
        }
    }
    
    /// Setup stylus button inputs
    private func setupStylusInputs(stylus: GCStylus, hapticsModel: HapticsModel) {
        guard let input = stylus.input else { return }
        
        // Primary button (upper side button) - Cycle wand color
        input.buttons[.stylusPrimaryButton]?.pressedInput.pressedDidChangeHandler = { [weak self] _, _, pressed in
            Task { @MainActor in
                if pressed {
                    self?.cycleWandColor()
                }
            }
        }
        
        // Secondary button (lower side button) - Toggle wand extension
        input.buttons[.stylusSecondaryButton]?.pressedInput.pressedDidChangeHandler = { [weak self] _, _, pressed in
            Task { @MainActor in
                if pressed {
                    hapticsModel.triggerImpact()
                    self?.toggleWandExtension()
                }
            }
        }
    }
    
    /// Setup controller button inputs
    private func setupControllerInputs(controller: GCController, hapticsModel: HapticsModel) {
        let input = controller.input
        
        // Trigger button - Toggle wand extension
        input.buttons[.trigger]?.pressedInput.pressedDidChangeHandler = { [weak self] _, _, pressed in
            Task { @MainActor in
                if pressed {
                    hapticsModel.triggerImpact()
                    self?.toggleWandExtension()
                }
            }
        }
        
        // Thumbstick button
        input.buttons[.thumbstickButton]?.pressedInput.pressedDidChangeHandler = { [weak self] _, _, pressed in
            Task { @MainActor in
                if pressed {
                    self?.toggleDebug()
                }
            }
        }
    }
    
    /// Update debug logging and motion detection
    func update() {
        // Log debug positions if enabled
        if isDebugEnabled {
            logDebugPositions()
        }
        
        // Check motion for haptic feedback
        if motionHapticsEnabled && isWandExtended {
            checkMotionForHaptics()
        }
    }
    
    /// Check motion based on position changes and trigger haptics
    private func checkMotionForHaptics() {
        // Get current position from wand anchor
        guard let anchor = wandAnchorEntity else {
            if isDebugEnabled {
                print("⚠️ No wand anchor")
            }
            return
        }
        
        let currentTime = CACurrentMediaTime()
        let currentPosition = anchor.position(relativeTo: nil)
        
        // Calculate velocity if we have a previous position
        if let lastPos = lastPosition {
            let deltaTime = Float(currentTime - lastUpdateTime)
            
            // Skip if deltaTime is too small to avoid division issues
            guard deltaTime > 0.001 else { return }
            
            // Calculate velocity vector
            let deltaPosition = currentPosition - lastPos
            let velocity = deltaPosition / deltaTime
            
            // Calculate velocity magnitude
            let velocityMagnitude = length(velocity)
            
            // Log velocity in debug mode when position logging is enabled
            if isDebugEnabled && isPositionLoggingEnabled {
                print("📊 Velocity: \(String(format: "%.2f", velocityMagnitude)) m/s, delta: (\(String(format: "%.3f", deltaPosition.x)), \(String(format: "%.3f", deltaPosition.y)), \(String(format: "%.3f", deltaPosition.z)))")
            }
            
            // Trigger haptics if velocity exceeds threshold
            if velocityMagnitude > velocityThreshold {
                if isPositionLoggingEnabled {
                    print("⚡️ Motion detected - velocity: \(String(format: "%.2f", velocityMagnitude)) m/s")
                }
                
                // Trigger light haptic feedback for swing
                hapticsModel?.triggerLightSwing()
            }
        }
        
        // Update last position and time
        lastPosition = currentPosition
        lastUpdateTime = currentTime
    }
}
