import Foundation
import SceneKit
import ModelRigKit


/// Exports a SkillAnimation to JSON files — one per camera sample in the orbital grid.
@MainActor
public final class SkillAnimationExporter {

    public enum ExportError: Error {
        case missingPose(id: UUID)
        case missingKeyframePose(frameIndex: Int)
        case noKeyframes
    }

    private let sceneView: SCNView
    private let characterNode: SCNNode
    private let boneNodes: [String: SCNNode]

    public init(sceneView: SCNView, characterNode: SCNNode, boneNodes: [String: SCNNode]) {
        self.sceneView = sceneView
        self.characterNode = characterNode
        self.boneNodes = boneNodes
    }

    // MARK: - Output directory

    public static var exportRootURL: URL {
        let fm = FileManager.default
        let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let rawDir = docsURL
            .appendingPathComponent("CheerCOMAnimations", isDirectory: true)
            .appendingPathComponent("training_data", isDirectory: true)
            .appendingPathComponent("raw", isDirectory: true)
        if !fm.fileExists(atPath: rawDir.path) {
            try? fm.createDirectory(at: rawDir, withIntermediateDirectories: true)
        }
        return rawDir
    }

    // MARK: - Export entry

    public func export(
        animation: SkillAnimation,
        poseResolver: (UUID) -> [String: SCNVector3]?,
        bodylineForPoseId: (UUID) -> String?
    ) throws -> [URL] {
        guard !animation.keyframes.isEmpty else { throw ExportError.noKeyframes }

        let resolved: [KeyframeInterpolator.ResolvedKeyframe] = try animation.sortedKeyframes.map { kf in
            let angles: [String: SCNVector3]
            if let inlineAngles = kf.inlineJointAngles {
                angles = vectorAngles(from: inlineAngles)
            } else if let poseId = kf.poseId {
                guard let resolvedAngles = poseResolver(poseId) else {
                    throw ExportError.missingPose(id: poseId)
                }
                angles = resolvedAngles
            } else {
                throw ExportError.missingKeyframePose(frameIndex: kf.frameIndex)
            }
            return KeyframeInterpolator.ResolvedKeyframe(
                frameIndex: kf.frameIndex,
                jointAngles: angles
            )
        }
        let interpolator = KeyframeInterpolator(
            keyframes: resolved,
            numFrames: animation.numFrames
        )

        let bodylineByFrame = buildBodylineByFrame(
            keyframes: animation.sortedKeyframes,
            numFrames: animation.numFrames,
            bodylineForPoseId: bodylineForPoseId
        )

        let cameraSamples = OrbitalCameraSampler.standardGrid()
        var writtenUrls: [URL] = []
        let timestampFormatter = ISO8601DateFormatter()
        timestampFormatter.formatOptions = [.withInternetDateTime, .withTimeZone]
        let timestamp = timestampFormatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")

        let exportRoot = Self.exportRootURL

        for cameraSample in cameraSamples {
            let frames = renderFrames(
                animation: animation,
                interpolator: interpolator,
                cameraSample: cameraSample,
                bodylineByFrame: bodylineByFrame
            )

            let file = ExportedKeypointFile(
                schemaVersion: 1,
                source: "cheercom_skill_animator",
                createdAt: Date(),
                animationId: "\(animation.atomId)_\(animation.id.uuidString.prefix(8))",
                fps: animation.fps,
                numFrames: animation.numFrames,
                skill: .init(
                    atom: animation.atomId,
                    category: animation.category,
                    notes: animation.notes
                ),
                camera: .init(
                    azimuthDeg: cameraSample.azimuthDeg,
                    elevationDeg: cameraSample.elevationDeg,
                    distanceM: cameraSample.distanceM,
                    focalLengthMm: cameraSample.focalLengthMm,
                    imageWidthPx: cameraSample.imageWidthPx,
                    imageHeightPx: cameraSample.imageHeightPx
                ),
                character: .init(
                    rig: animation.characterRig,
                    heightM: animation.characterHeightM,
                    proportionsPreset: animation.characterProportionsPreset
                ),
                frames: frames
            )

            let elevationSign = cameraSample.elevationDeg >= 0 ? "p" : "m"
            let elevationAbs = Int(abs(cameraSample.elevationDeg))
            let filename = String(
                format: "%@_az%03d_el%@%02d_%@.json",
                animation.atomId,
                Int(cameraSample.azimuthDeg),
                elevationSign,
                elevationAbs,
                timestamp
            )
            let url = exportRoot.appendingPathComponent(filename)
            try writeFile(file, to: url)
            writtenUrls.append(url)
        }

        return writtenUrls
    }

    // MARK: - Per-frame rendering

