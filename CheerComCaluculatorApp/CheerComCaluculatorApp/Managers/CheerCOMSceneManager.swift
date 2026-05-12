import SceneKit
import UIKit



class CheerCOMSceneManager {
    var sceneView: SCNView!
    var scene: SCNScene!
    var characterNode: SCNNode!
    var cachedBoneNodes: [String: SCNNode] = [:]
    var feetAndToes = Set<SCNNode>()

    // List of controllable joints (in order from root to extremities)
    let controllableJoints: [Joint] = [
        .hips,
        .spine,
        .spine1,
        .spine2,
        .neck,
        .head,
        .rightShoulder,
        .rightArm,
        .rightForeArm,
        .rightHand,
        .leftShoulder,
        .leftArm,
        .leftForeArm,
        .leftHand,
        .rightUpLeg,
        .rightLeg,
        .rightFoot,
        .leftUpLeg,
        .leftLeg,
        .leftFoot,
    ]

    /// Returns a Joint-keyed dictionary of cached bone nodes suitable for COMCalculator.bind().
    var jointNodeMap: [Joint: SCNNode] {
        var map: [Joint: SCNNode] = [:]
        for joint in Joint.allCases {
            if let node = cachedBoneNodes[joint.rawValue] {
                map[joint] = node
            }
        }
        return map
    }

    init(view: UIView) {
        setupScene(in: view)
    }

    private func setupScene(in view: UIView) {
        // Create scene view
        sceneView = SCNView(frame: view.bounds)
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sceneView.isOpaque = false
        sceneView.backgroundColor = .clear
        sceneView.antialiasingMode = .multisampling4X
        view.addSubview(sceneView)

        // Create scene
        scene = SCNScene()
        sceneView.scene = scene

        // Enable free camera controls
        sceneView.allowsCameraControl = true
        scene.background.contents = UIColor.clear

        // Show statistics (FPS, etc)
        sceneView.showsStatistics = false

        print("Scene view frame: \(view.bounds)")

        setupLighting()
        setupGround()
    }

    private func setupLighting() {
        // Add lights with a cooler studio palette so the 3D view matches the new chrome.
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light!.type = .ambient
        ambientLight.light!.color = UIColor(hex: 0xA3B7C8)
        ambientLight.light!.intensity = 900
        scene.rootNode.addChildNode(ambientLight)

        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light!.type = .directional
        directionalLight.light!.color = UIColor(hex: 0xFFF3D0)
        directionalLight.light!.intensity = 1500
        directionalLight.position = SCNVector3(x: 0, y: 100, z: 100)
        directionalLight.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(directionalLight)

        // Add a side rim light for depth.
        let sideLight = SCNNode()
        sideLight.light = SCNLight()
        sideLight.light!.type = .omni
        sideLight.light!.color = UIColor(hex: 0x66C7FF)
        sideLight.light!.intensity = 800
        sideLight.position = SCNVector3(x: -100, y: 50, z: 50)
        scene.rootNode.addChildNode(sideLight)
    }

    private func setupGround() {
        // Add a subtle ground plane for visual reference
        let ground = SCNFloor()
        ground.firstMaterial?.diffuse.contents = UIColor(hex: 0x13273D, alpha: 0.92)
        ground.firstMaterial?.specular.contents = UIColor.white.withAlphaComponent(0.08)
        ground.reflectivity = 0.06
        let groundNode = SCNNode(geometry: ground)
        groundNode.position = SCNVector3(x: 0, y: 0, z: 0)
        scene.rootNode.addChildNode(groundNode)
    }

    func loadCharacter() {
        guard let modelScene = SCNScene(named: "art.scnassets/character.dae") else {
            print("ERROR: Model not found")
            return
        }

        // CRITICAL FIX: Remove all animations from the source scene root
        stripAnimations(from: modelScene.rootNode)

        characterNode = SCNNode()
        for child in modelScene.rootNode.childNodes {
            characterNode.addChildNode(child)
        }

        // Remove animations from the character hierarchy
        stripAnimations(from: characterNode)
        print("Removed all animations from character model and source scene")

        scene.rootNode.addChildNode(characterNode)
        print("Character loaded successfully")

        applyBodyPartColors()
        cacheBoneNodes()
    }

