import SceneKit
import UIKit

class CoMValidationHarness {
    private weak var sceneManager: CheerCOMSceneManager?
    private weak var calculator: COMCalculator?

    init(sceneManager: CheerCOMSceneManager, calculator: COMCalculator) {
        self.sceneManager = sceneManager
        self.calculator = calculator
    }

    func runValidation() {
        print("\n🔎 === Starting CoM Validation Harness ===")

        guard let sceneManager = sceneManager, let calculator = calculator else {
            print("❌ Validation failed: Missing scene manager or calculator")
            return
        }

        let testPoses: [PoseType] = [.tPose, .highV, .liberty, .bridge]

        for poseType in testPoses {
            print("\n🧪 Testing Pose: \(poseType.displayName)")

            // 1. Apply Pose
            let poseDefinition = PosePresets.shared.getPose(poseType)

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0

            for (jointName, angles) in poseDefinition.jointAngles {
                if let bone = sceneManager.findBone(named: jointName) {
                    bone.eulerAngles = angles
                }
            }

            SCNTransaction.commit()

            // Force SceneKit to update transforms (if needed, sometimes checking worldPosition forces update)
            // In a real run loop this happens automatically, but here we might need to rely on the fact that accessing worldPosition triggers an update of the node hierarchy if dirty.

            // 2. Gather Positions
            var jointPositions: [String: SCNVector3] = [:]
            for (name, node) in sceneManager.cachedBoneNodes {
                jointPositions[name] = node.worldPosition
            }

            // 3. Calculate CoM
            let result = calculator.calculateBodyCOM(jointPositions: jointPositions)

            // 4. Output Results
            print("   📍 Total CoM: \(formatVector(result.totalCOM))")
            print("   📊 Segment CoMs:")
            for segment in result.segmentCOMs {
                print("      - \(segment.name.padding(toLength: 15, withPad: " ", startingAt: 0)): \(formatVector(segment.position)) (Mass: \(String(format: "%.2f", segment.mass)) kg)")
            }
        }

        print("\n✅ Validation Complete\n")

        // Restore T-Pose
        let tPose = PosePresets.shared.getPose(.tPose)
        for (jointName, angles) in tPose.jointAngles {
            if let bone = sceneManager.findBone(named: jointName) {
                bone.eulerAngles = angles
            }
        }
    }

    private func formatVector(_ v: SCNVector3) -> String {
        return String(format: "(x: %.2f, y: %.2f, z: %.2f)", v.x, v.y, v.z)
    }
}
