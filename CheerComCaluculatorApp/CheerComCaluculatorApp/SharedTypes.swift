import Foundation

enum JointAxis: String {
    case x = "X-Axis"
    case y = "Y-Axis"
    case z = "Z-Axis"
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
    case handstand

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
            .backbend, .standingSplit, .prepPosition, .squat, .pike, .layout, .sideLean, .handstand:
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
        case .handstand: return "Handstand"

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
        case .handstand: return "🤸"

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

enum TransformMode {
    case position, rotation, scale
}

enum TransformDirection {
    case up, down, left, right
}
