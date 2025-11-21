import SceneKit

class CameraManager {
    var cameraNode: SCNNode!
    var currentCameraIndex = 0

    let cameraPositions: [(position: SCNVector3, lookAt: SCNVector3, name: String)] = [
        (SCNVector3(x: 0, y: 90, z: 220), SCNVector3(x: 0, y: 90, z: 0), "Front"),
        (SCNVector3(x: 220, y: 90, z: 0), SCNVector3(x: 0, y: 90, z: 0), "Right"),
        (SCNVector3(x: 0, y: 90, z: -220), SCNVector3(x: 0, y: 90, z: 0), "Back"),
        (SCNVector3(x: -220, y: 90, z: 0), SCNVector3(x: 0, y: 90, z: 0), "Left"),
        (SCNVector3(x: 0, y: 300, z: 0), SCNVector3(x: 0, y: 0, z: 0), "Top"),
    ]

    init(scene: SCNScene) {
        setupCamera(in: scene)
    }

    private func setupCamera(in scene: SCNScene) {
        // Add camera with fixed positions
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()

        // Adjust clipping planes to prevent model clipping
        cameraNode.camera!.zNear = 1.0  // Very close objects visible
        cameraNode.camera!.zFar = 1000.0  // Far objects visible

        let initialPos = cameraPositions[0]
        cameraNode.position = initialPos.position
        cameraNode.look(at: initialPos.lookAt)
        scene.rootNode.addChildNode(cameraNode)

        print("📷 Camera positioned at: \(initialPos.name)")
    }

    func switchToCamera(index: Int) -> String {
        let newPos = cameraPositions[index]

        // Animate camera transition
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        // First, reset camera rotation to avoid accumulated rotations
        cameraNode.eulerAngles = SCNVector3Zero

        // Set position
        cameraNode.position = newPos.position

        // Now look at target - this will set proper orientation
        cameraNode.look(at: newPos.lookAt)

        SCNTransaction.commit()

        print("📷 Switched to: \(newPos.name) - Pos: \(newPos.position), LookAt: \(newPos.lookAt)")
        return newPos.name
    }

    func nextView() -> String {
        currentCameraIndex = (currentCameraIndex + 1) % cameraPositions.count
        return switchToCamera(index: currentCameraIndex)
    }

    func previousView() -> String {
        currentCameraIndex =
            (currentCameraIndex - 1 + cameraPositions.count) % cameraPositions.count
        return switchToCamera(index: currentCameraIndex)
    }

    func fitToView() -> String {
        // Reset to current camera position (smooth re-center)
        return switchToCamera(index: currentCameraIndex)
    }

    func getCurrentCameraName() -> String {
        return cameraPositions[currentCameraIndex].name
    }
}
