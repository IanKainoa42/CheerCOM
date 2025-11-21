import SceneKit
import UIKit

class CheerCOMSceneManager {
    var sceneView: SCNView!
    var scene: SCNScene!
    var characterNode: SCNNode!
    var cachedBoneNodes: [String: SCNNode] = [:]

    // List of controllable joints (in order from root to extremities)
    let controllableJoints = [
        "mixamorig_Hips",
        "mixamorig_Spine",
        "mixamorig_Spine1",
        "mixamorig_Spine2",
        "mixamorig_Neck",
        "mixamorig_Head",
        "mixamorig_RightShoulder",
        "mixamorig_RightArm",
        "mixamorig_RightForeArm",
        "mixamorig_RightHand",
        "mixamorig_LeftShoulder",
        "mixamorig_LeftArm",
        "mixamorig_LeftForeArm",
        "mixamorig_LeftHand",
        "mixamorig_RightUpLeg",
        "mixamorig_RightLeg",
        "mixamorig_RightFoot",
        "mixamorig_LeftUpLeg",
        "mixamorig_LeftLeg",
        "mixamorig_LeftFoot",
    ]

    init(view: UIView) {
        setupScene(in: view)
    }

    private func setupScene(in view: UIView) {
        // Create scene view
        sceneView = SCNView(frame: view.bounds)
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(sceneView)

        // Create scene
        scene = SCNScene()
        sceneView.scene = scene

        // Enable free camera controls
        sceneView.allowsCameraControl = true
        sceneView.backgroundColor = UIColor(white: 0.15, alpha: 1.0)  // Dark gray background

        // Show statistics (FPS, etc)
        sceneView.showsStatistics = false

        print("📷 Scene view frame: \(view.bounds)")

        setupLighting()
        setupGround()
    }

    private func setupLighting() {
        // Add lights - brighter setup
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light!.type = .ambient
        ambientLight.light!.color = UIColor(white: 0.6, alpha: 1.0)
        ambientLight.light!.intensity = 1000
        scene.rootNode.addChildNode(ambientLight)

        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light!.type = .directional
        directionalLight.light!.intensity = 1500
        directionalLight.position = SCNVector3(x: 0, y: 100, z: 100)
        directionalLight.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(directionalLight)

        // Add a second light from the side
        let sideLight = SCNNode()
        sideLight.light = SCNLight()
        sideLight.light!.type = .omni
        sideLight.light!.intensity = 800
        sideLight.position = SCNVector3(x: -100, y: 50, z: 50)
        scene.rootNode.addChildNode(sideLight)
    }

    private func setupGround() {
        // Add a subtle ground plane for visual reference
        let ground = SCNFloor()
        ground.firstMaterial?.diffuse.contents = UIColor(white: 0.2, alpha: 1.0)
        ground.reflectivity = 0.1
        let groundNode = SCNNode(geometry: ground)
        groundNode.position = SCNVector3(x: 0, y: 0, z: 0)
        scene.rootNode.addChildNode(groundNode)
    }

    func loadCharacter() {
        guard let modelScene = SCNScene(named: "art.scnassets/character.dae") else {
            print("ERROR: Model not found")
            return
        }

        characterNode = SCNNode()
        for child in modelScene.rootNode.childNodes {
            characterNode.addChildNode(child)
        }

        // CRITICAL FIX: Remove all animations that could interfere with manual joint control
        // The DAE file contains baked animations that override euler angle modifications
        characterNode.enumerateChildNodes { (node, _) in
            node.removeAllAnimations()
            node.removeAllActions()
        }
        print("✅ Removed all animations from character model")

        scene.rootNode.addChildNode(characterNode)
        print("✅ Character loaded successfully")

        applyBodyPartColors()
        cacheBoneNodes()
    }

    func applyBodyPartColors() {
        characterNode.enumerateChildNodes { (node, _) in
            guard let geometry = node.geometry else { return }

            let name = node.name ?? ""
            var color: UIColor?

            if name.contains("Arm") || name.contains("Hand") || name.contains("Shoulder") {
                color = UIColor.systemBlue
            } else if name.contains("Leg") || name.contains("Foot") || name.contains("Toe") {
                color = UIColor.systemGreen
            } else if name.contains("Spine") || name.contains("Hips") || name.contains("Head")
                || name.contains("Neck")
            {
                color = UIColor.systemOrange
            }

            if let color = color {
                for material in geometry.materials {
                    material.diffuse.contents = color
                }
            }
        }
        print("🎨 Body part colors applied")
    }

    func cacheBoneNodes() {
        // Debug: Print ALL node names to identify bone structure
        print("🔍 === DEBUGGING: All nodes in character model ===")
        var allNodeNames: [String] = []
        characterNode.enumerateChildNodes { (node, _) in
            if let name = node.name, !name.isEmpty {
                allNodeNames.append(name)
            }
        }
        // Sort and print for easier reading
        allNodeNames.sort()
        for name in allNodeNames {
            print("   - \(name)")
        }
        print("🔍 === Total nodes found: \(allNodeNames.count) ===\n")

        // Cache all the joints we'll be accessing frequently
        let allJoints =
            controllableJoints + [
                "mixamorig_LeftToeBase", "mixamorig_RightToeBase",
            ]

        var foundJoints = 0
        var missingJoints: [String] = []

        for jointName in allJoints {
            if let node = characterNode.childNode(withName: jointName, recursively: true) {
                cachedBoneNodes[jointName] = node
                foundJoints += 1
            } else {
                missingJoints.append(jointName)
            }
        }

        if !missingJoints.isEmpty {
            print("⚠️ Missing expected joints:")
            for missing in missingJoints {
                print("   ❌ \(missing)")
            }
        }
        print("✅ Found \(foundJoints)/\(allJoints.count) expected joints")

        // Cache all nodes for COM calculation
        characterNode.enumerateChildNodes { [weak self] (node, _) in
            if let name = node.name {
                self?.cachedBoneNodes[name] = node
            }
        }

        print("✅ Cached \(cachedBoneNodes.count) total bone nodes")
    }

    func findBone(named name: String) -> SCNNode? {
        // Use cached node if available, otherwise search
        if let cachedNode = cachedBoneNodes[name] {
            return cachedNode
        }
        // Fallback to search if not cached (and cache it for next time)
        if let node = characterNode.childNode(withName: name, recursively: true) {
            cachedBoneNodes[name] = node
            return node
        }
        return nil
    }

    func frameCharacter() {
        guard let cameraNode = sceneView.pointOfView else { return }

        let (min, max) = characterNode.boundingBox
        let center = SCNVector3((min.x + max.x) / 2, (min.y + max.y) / 2, (min.z + max.z) / 2)
        let characterHeight = max.y - min.y

        cameraNode.position = SCNVector3(
            center.x, center.y, center.z + Float(characterHeight) * 1.5)
        cameraNode.look(at: center)
        print("✅ Character automatically framed.")
    }
}