    private func renderFrames(
        animation: SkillAnimation,
        interpolator: KeyframeInterpolator,
        cameraSample: CameraSample,
        bodylineByFrame: [Int: String?]
    ) -> [ExportedKeypointFile.ExportedFrame] {
        var frames: [ExportedKeypointFile.ExportedFrame] = []
        var previousFeatures: KinematicFeatures? = nil

        let cameraNode = makeCameraNode(for: cameraSample)

        for frameIndex in 0..<animation.numFrames {
            let angles = interpolator.angles(atFrame: frameIndex)
            applyAngles(angles, to: boneNodes)

            let keypoints = MixamoCOCOProjector.project(
                boneNodes: boneNodes,
                camera: cameraNode,
                sceneView: sceneView
            )

            let features = KinematicFeatures.compute(
                keypoints: keypoints,
                previous: previousFeatures,
                fps: Double(animation.fps)
            )
            previousFeatures = features

            let (xmin, ymin, xmax, ymax) = MixamoCOCOProjector.boundingBox(from: keypoints)

            let person = ExportedKeypointFile.ExportedPerson(
                personId: 0,
                role: "tumbler",
                boundingBoxNorm: [xmin, ymin, xmax, ymax],
                keypoints: zip(keypoints, COCOKeypointNames.ordered).map { kp, name in
                    ExportedKeypointFile.ExportedKeypoint(
                        name: name,
                        x: Double(kp.x),
                        y: Double(kp.y),
                        confidence: Double(kp.confidence)
                    )
                },
                bodyline: bodylineByFrame[frameIndex] ?? nil,
                derived: .init(
                    inversion: features.inversion,
                    bodyAngleDeg: features.bodyAngleDeg,
                    hipAngleDeg: features.hipAngleDeg,
                    kneeAngleLeftDeg: features.kneeAngleLeftDeg,
                    kneeAngleRightDeg: features.kneeAngleRightDeg,
                    comXNorm: features.comXNorm,
                    comYNorm: features.comYNorm,
                    comVxNorm: features.comVxNorm,
                    comVyNorm: features.comVyNorm,
                    hipAngularVelocityDps: features.hipAngularVelocityDps,
                    shoulderHipTwistDeg: features.shoulderHipTwistDeg,
                    groundContact: features.groundContact
                )
            )

            frames.append(ExportedKeypointFile.ExportedFrame(
                frame: frameIndex,
                t: Double(frameIndex) / Double(animation.fps),
                persons: [person]
            ))
        }

        return frames
    }

    // MARK: - Helpers

    private func applyAngles(_ angles: [String: SCNVector3], to boneNodes: [String: SCNNode]) {
        for (boneName, eulerAngles) in angles {
            if let node = boneNodes[boneName] {
                node.eulerAngles = eulerAngles
            }
        }
    }

    private func makeCameraNode(for sample: CameraSample) -> SCNNode {
        let azRad = sample.azimuthDeg * .pi / 180.0
        let elRad = sample.elevationDeg * .pi / 180.0

        let x = sample.distanceM * cos(elRad) * sin(azRad)
        let y = sample.distanceM * sin(elRad) + 1.0
        let z = sample.distanceM * cos(elRad) * cos(azRad)

        let camera = SCNCamera()
        camera.fieldOfView = 60
        let node = SCNNode()
        node.camera = camera
        #if os(macOS)
        node.position = SCNVector3(CGFloat(x), CGFloat(y), CGFloat(z))
        #else
        node.position = SCNVector3(Float(x), Float(y), Float(z))
        #endif
        node.look(at: characterNode.presentation.worldPosition)
        return node
    }

    private func buildBodylineByFrame(
        keyframes: [SkillKeyframe],
        numFrames: Int,
        bodylineForPoseId: (UUID) -> String?
    ) -> [Int: String?] {
        var result: [Int: String?] = [:]
        guard !keyframes.isEmpty else { return result }

        let pairs: [(Int, String?)] = keyframes.map { kf in
            let bodylineId = kf.bodylineId ?? kf.poseId.flatMap(bodylineForPoseId)
            return (kf.frameIndex, bodylineId)
        }

        for frame in 0..<numFrames {
            let nearest = pairs.min { abs($0.0 - frame) < abs($1.0 - frame) }
            result[frame] = nearest?.1
        }
        return result
    }

    private func vectorAngles(from inlineJointAngles: [String: [Float]]) -> [String: SCNVector3] {
        var result: [String: SCNVector3] = [:]
        for (boneName, components) in inlineJointAngles where components.count == 3 {
            #if os(macOS)
            result[boneName] = SCNVector3(
                CGFloat(components[0]), CGFloat(components[1]), CGFloat(components[2])
            )
            #else
            result[boneName] = SCNVector3(components[0], components[1], components[2])
            #endif
        }
        return result
    }

    private func writeFile(_ file: ExportedKeypointFile, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(file)
        try data.write(to: url, options: .atomic)
    }
}
