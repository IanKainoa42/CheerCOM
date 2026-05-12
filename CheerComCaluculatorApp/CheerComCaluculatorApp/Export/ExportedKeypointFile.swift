import Foundation

/// The exact JSON schema emitted per (animation, camera sample). Matches
/// Section 7 of the tumbling skill classification design spec.
public struct ExportedKeypointFile: Codable {
    public let schemaVersion: Int
    public let source: String
    public let createdAt: Date
    public let animationId: String
    public let fps: Int
    public let numFrames: Int
    public let skill: ExportedSkill
    public let camera: ExportedCamera
    public let character: ExportedCharacter
    public let frames: [ExportedFrame]

    public struct ExportedSkill: Codable {
        public let atom: String
        public let category: String
        public let notes: String
    }

    public struct ExportedCamera: Codable {
        public let azimuthDeg: Double
        public let elevationDeg: Double
        public let distanceM: Double
        public let focalLengthMm: Double
        public let imageWidthPx: Int
        public let imageHeightPx: Int
    }

    public struct ExportedCharacter: Codable {
        public let rig: String
        public let heightM: Double
        public let proportionsPreset: String
    }

    public struct ExportedFrame: Codable {
        public let frame: Int
        public let t: Double
        public let persons: [ExportedPerson]
    }

    public struct ExportedPerson: Codable {
        public let personId: Int
        public let role: String
        public let boundingBoxNorm: [Double]
        public let keypoints: [ExportedKeypoint]
        public let bodyline: String?
        public let derived: ExportedDerived
    }

    public struct ExportedKeypoint: Codable {
        public let name: String
        public let x: Double
        public let y: Double
        public let confidence: Double
    }

    public struct ExportedDerived: Codable {
        public let inversion: Bool
        public let bodyAngleDeg: Double
        public let hipAngleDeg: Double
        public let kneeAngleLeftDeg: Double
        public let kneeAngleRightDeg: Double
        public let comXNorm: Double
        public let comYNorm: Double
        public let comVxNorm: Double
        public let comVyNorm: Double
        public let hipAngularVelocityDps: Double
        public let shoulderHipTwistDeg: Double
        public let groundContact: Bool
    }
}

/// Canonical COCO keypoint names in the order produced by YOLOv8-pose.
public enum COCOKeypointNames {
    public static let ordered: [String] = [
        "nose", "left_eye", "right_eye", "left_ear", "right_ear",
        "left_shoulder", "right_shoulder", "left_elbow", "right_elbow",
        "left_wrist", "right_wrist", "left_hip", "right_hip",
        "left_knee", "right_knee", "left_ankle", "right_ankle"
    ]
}
