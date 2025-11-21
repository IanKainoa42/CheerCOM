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
            .bridge, .backbend, .standingSplit, .prepPosition,
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
