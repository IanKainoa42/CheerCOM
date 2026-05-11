import Foundation
import SceneKit


/// Projects a rigged Mixamo character's joint world positions to 2D COCO keypoint
/// coordinates from a virtual camera's viewpoint. Output: 17 COCOKeypoints in
/// normalized [0, 1] image coordinates, in COCO order.
///
/// Face keypoints (nose, eyes, ears) are all approximated from the head bone
/// position — the nose keypoint gets the head bone exactly, and eyes/ears are
/// also mapped to the head bone. Intentional approximation: real YOLO face
/// keypoints cluster tightly, and face points don't drive tumbling classification.
public struct MixamoCOCOProjector {

    /// Mapping from each COCO keypoint slot to the Mixamo bone name that drives it.
    public static let boneMapping: [(COCOKeypointIndex, String)] = [
        (.nose,          "mixamorig_Head"),
        (.leftEye,       "mixamorig_Head"),
        (.rightEye,      "mixamorig_Head"),
        (.leftEar,       "mixamorig_Head"),
        (.rightEar,      "mixamorig_Head"),
        (.leftShoulder,  "mixamorig_LeftArm"),
        (.rightShoulder, "mixamorig_RightArm"),
        (.leftElbow,     "mixamorig_LeftForeArm"),
        (.rightElbow,    "mixamorig_RightForeArm"),
        (.leftWrist,     "mixamorig_LeftHand"),
        (.rightWrist,    "mixamorig_RightHand"),
        (.leftHip,       "mixamorig_LeftUpLeg"),
        (.rightHip,      "mixamorig_RightUpLeg"),
        (.leftKnee,      "mixamorig_LeftLeg"),
        (.rightKnee,     "mixamorig_RightLeg"),
        (.leftAnkle,     "mixamorig_LeftFoot"),
        (.rightAnkle,    "mixamorig_RightFoot")
    ]

    /// Extract 17 COCO keypoints from the rigged character using the given virtual camera.
    @MainActor
    public static func project(
        boneNodes: [String: SCNNode],
        camera cameraNode: SCNNode,
        sceneView: SCNView
    ) -> [COCOKeypoint] {
        var result: [COCOKeypoint] = Array(
            repeating: COCOKeypoint(x: 0, y: 0, confidence: 0),
            count: 17
        )

        let originalPoint = sceneView.pointOfView
        sceneView.pointOfView = cameraNode
        defer { sceneView.pointOfView = originalPoint }

        let bounds = sceneView.bounds
        let width = Float(bounds.width == 0 ? 1920 : bounds.width)
        let height = Float(bounds.height == 0 ? 1080 : bounds.height)

        for (cocoIndex, boneName) in boneMapping {
            guard let boneNode = boneNodes[boneName] else {
                result[cocoIndex.rawValue] = COCOKeypoint(x: 0, y: 0, confidence: 0)
                continue
            }

            let worldPos = boneNode.presentation.worldPosition
            let projected = sceneView.projectPoint(worldPos)

            let normX = Float(projected.x) / width
            let normY = Float(projected.y) / height

            result[cocoIndex.rawValue] = COCOKeypoint(
                x: normX,
                y: normY,
                confidence: 1.0
            )
        }

        return result
    }

    /// Compute the normalized bounding box from a list of COCO keypoints.
    /// Returns (xMin, yMin, xMax, yMax) in [0, 1].
    public static func boundingBox(from keypoints: [COCOKeypoint]) -> (Double, Double, Double, Double) {
        let valid = keypoints.filter { $0.confidence > 0 }
        guard !valid.isEmpty else { return (0, 0, 0, 0) }

        let xs = valid.map { Double($0.x) }
        let ys = valid.map { Double($0.y) }
        return (xs.min()!, ys.min()!, xs.max()!, ys.max()!)
    }
}
