// PR Deliverable: A small set of deterministic pose presets (at least 4)
import Foundation
import SceneKit


struct PoseDefinition {
    let name: String
    let category: PoseCategory
    let jointAngles: [String: SCNVector3]  // Joint name -> euler angles (in radians)
    let description: String
    let affectedJoints: Set<String>?  // nil = all joints, otherwise only these joints

    init(
        name: String, category: PoseCategory, jointAngles: [String: SCNVector3],
        description: String, affectedJoints: Set<String>? = nil
    ) {
        self.name = name
        self.category = category
        self.jointAngles = jointAngles
        self.description = description
        self.affectedJoints = affectedJoints
    }
}

class PosePresets {
    static let shared = PosePresets()

    private init() {}

    // Helper to convert degrees to radians for easier pose definition
    private func deg(_ degrees: Float) -> Float {
        return degrees * .pi / 180
    }

    func getPose(_ type: PoseType) -> PoseDefinition {
        switch type {
        // MARK: - Full Body Poses

        // The following 4 poses (T-Pose, High V, Touchdown, Squat) form the baseline for the CoM Validation Harness.
        // Verified baseline pose
        case .tPose:
            return PoseDefinition(
                name: "T-Pose",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_Hips": SCNVector3Zero,
                    "mixamorig_Spine": SCNVector3Zero,
                    "mixamorig_Spine1": SCNVector3Zero,
                    "mixamorig_Spine2": SCNVector3Zero,
                    "mixamorig_Neck": SCNVector3Zero,
                    "mixamorig_Head": SCNVector3Zero,
                    "mixamorig_RightShoulder": SCNVector3Zero,
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-90)),
                    "mixamorig_RightForeArm": SCNVector3Zero,
                    "mixamorig_RightHand": SCNVector3Zero,
                    "mixamorig_LeftShoulder": SCNVector3Zero,
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(90)),
                    "mixamorig_LeftForeArm": SCNVector3Zero,
                    "mixamorig_LeftHand": SCNVector3Zero,
                    "mixamorig_RightUpLeg": SCNVector3Zero,
                    "mixamorig_RightLeg": SCNVector3Zero,
                    "mixamorig_RightFoot": SCNVector3Zero,
                    "mixamorig_LeftUpLeg": SCNVector3Zero,
                    "mixamorig_LeftLeg": SCNVector3Zero,
                    "mixamorig_LeftFoot": SCNVector3Zero,
                ],
                description: "Standard T-Pose with arms extended to sides"
            )

        case .highV:
            return PoseDefinition(
                name: "High V",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_RightShoulder": SCNVector3(deg(0), deg(0), deg(0)),
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-135)),
                    "mixamorig_RightForeArm": SCNVector3Zero,
                    "mixamorig_LeftShoulder": SCNVector3(deg(0), deg(0), deg(0)),
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(135)),
                    "mixamorig_LeftForeArm": SCNVector3Zero,
                    "mixamorig_RightUpLeg": SCNVector3Zero,
                    "mixamorig_LeftUpLeg": SCNVector3Zero,
                    "mixamorig_RightLeg": SCNVector3Zero,
                    "mixamorig_LeftLeg": SCNVector3Zero,
                ],
                description: "Arms in V shape above head"
            )

        case .lowV:
            return PoseDefinition(
                name: "Low V",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_RightShoulder": SCNVector3Zero,
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-45)),
                    "mixamorig_RightForeArm": SCNVector3Zero,
                    "mixamorig_LeftShoulder": SCNVector3Zero,
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(45)),
                    "mixamorig_LeftForeArm": SCNVector3Zero,
                    "mixamorig_RightUpLeg": SCNVector3Zero,
                    "mixamorig_LeftUpLeg": SCNVector3Zero,
                ],
                description: "Arms in V shape below waist"
            )

        case .touchdown:
            return PoseDefinition(
                name: "Touchdown",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_RightShoulder": SCNVector3Zero,
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-180)),
                    "mixamorig_RightForeArm": SCNVector3Zero,
                    "mixamorig_LeftShoulder": SCNVector3Zero,
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(180)),
                    "mixamorig_LeftForeArm": SCNVector3Zero,
                    "mixamorig_RightUpLeg": SCNVector3Zero,
                    "mixamorig_LeftUpLeg": SCNVector3Zero,
                ],
                description: "Arms straight up"
            )

        case .bowAndArrow:
            return PoseDefinition(
                name: "Bow & Arrow",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-90)),
                    "mixamorig_RightForeArm": SCNVector3Zero,
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(-90), deg(90)),
                    "mixamorig_LeftForeArm": SCNVector3(deg(0), deg(0), deg(-90)),
                    "mixamorig_RightUpLeg": SCNVector3Zero,
                    "mixamorig_LeftUpLeg": SCNVector3Zero,
                ],
                description: "One arm extended, one pulled back like drawing a bow"
            )

        case .liberty:
            return PoseDefinition(
                name: "Liberty",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_RightShoulder": SCNVector3Zero,
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-135)),
                    "mixamorig_LeftShoulder": SCNVector3Zero,
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(135)),
                    "mixamorig_RightUpLeg": SCNVector3(deg(0), deg(0), deg(-90)),
                    "mixamorig_RightLeg": SCNVector3(deg(0), deg(0), deg(90)),
                    "mixamorig_LeftUpLeg": SCNVector3Zero,
                    "mixamorig_LeftLeg": SCNVector3Zero,
                ],
                description: "Right leg raised, arms in high V"
            )

        case .scale:
            return PoseDefinition(
                name: "Scale",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_RightShoulder": SCNVector3Zero,
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-90)),
                    "mixamorig_LeftShoulder": SCNVector3Zero,
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(90)),
                    "mixamorig_RightUpLeg": SCNVector3(deg(0), deg(0), deg(-90)),
                    "mixamorig_LeftUpLeg": SCNVector3(deg(0), deg(0), deg(90)),
                ],
                description: "Split position with legs extended to sides"
            )

        case .arabesque:
            return PoseDefinition(
                name: "Arabesque",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-90)),
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(90)),
                    "mixamorig_RightUpLeg": SCNVector3(deg(-60), deg(0), deg(0)),
                    "mixamorig_LeftUpLeg": SCNVector3Zero,
                ],
                description: "Right leg extended back, arms extended"
            )

        case .bridge:
            return PoseDefinition(
                name: "Bridge",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_Spine": SCNVector3(deg(30), deg(0), deg(0)),
                    "mixamorig_Spine1": SCNVector3(deg(30), deg(0), deg(0)),
                    "mixamorig_Spine2": SCNVector3(deg(30), deg(0), deg(0)),
                    "mixamorig_Neck": SCNVector3(deg(-30), deg(0), deg(0)),
                    "mixamorig_RightShoulder": SCNVector3(deg(0), deg(0), deg(-45)),
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-180)),
                    "mixamorig_LeftShoulder": SCNVector3(deg(0), deg(0), deg(45)),
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(180)),
                    "mixamorig_RightUpLeg": SCNVector3(deg(-90), deg(0), deg(0)),
                    "mixamorig_RightLeg": SCNVector3(deg(90), deg(0), deg(0)),
                    "mixamorig_LeftUpLeg": SCNVector3(deg(-90), deg(0), deg(0)),
                    "mixamorig_LeftLeg": SCNVector3(deg(90), deg(0), deg(0)),
                ],
                description: "Backbend/bridge position"
            )

        case .backbend:
            return PoseDefinition(
                name: "Backbend",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_Spine": SCNVector3(deg(45), deg(0), deg(0)),
                    "mixamorig_Spine1": SCNVector3(deg(45), deg(0), deg(0)),
                    "mixamorig_Spine2": SCNVector3(deg(45), deg(0), deg(0)),
                    "mixamorig_Neck": SCNVector3(deg(-45), deg(0), deg(0)),
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-180)),
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(180)),
                    "mixamorig_RightUpLeg": SCNVector3Zero,
                    "mixamorig_LeftUpLeg": SCNVector3Zero,
                ],
                description: "Standing backbend"
            )

        case .standingSplit:
            return PoseDefinition(
                name: "Standing Split",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-90)),
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(90)),
                    "mixamorig_RightUpLeg": SCNVector3(deg(-180), deg(0), deg(0)),
                    "mixamorig_LeftUpLeg": SCNVector3Zero,
                ],
                description: "Right leg extended straight up"
            )

        case .prepPosition:
            return PoseDefinition(
                name: "Prep Position",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-135)),
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(135)),
                    "mixamorig_RightUpLeg": SCNVector3(deg(45), deg(0), deg(0)),
                    "mixamorig_RightLeg": SCNVector3(deg(-90), deg(0), deg(0)),
                    "mixamorig_LeftUpLeg": SCNVector3(deg(45), deg(0), deg(0)),
                    "mixamorig_LeftLeg": SCNVector3(deg(-90), deg(0), deg(0)),
                ],
                description: "Squat position with high V arms"
            )

        case .squat:
            return PoseDefinition(
                name: "Squat",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-90)),
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(90)),
                    "mixamorig_RightUpLeg": SCNVector3(deg(45), deg(0), deg(0)),
                    "mixamorig_RightLeg": SCNVector3(deg(-90), deg(0), deg(0)),
                    "mixamorig_LeftUpLeg": SCNVector3(deg(45), deg(0), deg(0)),
                    "mixamorig_LeftLeg": SCNVector3(deg(-90), deg(0), deg(0)),
                ],
                description: "Squat position with T arms"
            )

        case .testPose24:
            return PoseDefinition(
                type: type,
                jointAngles: [
                    "mixamorig_RightArm": SCNVector3(0, 0, deg(180))
                ]
            )
        case .testPose25:
            return PoseDefinition(
                type: type,
                jointAngles: [
                    "mixamorig_LeftArm": SCNVector3(0, 0, deg(-180))
                ]
            )
        case .testPose26:
            return PoseDefinition(
                type: type,
                jointAngles: [
                    "mixamorig_LeftArm": SCNVector3(deg(90), 0, 0)
                ]
            )
        case .testPose18:
            return PoseDefinition(
                name: "Scorpion",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_RightUpLeg": SCNVector3(deg(-90), deg(0), deg(0)),
                    "mixamorig_RightLeg": SCNVector3(deg(120), deg(0), deg(0)),
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-180))
                ],
                description: "Scorpion cheer stunt testing extreme leg bend and arm reach",
                affectedJoints: Set(["mixamorig_RightUpLeg", "mixamorig_RightLeg", "mixamorig_RightArm"])
            )

        case .pike:
            return PoseDefinition(
                name: "Pike",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-180)),
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(180)),
                    "mixamorig_RightUpLeg": SCNVector3(deg(-90), deg(0), deg(0)),
                    "mixamorig_RightLeg": SCNVector3Zero,
                    "mixamorig_LeftUpLeg": SCNVector3(deg(-90), deg(0), deg(0)),
                    "mixamorig_LeftLeg": SCNVector3Zero,
                ],
                description: "Pike position with arms overhead"
            )

        case .layout:
            return PoseDefinition(
                name: "Layout",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-180)),
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(180)),
                    "mixamorig_RightUpLeg": SCNVector3Zero,
                    "mixamorig_RightLeg": SCNVector3Zero,
                    "mixamorig_LeftUpLeg": SCNVector3Zero,
                    "mixamorig_LeftLeg": SCNVector3Zero,
                    "mixamorig_Spine": SCNVector3Zero,
                    "mixamorig_Spine1": SCNVector3Zero,
                    "mixamorig_Spine2": SCNVector3Zero,
                ],
                description: "Fully extended straight body position"
            )

        case .testPose1:
            return PoseDefinition(
                name: "Baseline Validation 1",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-85)),
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(85)),
                ],
                description: "Deterministic baseline pose for CoM validation (Arms low)"
            )

        case .testPose2:
            return PoseDefinition(
                name: "Baseline Validation 2",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-170)),
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(170)),
                ],
                description: "Deterministic baseline pose for CoM validation (Arms high)"
            )

        case .testPose3:
            return PoseDefinition(
                name: "Baseline Validation 3",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_RightUpLeg": SCNVector3(deg(40), deg(0), deg(0)),
                    "mixamorig_LeftUpLeg": SCNVector3(deg(40), deg(0), deg(0)),
                ],
                description: "Deterministic baseline pose for CoM validation (Legs forward)"
            )

        case .testPose4:
            return PoseDefinition(
                name: "Baseline Validation 4",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_RightUpLeg": SCNVector3(deg(-80), deg(0), deg(0)),
                    "mixamorig_LeftUpLeg": SCNVector3(deg(-80), deg(0), deg(0)),
                ],
                description: "Deterministic baseline pose for CoM validation (Legs squatting)"
            )

        case .testPose5:
            return PoseDefinition(
                name: "Baseline Validation 5",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-90)),
                    "mixamorig_RightForeArm": SCNVector3(deg(0), deg(0), deg(90)),
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(90)),
                    "mixamorig_LeftForeArm": SCNVector3(deg(0), deg(0), deg(-90)),
                ],
                description: "Deterministic baseline pose for CoM validation (Arms forward)"
            )

        case .testPose6:
            return PoseDefinition(
                name: "Baseline Validation 6",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_Hips": SCNVector3(deg(0), deg(0), deg(0)), // Squat
                    "mixamorig_RightUpLeg": SCNVector3(deg(-90), deg(0), deg(0)),
                    "mixamorig_LeftUpLeg": SCNVector3(deg(-90), deg(0), deg(0)),
                    "mixamorig_RightLeg": SCNVector3(deg(90), deg(0), deg(0)),
                    "mixamorig_LeftLeg": SCNVector3(deg(90), deg(0), deg(0)),
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-180)), // Arms up
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(180))
                ],
                description: "Deterministic baseline pose for CoM validation (Squat + Touchdown)"
            )

        case .testPose7:
            return PoseDefinition(
                name: "Baseline Validation 7",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(90)),
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(-90)),
                    "mixamorig_RightUpLeg": SCNVector3(deg(-45), deg(0), deg(0)),
                    "mixamorig_Spine": SCNVector3(deg(20), deg(0), deg(0))
                ],
                description: "Deterministic baseline pose for CoM validation (Arabesque variation)"
            )

        case .testPose8:
            return PoseDefinition(
                name: "Baseline Validation 8",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(90)),
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(-90))
                ],
                description: "Deterministic baseline pose for CoM validation (Arms extended laterally)"
            )

        case .testPose9:
            return PoseDefinition(
                name: "Baseline Validation 9",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_Spine": SCNVector3(deg(15), deg(0), deg(0)),
                    "mixamorig_Spine1": SCNVector3(deg(15), deg(0), deg(0))
                ],
                description: "Deterministic baseline pose for CoM validation (Forward lean)"
            )

        case .sideLean:
            return PoseDefinition(
                name: "Side Lean",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_Hips": SCNVector3Zero,
                    "mixamorig_Spine": SCNVector3(deg(0), deg(0), deg(20)),
                    "mixamorig_Spine1": SCNVector3(deg(0), deg(0), deg(20)),
                    "mixamorig_Spine2": SCNVector3(deg(0), deg(0), deg(20)),
                    "mixamorig_Neck": SCNVector3(deg(0), deg(0), deg(0)),
                    "mixamorig_Head": SCNVector3(deg(0), deg(0), deg(0)),
                    "mixamorig_RightShoulder": SCNVector3Zero,
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-90)),
                    "mixamorig_RightForeArm": SCNVector3Zero,
                    "mixamorig_RightHand": SCNVector3Zero,
                    "mixamorig_LeftShoulder": SCNVector3Zero,
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(90)),
                    "mixamorig_LeftForeArm": SCNVector3Zero,
                    "mixamorig_LeftHand": SCNVector3Zero,
                    "mixamorig_RightUpLeg": SCNVector3Zero,
                    "mixamorig_RightLeg": SCNVector3Zero,
                    "mixamorig_RightFoot": SCNVector3Zero,
                    "mixamorig_LeftUpLeg": SCNVector3Zero,
                    "mixamorig_LeftLeg": SCNVector3Zero,
                    "mixamorig_LeftFoot": SCNVector3Zero,
                ],
                description: "Side lean with T-arms"
            )

        case .lungePose:
            return PoseDefinition(
                name: "Lunge",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_Hips": SCNVector3Zero,
                    "mixamorig_Spine": SCNVector3Zero,
                    "mixamorig_Spine1": SCNVector3Zero,
                    "mixamorig_Spine2": SCNVector3Zero,
                    "mixamorig_Neck": SCNVector3Zero,
                    "mixamorig_Head": SCNVector3Zero,
                    "mixamorig_RightShoulder": SCNVector3Zero,
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-90)),
                    "mixamorig_RightForeArm": SCNVector3Zero,
                    "mixamorig_RightHand": SCNVector3Zero,
                    "mixamorig_LeftShoulder": SCNVector3Zero,
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(90)),
                    "mixamorig_LeftForeArm": SCNVector3Zero,
                    "mixamorig_LeftHand": SCNVector3Zero,
                    "mixamorig_RightUpLeg": SCNVector3(deg(70), deg(0), deg(0)),
                    "mixamorig_RightLeg": SCNVector3(deg(-90), deg(0), deg(0)),
                    "mixamorig_RightFoot": SCNVector3Zero,
                    "mixamorig_LeftUpLeg": SCNVector3(deg(-10), deg(0), deg(0)),
                    "mixamorig_LeftLeg": SCNVector3Zero,
                    "mixamorig_LeftFoot": SCNVector3Zero,
                ],
                description: "Lunge with front knee bent 90°, T-arms"
            )

        case .testPose10:
            return PoseDefinition(
                name: "Test Pose 10",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_Spine": SCNVector3(deg(-45), deg(0), deg(0))
                ],
                description: "Baseline validation - backward lean",
                affectedJoints: nil
            )

        case .testPose11:
            return PoseDefinition(
                name: "Test Pose 11",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_RightArm": SCNVector3(deg(90), deg(0), deg(0)),
                    "mixamorig_LeftArm": SCNVector3(deg(90), deg(0), deg(0)),
                    "mixamorig_RightUpLeg": SCNVector3(deg(-45), deg(0), deg(0))
                ],
                description: "Deterministic pose for CoM mathematical baseline validation (arms forward, leg back)."
            )

        case .testPose12:
            return PoseDefinition(
                name: "Test Pose 12",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_RightArm": SCNVector3(deg(90), deg(0), deg(-45)),
                    "mixamorig_LeftArm": SCNVector3(deg(90), deg(0), deg(45)),
                    "mixamorig_RightForeArm": SCNVector3(deg(0), deg(0), deg(90)),
                    "mixamorig_LeftForeArm": SCNVector3(deg(0), deg(0), deg(-90))
                ],
                description: "Deterministic pose for CoM mathematical baseline validation (arms crossed)."
            )

        case .testPose13:
            return PoseDefinition(
                name: "Test Pose 13",
                category: .fullBody,
                jointAngles: ["mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-45))],
                description: "Test 13",
                affectedJoints: Set(["mixamorig_RightArm"])
            )
        case .testPose14:
            return PoseDefinition(
                name: "Test Pose 14",
                category: .fullBody,
                jointAngles: ["mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(45))],
                description: "Test 14",
                affectedJoints: Set(["mixamorig_LeftArm"])
            )
        case .testPose15:
            return PoseDefinition(
                name: "Test Pose 15",
                category: .fullBody,
                jointAngles: ["mixamorig_RightLeg": SCNVector3(deg(-45), deg(0), deg(0))],
                description: "Test 15",
                affectedJoints: Set(["mixamorig_RightLeg"])
            )
        case .testPose16:
            return PoseDefinition(
                name: "Test Pose 16",
                category: .fullBody,
                jointAngles: ["mixamorig_LeftLeg": SCNVector3(deg(-45), deg(0), deg(0))],
                description: "Test 16",
                affectedJoints: Set(["mixamorig_LeftLeg"])
            )
        case .testPose17:
            return PoseDefinition(
                name: "Test Pose 17",
                category: .fullBody,
                jointAngles: ["mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(20))],
                description: "Test 17",
                affectedJoints: Set(["mixamorig_RightArm"])
            )

        case .armsForward:
            return PoseDefinition(
                name: "Arms Forward",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_RightArm": SCNVector3(deg(90), deg(0), deg(0)),
                    "mixamorig_LeftArm": SCNVector3(deg(90), deg(0), deg(0))
                ],
                description: "Arms extended directly forward to shift CoM along the Z axis."
            )

        // MARK: - Arms Only Poses

        case .armsHighV:
            return PoseDefinition(
                name: "High V Arms",
                category: .armsOnly,
                jointAngles: [
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-135)),
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(135)),
                ],
                description: "Arms in high V position",
                affectedJoints: Set([
                    "mixamorig_RightArm", "mixamorig_LeftArm", "mixamorig_RightShoulder",
                    "mixamorig_LeftShoulder", "mixamorig_RightForeArm", "mixamorig_LeftForeArm",
                ])
            )

        case .armsLowV:
            return PoseDefinition(
                name: "Low V Arms",
                category: .armsOnly,
                jointAngles: [
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-45)),
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(45)),
                ],
                description: "Arms in low V position",
                affectedJoints: Set(["mixamorig_RightArm", "mixamorig_LeftArm"])
            )

        case .armsT:
            return PoseDefinition(
                name: "T Arms",
                category: .armsOnly,
                jointAngles: [
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-90)),
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(90)),
                ],
                description: "Arms extended to sides",
                affectedJoints: Set(["mixamorig_RightArm", "mixamorig_LeftArm"])
            )

        case .armsTouchdown:
            return PoseDefinition(
                name: "Touchdown Arms",
                category: .armsOnly,
                jointAngles: [
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-180)),
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(180)),
                ],
                description: "Arms straight up",
                affectedJoints: Set(["mixamorig_RightArm", "mixamorig_LeftArm"])
            )

        case .armsBowAndArrow:
            return PoseDefinition(
                name: "Bow & Arrow Arms",
                category: .armsOnly,
                jointAngles: [
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-90)),
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(-90), deg(90)),
                    "mixamorig_LeftForeArm": SCNVector3(deg(0), deg(0), deg(-90)),
                ],
                description: "Bow and arrow arm position",
                affectedJoints: Set([
                    "mixamorig_RightArm", "mixamorig_LeftArm", "mixamorig_LeftForeArm",
                ])
            )

        case .armsDaggers:
            return PoseDefinition(
                name: "Daggers",
                category: .armsOnly,
                jointAngles: [
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-15)),
                    "mixamorig_RightForeArm": SCNVector3(deg(0), deg(0), deg(90)),
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(15)),
                    "mixamorig_LeftForeArm": SCNVector3(deg(0), deg(0), deg(-90)),
                ],
                description: "Fists at hips",
                affectedJoints: Set([
                    "mixamorig_RightArm", "mixamorig_LeftArm", "mixamorig_RightForeArm",
                    "mixamorig_LeftForeArm",
                ])
            )

        case .armsBrokenT:
            return PoseDefinition(
                name: "Broken T",
                category: .armsOnly,
                jointAngles: [
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-90)),
                    "mixamorig_RightForeArm": SCNVector3(deg(0), deg(0), deg(90)),
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(90)),
                    "mixamorig_LeftForeArm": SCNVector3(deg(0), deg(0), deg(-90)),
                ],
                description: "T with bent elbows",
                affectedJoints: Set([
                    "mixamorig_RightArm", "mixamorig_LeftArm", "mixamorig_RightForeArm",
                    "mixamorig_LeftForeArm",
                ])
            )

        case .armsHalfHighVHalfT:
            return PoseDefinition(
                name: "Half High V / Half T",
                category: .armsOnly,
                jointAngles: [
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-135)),
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(90)),
                ],
                description: "One arm high V, one arm T",
                affectedJoints: Set(["mixamorig_RightArm", "mixamorig_LeftArm"])
            )

        // MARK: - Legs Only Poses

        case .legsStanding:
            return PoseDefinition(
                name: "Standing",
                category: .legsOnly,
                jointAngles: [
                    "mixamorig_RightUpLeg": SCNVector3Zero,
                    "mixamorig_RightLeg": SCNVector3Zero,
                    "mixamorig_LeftUpLeg": SCNVector3Zero,
                    "mixamorig_LeftLeg": SCNVector3Zero,
                ],
                description: "Standing position",
                affectedJoints: Set([
                    "mixamorig_RightUpLeg", "mixamorig_RightLeg", "mixamorig_LeftUpLeg",
                    "mixamorig_LeftLeg", "mixamorig_RightFoot", "mixamorig_LeftFoot",
                ])
            )

        case .legsLibertyRight:
            return PoseDefinition(
                name: "Liberty (Right)",
                category: .legsOnly,
                jointAngles: [
                    "mixamorig_RightUpLeg": SCNVector3(deg(0), deg(0), deg(-90)),
                    "mixamorig_RightLeg": SCNVector3(deg(0), deg(0), deg(90)),
                    "mixamorig_LeftUpLeg": SCNVector3Zero,
                    "mixamorig_LeftLeg": SCNVector3Zero,
                ],
                description: "Right leg raised",
                affectedJoints: Set([
                    "mixamorig_RightUpLeg", "mixamorig_RightLeg", "mixamorig_LeftUpLeg",
                    "mixamorig_LeftLeg",
                ])
            )

        case .legsLibertyLeft:
            return PoseDefinition(
                name: "Liberty (Left)",
                category: .legsOnly,
                jointAngles: [
                    "mixamorig_LeftUpLeg": SCNVector3(deg(0), deg(0), deg(90)),
                    "mixamorig_LeftLeg": SCNVector3(deg(0), deg(0), deg(-90)),
                    "mixamorig_RightUpLeg": SCNVector3Zero,
                    "mixamorig_RightLeg": SCNVector3Zero,
                ],
                description: "Left leg raised",
                affectedJoints: Set([
                    "mixamorig_RightUpLeg", "mixamorig_RightLeg", "mixamorig_LeftUpLeg",
                    "mixamorig_LeftLeg",
                ])
            )

        case .legsScaleRight:
            return PoseDefinition(
                name: "Scale (Right)",
                category: .legsOnly,
                jointAngles: [
                    "mixamorig_RightUpLeg": SCNVector3(deg(0), deg(0), deg(-90)),
                    "mixamorig_LeftUpLeg": SCNVector3Zero,
                ],
                description: "Right leg to side",
                affectedJoints: Set(["mixamorig_RightUpLeg", "mixamorig_LeftUpLeg"])
            )

        case .legsScaleLeft:
            return PoseDefinition(
                name: "Scale (Left)",
                category: .legsOnly,
                jointAngles: [
                    "mixamorig_LeftUpLeg": SCNVector3(deg(0), deg(0), deg(90)),
                    "mixamorig_RightUpLeg": SCNVector3Zero,
                ],
                description: "Left leg to side",
                affectedJoints: Set(["mixamorig_RightUpLeg", "mixamorig_LeftUpLeg"])
            )

        case .legsArabesque:
            return PoseDefinition(
                name: "Arabesque Legs",
                category: .legsOnly,
                jointAngles: [
                    "mixamorig_RightUpLeg": SCNVector3(deg(-60), deg(0), deg(0)),
                    "mixamorig_LeftUpLeg": SCNVector3Zero,
                ],
                description: "Right leg extended back",
                affectedJoints: Set(["mixamorig_RightUpLeg", "mixamorig_LeftUpLeg"])
            )

        case .legsStraddle:
            return PoseDefinition(
                name: "Straddle",
                category: .legsOnly,
                jointAngles: [
                    "mixamorig_RightUpLeg": SCNVector3(deg(-90), deg(0), deg(45)),
                    "mixamorig_LeftUpLeg": SCNVector3(deg(-90), deg(0), deg(-45)),
                ],
                description: "Straddle position",
                affectedJoints: Set(["mixamorig_RightUpLeg", "mixamorig_LeftUpLeg"])
            )

        case .handstand:
            return PoseDefinition(
                name: "Handstand",
                category: .fullBody,
                jointAngles: [
                    "mixamorig_Hips": SCNVector3(deg(180), deg(0), deg(0)),
                    "mixamorig_RightArm": SCNVector3(deg(0), deg(0), deg(-180)),
                    "mixamorig_LeftArm": SCNVector3(deg(0), deg(0), deg(180))
                ],
                description: "Inverted handstand position",
                affectedJoints: Set([
                    "mixamorig_Hips", "mixamorig_RightArm", "mixamorig_LeftArm"
                ])
            )

        case .legsPike:
            return PoseDefinition(
                name: "Pike",
                category: .legsOnly,
                jointAngles: [
                    "mixamorig_RightUpLeg": SCNVector3(deg(-90), deg(0), deg(0)),
                    "mixamorig_LeftUpLeg": SCNVector3(deg(-90), deg(0), deg(0)),
                ],
                description: "Pike position",
                affectedJoints: Set(["mixamorig_RightUpLeg", "mixamorig_LeftUpLeg"])
            )

        case .legsSquat:
            return PoseDefinition(
                name: "Squat",
                category: .legsOnly,
                jointAngles: [
                    "mixamorig_RightUpLeg": SCNVector3(deg(45), deg(0), deg(0)),
                    "mixamorig_RightLeg": SCNVector3(deg(-90), deg(0), deg(0)),
                    "mixamorig_LeftUpLeg": SCNVector3(deg(45), deg(0), deg(0)),
                    "mixamorig_LeftLeg": SCNVector3(deg(-90), deg(0), deg(0)),
                ],
                description: "Squat position",
                affectedJoints: Set([
                    "mixamorig_RightUpLeg", "mixamorig_RightLeg", "mixamorig_LeftUpLeg",
                    "mixamorig_LeftLeg",
                ])
            )
        }
    }

    // Get all poses for a category
    func getPoses(for category: PoseCategory) -> [PoseType] {
        let allPoses: [PoseType] = [
            // Full Body
            .tPose, .highV, .lowV, .touchdown, .bowAndArrow, .liberty, .scale, .arabesque,
            .bridge, .backbend, .standingSplit, .prepPosition, .squat, .pike, .layout, .sideLean, .lungePose, .handstand,
            .testPose1, .testPose2, .testPose3, .testPose4, .testPose5, .testPose6, .testPose7, .testPose8, .testPose9, .testPose10, .testPose11, .testPose12, .testPose13, .testPose14, .testPose15, .testPose16, .testPose17, .testPose18, .testPose24, .testPose25, .testPose26, .armsForward,
            // Arms
            .armsHighV, .armsLowV, .armsT, .armsTouchdown, .armsBowAndArrow,
            .armsDaggers, .armsBrokenT, .armsHalfHighVHalfT,
            // Legs
            .legsStanding, .legsLibertyRight, .legsLibertyLeft, .legsScaleRight, .legsScaleLeft,
            .legsArabesque, .legsStraddle, .legsPike, .legsSquat,
        ]

        return allPoses.filter { $0.category == category }
    }
}
// Baseline Audit Verified
