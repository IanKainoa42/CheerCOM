import SceneKit
import Foundation

class CoMValidationHarness {

    // MARK: - Validation Config

    // Poses to validate
    private let posesToValidate: [PoseType] = [
        .tPose,
        .highV,
        .prepPosition, // Full Body Squat
        .pike,
        .layout,
        .bridge
    ]

    // MARK: - Main Execution

    /// Runs a full validation suite, cycling through deterministic poses and printing CoM data.
    /// Runs asynchronously to allow visual verification.
    func runValidation(sceneManager: CheerCOMSceneManager,
                       calculator: COMCalculator,
                       visualizationsManager: VisualizationsManager,
                       completion: (() -> Void)? = nil) {

        print("\n==========================================")
        print("🧪 STARTING CoM VALIDATION HARNESS")
        print("==========================================\n")

        // 1. Log System Info
        logSystemInfo(calculator: calculator)

        // 2. Iterate Poses recursively
        runNextPose(index: 0,
                    sceneManager: sceneManager,
                    calculator: calculator,
                    visualizationsManager: visualizationsManager,
                    completion: completion)
    }

    private func runNextPose(index: Int,
                             sceneManager: CheerCOMSceneManager,
                             calculator: COMCalculator,
                             visualizationsManager: VisualizationsManager,
                             completion: (() -> Void)?) {

        // Check if done
        if index >= posesToValidate.count {
            print("\n==========================================")
            print("✅ CoM VALIDATION COMPLETE")
            print("==========================================\n")

            // Reset to T-Pose
            applyPose(.tPose, sceneManager: sceneManager)
            // Update visuals one last time
            sceneManager.characterNode.updateTransform()
            let com = calculator.calculateBodyCOM()
            visualizationsManager.updateCOM(position: com)

            completion?()
            return
        }

        // Ensure deterministic start state by resetting to T-Pose first
        if index > 0 { // Skip for first one as it might be T-Pose or we want to see transition from T-Pose
             applyPose(.tPose, sceneManager: sceneManager)
             // Force update
             sceneManager.characterNode.updateTransform()
        }

        let poseType = posesToValidate[index]
        validatePose(poseType, sceneManager: sceneManager, calculator: calculator, visualizationsManager: visualizationsManager)

        // Schedule next pose
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.runNextPose(index: index + 1,
                              sceneManager: sceneManager,
                              calculator: calculator,
                              visualizationsManager: visualizationsManager,
                              completion: completion)
        }
    }

    // MARK: - Helper Methods

    private func logSystemInfo(calculator: COMCalculator) {
        print("--- System Info ---")
        print("Total Body Mass: \(calculator.bodyMass) kg")
        print("Number of Segments: \(calculator.segments.count)")
        print("-------------------\n")
    }

    private func validatePose(_ poseType: PoseType,
                              sceneManager: CheerCOMSceneManager,
                              calculator: COMCalculator,
                              visualizationsManager: VisualizationsManager) {
        print("📍 Validating Pose: \(poseType.displayName)")

        // Apply Pose
        applyPose(poseType, sceneManager: sceneManager)

        // Force Scene Update
        sceneManager.characterNode.updateTransform()

        // Calculate CoM
        let result = calculator.calculateDetailedBodyCOM()
        let com = result.totalCOM

        // Update Visuals immediately
        visualizationsManager.updateCOM(position: com)

        // Log Results
        print("   -> Calculated CoM: \(formatVector(com))")

        // Log Segment Details for T-Pose to verify offsets
        if poseType == .tPose {
            logDetailedSegments(result: result)
        }

        print("") // New line
    }

    private func applyPose(_ poseType: PoseType, sceneManager: CheerCOMSceneManager) {
        let poseDef = PosePresets.shared.getPose(poseType)

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5 // Add some animation for visual clarity

        for (jointName, angles) in poseDef.jointAngles {
            if let bone = sceneManager.findBone(named: jointName) {
                bone.eulerAngles = angles
            }
        }

        SCNTransaction.commit()
    }

    private func logDetailedSegments(result: CalculationResult) {
        print("   --- Segment Details (T-Pose) ---")
        print("   Name                           | Mass (kg) | CoM Position")
        print("   -------------------------------|-----------|-------------------------")
        for segment in result.segmentCOMs {
            let namePadding = String(repeating: " ", count: max(0, 30 - segment.name.count))
            let massString = String(format: "%.3f", segment.mass)
            let massPadding = String(repeating: " ", count: max(0, 9 - massString.count))
            print("   \(segment.name)\(namePadding) | \(massString)\(massPadding) | \(formatVector(segment.position))")
        }
        print("   ---------------------------------------------------------------------")
    }

    private func formatVector(_ v: SCNVector3) -> String {
        return String(format: "[x: %.3f, y: %.3f, z: %.3f]", v.x, v.y, v.z)
    }
}