    /// Recursively removes animations, actions, constraints, and physics bodies from a node and its hierarchy.
    private func stripAnimations(from node: SCNNode) {
        node.removeAllAnimations()
        node.removeAllActions()
        node.constraints = nil
        node.physicsBody = nil

        if let geometry = node.geometry {
            geometry.removeAllAnimations()
            for material in geometry.materials {
                material.removeAllAnimations()
            }
        }

        if let morpher = node.morpher {
            morpher.removeAllAnimations()
        }

        for child in node.childNodes {
            stripAnimations(from: child)
        }
    }

    func applyBodyPartColors() {
        characterNode.enumerateChildNodes { (node, _) in
            guard let geometry = node.geometry else { return }

            let name = node.name ?? ""
            var color: UIColor?

            if name.contains("Arm") || name.contains("Hand") || name.contains("Shoulder") {
                color = UIColor(hex: 0x56C2FF)
            } else if name.contains("Leg") || name.contains("Foot") || name.contains("Toe") {
                color = UIColor(hex: 0x72E5A0)
            } else if name.contains("Spine") || name.contains("Hips") || name.contains("Head")
                || name.contains("Neck")
            {
                color = UIColor(hex: 0xFFB65C)
            }

            if let color = color {
                for material in geometry.materials {
                    material.diffuse.contents = color
                    material.specular.contents = UIColor.white.withAlphaComponent(0.12)
                }
            }
        }
        print("Body part colors applied")
    }

    func cacheBoneNodes() {
        // Cache all the joints we'll be accessing frequently
        // Performance Fix: Avoid multiple array allocations from map + concat
        let manualJoints = [
            Joint.leftToeBase.rawValue, Joint.rightToeBase.rawValue,
            Joint.leftHandMiddle1.rawValue, Joint.rightHandMiddle1.rawValue,
        ]
        var allJointStrings: [String] = []
        allJointStrings.reserveCapacity(controllableJoints.count + manualJoints.count)

        for joint in controllableJoints {
            allJointStrings.append(joint.rawValue)
        }
        allJointStrings.append(contentsOf: manualJoints)

        var foundJoints = 0
        var missingJoints: [String] = []

        for jointName in allJointStrings {
            if let node = characterNode.childNode(withName: jointName, recursively: true) {
                cachedBoneNodes[jointName] = node
                foundJoints += 1
            } else {
                missingJoints.append(jointName)
            }
        }

        if !missingJoints.isEmpty {
            print("Missing expected joints:")
            for missing in missingJoints {
                print("   \(missing)")
            }
        }
        print("Found \(foundJoints)/\(allJointStrings.count) expected joints")

        // Cache all nodes for COM calculation
        characterNode.enumerateChildNodes { [weak self] (node, _) in
            if let name = node.name {
                self?.cachedBoneNodes[name] = node
            }
        }

        for (name, node) in cachedBoneNodes {
            if name.contains("Foot") || name.contains("Toe") {
                feetAndToes.insert(node)
            }
        }

        print("Cached \(cachedBoneNodes.count) total bone nodes")
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

    func findBone(_ joint: Joint) -> SCNNode? {
        return findBone(named: joint.rawValue)
    }

    func frameCharacter() {
        guard let cameraNode = sceneView.pointOfView else { return }

        let (min, max) = characterNode.boundingBox
        let center = SCNVector3((min.x + max.x) / 2, (min.y + max.y) / 2, (min.z + max.z) / 2)
        let characterHeight = max.y - min.y

        cameraNode.position = SCNVector3(
            center.x, center.y, center.z + Float(characterHeight) * 1.5)
        cameraNode.look(at: center)
        print("Character automatically framed.")
    }
}
