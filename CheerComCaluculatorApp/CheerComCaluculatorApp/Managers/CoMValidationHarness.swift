import SceneKit
import Foundation

class CoMValidationHarness {

    // MARK: - Validation Config

    // Poses to validate
    private let posesToValidate: [PoseType] = [
        .tPose,
        .touchdown,
        .squat,
        .pike,
        .layout
    ]

    private struct ValidationOutcome {
        let pose: String
        let com: SCNVector3
        let passed: Bool
        let message: String
    }

    private var validationResults: [ValidationOutcome] = []
    private var tPoseBaseline: SCNVector3?
    private var logger: ((String) -> Void)?

    // MARK: - Main Execution

    /// Runs a full validation suite, cycling through deterministic poses and printing CoM data.
    /// Runs asynchronously to allow visual verification.
    func runValidation(sceneManager: CheerCOMSceneManager,
                       calculator: COMCalculator,
                       visualizationsManager: VisualizationsManager,
                       logger: ((String) -> Void)? = nil,
                       completion: (() -> Void)? = nil) {

        self.logger = logger

        log("\n==========================================")
        log("🧪 STARTING CoM VALIDATION HARNESS")
        log("==========================================\n")

        validationResults.removeAll()
        tPoseBaseline = nil

        // Ensure advanced visualizations are enabled to show segments
        visualizationsManager.showAdvancedVisualizations = true

        // 1. Log System Info
        logSystemInfo(calculator: calculator)

        // 2. Iterate Poses recursively
        runNextPose(index: 0,
                    sceneManager: sceneManager,
                    calculator: calculator,
                    visualizationsManager: visualizationsManager,
                    completion: completion)
    }

    private func log(_ message: String) {
        print(message)
        logger?(message)
    }

    private func runNextPose(index: Int,
                             sceneManager: CheerCOMSceneManager,
                             calculator: COMCalculator,
                             visualizationsManager: VisualizationsManager,
                             completion: (() -> Void)?) {

        // Check if done
        if index >= posesToValidate.count {
            log("\n==========================================")
            log("✅ CoM VALIDATION COMPLETE")
            log("==========================================\n")

            logValidationSummary()

            // Reset to T-Pose
            applyPose(.tPose, sceneManager: sceneManager)
            // Update visuals one last time
            sceneManager.characterNode.updateTransform()
            let result = calculator.calculateDetailedBodyCOM()
            visualizationsManager.updateCOM(result: result)

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
        log("--- System Info ---")
        log("Total Body Mass: \(calculator.bodyMass) kg")
        log("Number of Segments: \(calculator.segments.count)")
        log("-------------------\n")
    }

    private func validatePose(_ poseType: PoseType,
                              sceneManager: CheerCOMSceneManager,
                              calculator: COMCalculator,
                              visualizationsManager: VisualizationsManager) {
        log("\n## Validating Pose: \(poseType.displayName)")

        // Reset to T-Pose first (instant) to ensure deterministic start state
        // This clears any modifications from previous poses (e.g. spine bends)
        applyPose(.tPose, sceneManager: sceneManager, duration: 0.0)

        // Apply Pose
        applyPose(poseType, sceneManager: sceneManager)

        // Force Scene Update
        sceneManager.characterNode.updateTransform()

        // Calculate CoM
        let result = calculator.calculateDetailedBodyCOM()
        let com = result.totalCOM

        // Update Visuals immediately
        visualizationsManager.updateCOM(result: result)

        // Log Results
        log("- **Calculated CoM**: `\(formatVector(com))`")

        // Verify Criteria
        let (passed, message) = verifyPoseCriteria(poseType, com: com)
        let statusIcon = passed ? "✅" : "❌"
        log("- **Validation**: \(statusIcon) \(message)")

        // Store for summary
        validationResults.append(ValidationOutcome(pose: poseType.displayName, com: com, passed: passed, message: message))

        // Log Segment Details for all poses to aid debugging
        logDetailedSegments(result: result)

        log("") // New line
    }

    private func verifyPoseCriteria(_ poseType: PoseType, com: SCNVector3) -> (Bool, String) {
        // T-Pose is baseline
        if poseType == .tPose {
            tPoseBaseline = com
            // Check symmetry (X should be close to 0)
            if abs(com.x) < 2.0 {
                return (true, "Center X is symmetric (< 2.0)")
            } else {
                return (false, "Center X deviation: \(com.x)")
            }
        }

        guard let baseline = tPoseBaseline else {
            return (false, "Missing T-Pose baseline")
        }

        switch poseType {
        case .touchdown:
            // Y should be significantly higher than T-Pose
            let diff = com.y - baseline.y
            if diff > 5.0 {
                return (true, "CoM rose by \(String(format: "%.1f", diff)) units")
            }
            return (false, "CoM failed to rise significantly (diff: \(diff))")

        case .squat:
            // Y should be significantly lower than T-Pose
            let diff = baseline.y - com.y
            if diff > 10.0 {
                return (true, "CoM lowered by \(String(format: "%.1f", diff)) units")
            }
            return (false, "CoM failed to lower significantly (diff: \(diff))")

        case .pike:
            // Z should move forward (assuming negative Z is forward in this scene, or check diff magnitude)
            // Pike (legs forward) -> CoM moves forward (Z changes)
            // Check absolute change in Z
            let diff = abs(com.z - baseline.z)
            if diff > 5.0 {
                return (true, "CoM Z-shift detected (\(String(format: "%.1f", diff)) units)")
            }
            return (false, "CoM Z-axis did not shift significantly")

        case .layout:
            // Layout is straight body, similar to T-Pose but arms up?
            // "Fully extended straight body position" - arms up.
            // Should be higher than T-Pose, similar to Touchdown
            if com.y > baseline.y + 2.0 {
                return (true, "CoM higher than T-Pose")
            }
            return (false, "CoM not higher than T-Pose")

        default:
            return (true, "No specific criteria")
        }
    }

    private func applyPose(_ poseType: PoseType, sceneManager: CheerCOMSceneManager, duration: TimeInterval = 0.5) {
        let poseDef = PosePresets.shared.getPose(poseType)

        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration

        for (jointName, angles) in poseDef.jointAngles {
            if let bone = sceneManager.findBone(named: jointName) {
                bone.eulerAngles = angles
            }
        }

        SCNTransaction.commit()
    }

    private func logDetailedSegments(result: CalculationResult) {
        log("\n### Segment Details")
        log("| Segment Name | Mass (kg) | CoM Position (x, y, z) |")
        log("| :--- | :---: | :--- |")
        for segment in result.segmentCOMs {
            let massString = String(format: "%.3f", segment.mass)
            log("| \(segment.name) | \(massString) | \(formatVector(segment.position)) |")
        }
        log("")
    }

    private func logValidationSummary() {
        log("### Validation Summary")
        log("| Pose | Final CoM (x, y, z) | Result | Note |")
        log("| :--- | :--- | :---: | :--- |")
        for res in validationResults {
            let icon = res.passed ? "✅" : "❌"
            log("| \(res.pose) | \(formatVector(res.com)) | \(icon) | \(res.message) |")
        }
        log("")
    }

    private func formatVector(_ v: SCNVector3) -> String {
        return String(format: "(%.2f, %.2f, %.2f)", v.x, v.y, v.z)
    }
}
