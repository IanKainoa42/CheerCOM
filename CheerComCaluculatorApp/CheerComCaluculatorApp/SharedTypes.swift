import Foundation

enum BodyPreset: String, CaseIterable, Identifiable {
    case averageNeutral = "Neutral"
    case athleticFemale = "Athletic F"
    case athleticMale = "Athletic M"

    var id: String { rawValue }
}

enum JointAxis: String, CaseIterable, Codable {
    case xAxis = "X-Axis"
    case yAxis = "Y-Axis"
    case zAxis = "Z-Axis"




}

enum PoseCategory {
    case fullBody
    case armsOnly
    case legsOnly
    case saved

    var displayName: String {
        switch self {
        case .fullBody: return "Full Body"
        case .armsOnly: return "Arms Only"
        case .legsOnly: return "Legs Only"
        case .saved: return "Saved Poses"
        }
    }
}

enum PoseType {
    // Full Body Poses
    case tPose
    case highV
    case lowV
    case touchdown
    case bowAndArrow
    case liberty
    case scale
    case arabesque
    case bridge
    case backbend
    case standingSplit
    case prepPosition
    case squat
    case pike
    case layout
    case sideLean
    case lungePose
    case handstand

    case testPose1
    case testPose2
    case testPose3
    case testPose4
    case testPose5
    case testPose6
    case testPose7
    case testPose8

    // Arms Only Poses
    case armsHighV
    case armsLowV
    case armsT
    case armsTouchdown
    case armsBowAndArrow
    case armsDaggers
    case armsBrokenT
    case armsHalfHighVHalfT

    // Legs Only Poses
    case legsStanding
    case legsLibertyRight
    case legsLibertyLeft
    case legsScaleRight
    case legsScaleLeft
    case legsArabesque
    case legsStraddle
    case legsPike
    case legsSquat

    var category: PoseCategory {
        switch self {
        case .tPose, .highV, .lowV, .touchdown, .bowAndArrow, .liberty, .scale, .arabesque, .bridge,
            .backbend, .standingSplit, .prepPosition, .squat, .pike, .layout, .sideLean, .lungePose, .handstand:
            return .fullBody
        case .armsHighV, .armsLowV, .armsT, .armsTouchdown, .armsBowAndArrow, .armsDaggers,
            .armsBrokenT, .armsHalfHighVHalfT:
            return .armsOnly
        case .legsStanding, .legsLibertyRight, .legsLibertyLeft, .legsScaleRight, .legsScaleLeft,
            .legsArabesque, .legsStraddle, .legsPike, .legsSquat:
            return .legsOnly
        }
    }

    var displayName: String {
        switch self {
        // Full Body
        case .tPose: return "T-Pose"
        case .highV: return "High V"
        case .lowV: return "Low V"
        case .touchdown: return "Touchdown"
        case .bowAndArrow: return "Bow & Arrow"
        case .liberty: return "Liberty"
        case .scale: return "Scale"
        case .arabesque: return "Arabesque"
        case .bridge: return "Bridge"
        case .backbend: return "Backbend"
        case .standingSplit: return "Standing Split"
        case .prepPosition: return "Prep Position"
        case .squat: return "Squat"
        case .pike: return "Pike"
        case .layout: return "Layout"
        case .sideLean: return "Side Lean"
        case .lungePose: return "Lunge"
        case .handstand: return "Handstand"

        case .testPose1: return "Test Pose 1"
        case .testPose2: return "Test Pose 2"
        case .testPose3: return "Test Pose 3"
        case .testPose4: return "Test Pose 4"
        case .testPose5: return "Test Pose 5"
        case .testPose6: return "Test Pose 6"
        case .testPose7: return "Test Pose 7"
        case .testPose8: return "Test Pose 8"

        // Arms Only
        case .armsHighV: return "High V Arms"
        case .armsLowV: return "Low V Arms"
        case .armsT: return "T Arms"
        case .armsTouchdown: return "Touchdown Arms"
        case .armsBowAndArrow: return "Bow & Arrow Arms"
        case .armsDaggers: return "Daggers"
        case .armsBrokenT: return "Broken T"
        case .armsHalfHighVHalfT: return "Half High V / Half T"

        // Legs Only
        case .legsStanding: return "Standing"
        case .legsLibertyRight: return "Liberty (Right)"
        case .legsLibertyLeft: return "Liberty (Left)"
        case .legsScaleRight: return "Scale (Right)"
        case .legsScaleLeft: return "Scale (Left)"
        case .legsArabesque: return "Arabesque Legs"
        case .legsStraddle: return "Straddle"
        case .legsPike: return "Pike"
        case .legsSquat: return "Squat"
        }
    }

