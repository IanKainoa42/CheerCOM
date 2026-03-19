import SceneKit
import Foundation
import QuartzCore

class CoMValidationHarness {

    // MARK: - Validation Config

    // Poses to validate
    private let posesToValidate: [PoseType] = [
        .tPose,
        .highV,
        .touchdown,
        .squat,
        .pike,
        .layout,
        .sideLean,
        .bowAndArrow,
        .lunge
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
        log("📅 \(Date())")
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
            refreshTransforms(for: sceneManager.characterNode)
            let result = calculator.calculateDetailedBodyCOM()
            visualizationsManager.updateCOM(result: result)

            completion?()
            return
        }

        // Ensure deterministic start state by resetting to T-Pose first
        if index > 0 { // Skip for first one as it might be T-Pose or we want to see transition from T-Pose
             applyPose(.tPose, sceneManager: sceneManager)
             // Force update
             refreshTransforms(for: sceneManager.characterNode)
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
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .medium
        log("Run Date: \(dateFormatter.string(from: Date()))")
        log("--- System Info ---")
        log("Total Body Mass (Configured): \(calculator.bodyMass) kg")
        log("Number of Segments Defined: \(calculator.segments.count)")

        // 1. Verify Mass Ratios & Total Mass
        let totalMassRatio = calculator.segments.reduce(0.0) { $0 + $1.mass }
        log("Total Mass Ratio Sum: \(String(format: "%.4f", totalMassRatio))")

        if abs(totalMassRatio - 1.0) > 0.001 {
             log("⚠️ CRITICAL: Mass ratios do not sum to 1.0! (Diff: \(String(format: "%.4f", totalMassRatio - 1.0)))")
        } else {
             log("✅ Mass ratios sum to approx 1.0")
        }

        // Verify Total Mass Calculation
        let calculatedTotalMass = calculator.calculateDetailedBodyCOM().segmentCOMs.reduce(0.0) { $0 + $1.mass }
        log("Calculated Total Mass: \(String(format: "%.3f", calculatedTotalMass)) kg (Expected: \(String(format: "%.3f", calculator.bodyMass)) kg)")

        if abs(calculatedTotalMass - calculator.bodyMass) > 0.01 {
            log("⚠️ CRITICAL: Calculated total mass does not match body mass!")
        } else {
            log("✅ Calculated mass matches body mass.")
        }

        // 2. Verify Segment Binding
        let result = calculator.calculateDetailedBodyCOM()
        let boundCount = result.segmentCOMs.count
        log("Number of Segments Bound: \(boundCount)")

        log("\nSegment Mapping Verification:")
        for segment in calculator.segments {
            let proxName = segment.prox
            let distName = segment.dist
            log(" - \(segment.name): \(proxName) -> \(distName)")
        }
        log("")

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

        // 4. Log Joint Limits configuration
        log("\n--- Joint Limits Enforced ---")
        log("Configured Joints: \(JointLimits.limits.keys.count)")
        for (joint, _) in JointLimits.limits {
            log(" - \(joint)")
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
        // Use duration 0.0 to ensure model is updated immediately before calculation
        applyPose(poseType, sceneManager: sceneManager, duration: 0.0)

        // Force Scene Update
        refreshTransforms(for: sceneManager.characterNode)

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
                return (false, "Center X deviation: \(String(format: "%.2f", com.x))")
            }

            // Check Height (Should be above hips)
            guard let hipsPos = hipsPos else {
                return (false, "Critical: Hips bone reference not found")
            }

            // Note: If Trunk is defined only as Hips->Spine, this might fail or be very close.
            if com.y > hipsPos.y {
                return (true, "Symmetric & CoM above hips (+100% Pass)")
            } else {
                return (false, "CoM is below hips! (Diff: \(String(format: "%.1f", com.y - hipsPos.y)))")
            }
        }

        guard let baseline = tPoseBaseline else {
            return (false, "Missing T-Pose baseline")
        }

