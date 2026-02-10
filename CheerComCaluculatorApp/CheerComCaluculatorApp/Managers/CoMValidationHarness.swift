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
        logSystemInfo(calculator: calculator, sceneManager: sceneManager)

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

    private func logSystemInfo(calculator: COMCalculator, sceneManager: CheerCOMSceneManager) {
        log("--- System Info ---")
        log("Total Body Mass: \(calculator.bodyMass) kg")
        log("Number of Segments Defined: \(calculator.segments.count)")

        // 1. Verify Mass Ratios
        let totalMassRatio = calculator.segments.reduce(0.0) { $0 + $1.mass }
        log("Total Mass Ratio Sum: \(String(format: "%.4f", totalMassRatio))")

        if abs(totalMassRatio - 1.0) > 0.001 {
             log("⚠️ CRITICAL: Mass ratios do not sum to 1.0! (Diff: \(String(format: "%.4f", totalMassRatio - 1.0)))")
        } else {
             log("✅ Mass ratios sum to approx 1.0")
        }

        // 2. Verify Segment Binding
        let result = calculator.calculateDetailedBodyCOM()
        let boundCount = result.segmentCOMs.count
        log("Number of Segments Bound: \(boundCount)")

        if boundCount < calculator.segments.count {
            log("⚠️ CRITICAL: Only \(boundCount)/\(calculator.segments.count) segments are bound! Some segments are missing from the calculation.")
            // Identify missing segments
            let boundNames = Set(result.segmentCOMs.map { $0.name })
            for segment in calculator.segments {
                if !boundNames.contains(segment.name) {
                    log("   ❌ Missing: \(segment.name) (Joints: \(segment.prox) -> \(segment.dist))")
                }
            }
        } else {
            log("✅ All segments successfully bound to joints.")
        }

        // 3. Verify BOS Nodes (Visualizations)
        let bosJoints = ["mixamorig_LeftFoot", "mixamorig_RightFoot", "mixamorig_LeftToeBase", "mixamorig_RightToeBase"]
        var missingBOS = false
        for joint in bosJoints {
            if sceneManager.findBone(named: joint) == nil {
                log("⚠️ WARNING: BOS Joint missing: \(joint)")
                missingBOS = true
            }
        }
        if !missingBOS {
             log("✅ All BOS joints found.")
        }

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

        // Get Hips Position for reference
        let hipsPos = sceneManager.findBone(named: "mixamorig_Hips")?.worldPosition

        // Verify Criteria
        let (passed, message) = verifyPoseCriteria(poseType, com: com, hipsPos: hipsPos)
        let statusIcon = passed ? "✅" : "❌"
        log("- **Validation**: \(statusIcon) \(message)")

        // Store for summary
        validationResults.append(ValidationOutcome(pose: poseType.displayName, com: com, passed: passed, message: message))

        // Log Segment Details for all poses to aid debugging
        logDetailedSegments(result: result)

        log("") // New line
    }

    private func verifyPoseCriteria(_ poseType: PoseType, com: SCNVector3, hipsPos: SCNVector3?) -> (Bool, String) {
        // T-Pose is baseline
        if poseType == .tPose {
            tPoseBaseline = com

            // Check symmetry (X should be close to 0)
            if abs(com.x) >= 2.0 {
                return (false, "Center X deviation: \(com.x)")
            }

            // Check Height (Should be above hips)
            guard let hipsPos = hipsPos else {
                return (false, "Critical: Hips bone reference not found")
            }

            // Note: If Trunk is defined only as Hips->Spine, this might fail or be very close.
            if com.y > hipsPos.y {
                return (true, "Symmetric & CoM above hips (Diff: \(String(format: "%.1f", com.y - hipsPos.y)))")
            } else {
                return (false, "CoM is below hips! (Diff: \(String(format: "%.1f", com.y - hipsPos.y)))")
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