    var emoji: String {
        switch self {
        // Full Body
        case .tPose: return "🧍"
        case .highV: return "🙌"
        case .lowV: return "👐"
        case .touchdown: return "🙋"
        case .bowAndArrow: return "🏹"
        case .liberty: return "🦩"
        case .scale: return "⚖️"
        case .arabesque: return "🩰"
        case .bridge: return "🌉"
        case .backbend: return "🤸"
        case .standingSplit: return "🤸‍♀️"
        case .prepPosition: return "👯"
        case .squat: return "🏋️"
        case .pike: return "📐"
        case .layout: return "🧍"
        case .sideLean: return "📐"
        case .lungePose: return "🤺"
        case .handstand: return "🤸‍♂️"

        case .testPose1: return "🧪"
        case .testPose2: return "🧪"
        case .testPose3: return "🧪"
        case .testPose4: return "🧪"
        case .testPose5: return "🧪"
        case .testPose6: return "🧪"
        case .testPose7: return "🧪"
        case .testPose8: return "🧪"

        // Arms
        case .armsHighV: return "🙌"
        case .armsLowV: return "👐"
        case .armsT: return "✝️"
        case .armsTouchdown: return "🙋"
        case .armsBowAndArrow: return "🏹"
        case .armsDaggers: return "🗡️"
        case .armsBrokenT: return "⚡"
        case .armsHalfHighVHalfT: return "🔀"

        // Legs
        case .legsStanding: return "🧍"
        case .legsLibertyRight, .legsLibertyLeft: return "🦩"
        case .legsScaleRight, .legsScaleLeft: return "⚖️"
        case .legsArabesque: return "🩰"
        case .legsStraddle: return "🤸‍♀️"
        case .legsPike: return "📐"
        case .legsSquat: return "🏋️"
        }
    }
}

enum RotationDirection {
    case positive
    case negative
}

enum TransformMode: String, CaseIterable, Codable {
    case position
    case rotation
    case scale
}

enum TransformDirection: String, Codable {
    case up
    case down
    case left
    case right
    case forward
    case backward
}

public struct SegmentData {
    public let name: String
    public let proximalJoint: Joint
    public let distalJoint: Joint
    public let massRatio: Double
    public let comRatio: Double

    public init(name: String, proximalJoint: Joint, distalJoint: Joint, massRatio: Double, comRatio: Double) {
        self.name = name
        self.proximalJoint = proximalJoint
        self.distalJoint = distalJoint
        self.massRatio = massRatio
        self.comRatio = comRatio
    }
}

public enum Joint: String, CaseIterable, Codable {
    case hips = "mixamorig_Hips"
    case spine = "mixamorig_Spine"
    case spine1 = "mixamorig_Spine1"
    case spine2 = "mixamorig_Spine2"
    case neck = "mixamorig_Neck"
    case head = "mixamorig_Head"
    case headTop_End = "mixamorig_HeadTop_End"
    case rightShoulder = "mixamorig_RightShoulder"
    case rightArm = "mixamorig_RightArm"
    case rightForeArm = "mixamorig_RightForeArm"
    case rightHand = "mixamorig_RightHand"
    case rightHandMiddle1 = "mixamorig_RightHandMiddle1"
    case leftShoulder = "mixamorig_LeftShoulder"
    case leftArm = "mixamorig_LeftArm"
    case leftForeArm = "mixamorig_LeftForeArm"
    case leftHand = "mixamorig_LeftHand"
    case leftHandMiddle1 = "mixamorig_LeftHandMiddle1"
    case rightUpLeg = "mixamorig_RightUpLeg"
    case rightLeg = "mixamorig_RightLeg"
    case rightFoot = "mixamorig_RightFoot"
    case leftUpLeg = "mixamorig_LeftUpLeg"
    case leftLeg = "mixamorig_LeftLeg"
    case leftFoot = "mixamorig_LeftFoot"
    case leftToeBase = "mixamorig_LeftToeBase"
    case rightToeBase = "mixamorig_RightToeBase"
}