        switch poseType {
        case .highV:
            // Y should be higher than T-Pose, but typically less than Touchdown
            let diff = com.y - baseline.y
            if diff > 1.0 {
                return (true, "CoM rose by \(String(format: "%.1f", diff)) units (Expected > 1.0)")
            }
            return (false, "CoM failed to rise significantly (Diff: \(String(format: "%.1f", diff)), Expected > 1.0)")

        case .touchdown:
            // Y should be significantly higher than T-Pose
            let diff = com.y - baseline.y
            if diff > 5.0 {
                return (true, "CoM rose by \(String(format: "%.1f", diff)) units (Expected > 5.0)")
            }
            return (false, "CoM failed to rise significantly (Diff: \(String(format: "%.1f", diff)), Expected > 5.0)")

        case .squat:
            // Y should be significantly lower than T-Pose
            let diff = baseline.y - com.y
            if diff > 10.0 {
                return (true, "CoM lowered by \(String(format: "%.1f", diff)) units (Expected > 10.0)")
            }
            return (false, "CoM failed to lower significantly (Diff: \(String(format: "%.1f", diff)), Expected > 10.0)")

        case .pike:
            // Pike (legs forward) -> CoM moves forward (Z changes).
            // Since coordinate system direction depends on camera, we verify significant Z-axis shift.
            // Typically legs move into +Z or -Z depending on facing.
            let diff = abs(com.z - baseline.z)
            if diff > 5.0 {
                return (true, "CoM Z-shift detected: \(String(format: "%.1f", diff)) units (Expected > 5.0)")
            }
            return (false, "CoM Z-axis did not shift significantly (Diff: \(String(format: "%.1f", diff)), Expected > 5.0)")

        case .layout:
            // Layout is straight body, similar to T-Pose but arms up?
            // "Fully extended straight body position" - arms up.
            // Should be higher than T-Pose, similar to Touchdown
            let diff = com.y - baseline.y
            if diff > 2.0 {
                return (true, "CoM higher than T-Pose by \(String(format: "%.1f", diff)) units (Expected > 2.0)")
            }
            return (false, "CoM not higher than T-Pose (Diff: \(String(format: "%.1f", diff)), Expected > 2.0)")

        case .sideLean:
            // Side lean -> CoM should shift in X
            let diff = abs(com.x - baseline.x)
            if diff > 2.0 {
                return (true, "CoM shifted laterally by \(String(format: "%.1f", diff)) units (Expected > 2.0)")
            }
            return (false, "CoM did not shift laterally significantly (Diff: \(String(format: "%.1f", diff)), Expected > 2.0)")

        case .bowAndArrow:
            // Bow and arrow is asymmetric -> CoM should shift in X away from baseline
            // Since right arm is straight (-X direction usually) and left arm is pulled back,
            // we should see a noticeable X shift.
            let diff = abs(com.x - baseline.x)
            if diff > 1.0 {
                return (true, "CoM shifted laterally by \(String(format: "%.1f", diff)) units due to asymmetric arm pose (Expected > 1.0)")
            }
            return (false, "CoM did not shift laterally significantly for asymmetric arm pose (Diff: \(String(format: "%.1f", diff)), Expected > 1.0)")

        case .lunge:
            // Lunge has one leg forward (-Z usually) and one back (+Z), hips lower
            let drop = baseline.y - com.y
            if drop > 5.0 {
                return (true, "CoM lowered by \(String(format: "%.1f", drop)) units due to lunge stance (Expected > 5.0)")
            }
            return (false, "CoM did not lower significantly in lunge stance (Drop: \(String(format: "%.1f", drop)), Expected > 5.0)")

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
                bone.eulerAngles = JointLimits.clampAngles(for: jointName, angles: angles)
            }
        }

        SCNTransaction.commit()
    }

    private func refreshTransforms(for rootNode: SCNNode) {
        CATransaction.flush()
        _ = rootNode.presentation.worldTransform
        _ = rootNode.worldTransform

        rootNode.enumerateChildNodes { node, _ in
            _ = node.presentation.worldTransform
            _ = node.worldTransform
        }
    }

    private func logDetailedSegments(result: CalculationResult) {
        log("\n### Segment Details")

        func pad(_ s: String, _ len: Int) -> String {
            return s.padding(toLength: len, withPad: " ", startingAt: 0)
        }

        log("| " + pad("Segment Name", 20) + " | " + pad("Mass (kg)", 10) + " | " + pad("CoM Position", 25) + " |")
        log("|" + String(repeating: "-", count: 22) + "|" + String(repeating: "-", count: 12) + "|" + String(repeating: "-", count: 27) + "|")

        for segment in result.segmentCOMs {
            let massString = String(format: "%.3f", segment.mass)
            let posString = formatVector(segment.position)
            log("| " + pad(segment.name, 20) + " | " + pad(massString, 10) + " | " + pad(posString, 25) + " |")
        }
        log("")
    }

    private func logValidationSummary() {
        log("### Validation Summary")

        func pad(_ s: String, _ len: Int) -> String {
            return s.padding(toLength: len, withPad: " ", startingAt: 0)
        }

        log("| " + pad("Pose", 15) + " | " + pad("Final CoM", 25) + " | " + pad("Result", 6) + " | " + pad("Note", 40) + " |")
        log("|" + String(repeating: "-", count: 17) + "|" + String(repeating: "-", count: 27) + "|" + String(repeating: "-", count: 8) + "|" + String(repeating: "-", count: 42) + "|")

        for res in validationResults {
            let icon = res.passed ? "✅" : "❌"
            let comString = formatVector(res.com)
            log("| " + pad(res.pose, 15) + " | " + pad(comString, 25) + " | " + pad(icon, 6) + " | " + pad(res.message, 40) + " |")
        }
        log("")
    }

    private func formatVector(_ v: SCNVector3) -> String {
        return String(format: "(%.2f, %.2f, %.2f)", v.x, v.y, v.z)
    }
}
