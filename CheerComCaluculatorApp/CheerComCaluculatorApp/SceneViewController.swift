import UIKit
import SceneKit

class SceneViewController: UIViewController {
    
    var sceneView: SCNView!
    var scene: SCNScene!
    var characterNode: SCNNode!
    var comMarker: SCNNode!
    var calculator: COMCalculator!
    
    // UI Controls
    var comLabel: UILabel!
    var xLabel: UILabel!
    var yLabel: UILabel!
    var zLabel: UILabel!
    
    // COM Trail
    var comTrailNode: SCNNode!
    var trailPositions: [SCNVector3] = []
    let maxTrailPoints = 50
    
    // Camera views
    var cameraNode: SCNNode!
    var currentCameraIndex = 0
    let cameraPositions: [(position: SCNVector3, lookAt: SCNVector3, name: String)] = [
        (SCNVector3(x: 0, y: 100, z: 300), SCNVector3(x: 0, y: 100, z: 0), "Front"),
        (SCNVector3(x: 220, y: 90, z: 0), SCNVector3(x: 0, y: 90, z: 0), "Right"),
        (SCNVector3(x: 0, y: 90, z: -220), SCNVector3(x: 0, y: 90, z: 0), "Back"),
        (SCNVector3(x: -220, y: 90, z: 0), SCNVector3(x: 0, y: 90, z: 0), "Left"),
        (SCNVector3(x: 0, y: 300, z: 0), SCNVector3(x: 0, y: 0, z: 0), "Top")
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("🚀 SceneViewController loaded")
        
        setupScene()
        loadCharacter()
        applyBodyPartColors()
        setupCOMMarker()
        setupCOMTrail()
        setupUI()
        setupGestures()
        
        // Initialize calculator (52.2 kg = 115 lbs)
        calculator = COMCalculator(bodyMass: 52.2)
        
        print("✅ Scene setup complete")
        
        // Test liberty pose after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.applyLiberty()
        }
    }
    
    func setupScene() {
        // Create scene view
        sceneView = SCNView(frame: view.bounds)
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(sceneView)
        
        // Create scene
        scene = SCNScene()
        sceneView.scene = scene
        
        // Disable free camera controls - we'll use fixed positions
        sceneView.allowsCameraControl = false
        sceneView.backgroundColor = UIColor(white: 0.15, alpha: 1.0)  // Dark gray background
        
        // Show statistics (FPS, etc)
        sceneView.showsStatistics = true
        
        print("📷 Scene view frame: \(view.bounds)")
        
        // Add camera with fixed positions
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        let initialPos = cameraPositions[0]
        cameraNode.position = initialPos.position
        cameraNode.look(at: initialPos.lookAt)
        scene.rootNode.addChildNode(cameraNode)
        
        print("📷 Camera positioned at: \(initialPos.name)")
        
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
            print("Please add a character.dae file to art.scnassets folder")
            print("Download from mixamo.com as COLLADA (.dae)")
            return
        }
        
        // Use the entire root node to get BOTH the mesh AND the skeleton
        // In COLLADA files, they are typically separate sibling nodes
        characterNode = SCNNode()
        for child in modelScene.rootNode.childNodes {
            characterNode.addChildNode(child)
        }
        
        scene.rootNode.addChildNode(characterNode)
        
        // Print character info
        print("=== CHARACTER INFO ===")
        let (min, max) = characterNode.boundingBox
        print("Bounding box: min(\(min.x), \(min.y), \(min.z)) max(\(max.x), \(max.y), \(max.z))")
        print("Position: \(characterNode.position)")
        print("Scale: \(characterNode.scale)")
        print("✅ Character loaded successfully")
        print("======================")
    }
    
    func printBones(_ node: SCNNode, indent: Int = 0) {
        let prefix = String(repeating: "  ", count: indent)
        print("\(prefix)Bone: \(node.name ?? "unnamed")")
        for child in node.childNodes {
            printBones(child, indent: indent + 1)
        }
    }
    
    func setupCOMMarker() {
        // Create red sphere for COM visualization - bright and always visible
        let sphere = SCNSphere(radius: 8)
        sphere.firstMaterial?.diffuse.contents = UIColor.red
        sphere.firstMaterial?.emission.contents = UIColor.red.withAlphaComponent(0.5)
        sphere.firstMaterial?.lightingModel = .constant  // Always visible, no lighting needed
        
        comMarker = SCNNode(geometry: sphere)
        scene.rootNode.addChildNode(comMarker)
        
        print("🔴 COM marker created")
    }
    
    func setupCOMTrail() {
        comTrailNode = SCNNode()
        scene.rootNode.addChildNode(comTrailNode)
        print("🔵 COM trail initialized")
    }
    
    func setupUI() {
        // Background panel
        let panel = UIView(frame: CGRect(x: 20, y: 60, width: 200, height: 140))
        panel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        panel.layer.cornerRadius = 10
        
        // COM header label
        comLabel = UILabel(frame: CGRect(x: 10, y: 10, width: 180, height: 25))
        comLabel.text = "Center of Mass"
        comLabel.textColor = .white
        comLabel.font = .boldSystemFont(ofSize: 16)
        comLabel.textAlignment = .center
        panel.addSubview(comLabel)
        
        // X coordinate label
        xLabel = UILabel(frame: CGRect(x: 10, y: 40, width: 180, height: 25))
        xLabel.text = "X: 0.00 cm"
        xLabel.textColor = .white
        xLabel.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        panel.addSubview(xLabel)
        
        // Y coordinate label
        yLabel = UILabel(frame: CGRect(x: 10, y: 70, width: 180, height: 25))
        yLabel.text = "Y: 0.00 cm"
        yLabel.textColor = .white
        yLabel.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        panel.addSubview(yLabel)
        
        // Z coordinate label
        zLabel = UILabel(frame: CGRect(x: 10, y: 100, width: 180, height: 25))
        zLabel.text = "Z: 0.00 cm"
        zLabel.textColor = .white
        zLabel.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        panel.addSubview(zLabel)
        
        view.addSubview(panel)
        print("📊 UI panel created")
    }
    
    func applyBodyPartColors() {
        characterNode.enumerateChildNodes { (node, _) in
            guard let geometry = node.geometry else { return }
            
            let name = node.name ?? ""
            var color: UIColor?
            
            // Arms - Blue
            if name.contains("Arm") || name.contains("Hand") || name.contains("Shoulder") {
                color = UIColor.systemBlue
            }
            // Legs - Green
            else if name.contains("Leg") || name.contains("Foot") || name.contains("Toe") {
                color = UIColor.systemGreen
            }
            // Torso/Head - Orange
            else if name.contains("Spine") || name.contains("Hips") || name.contains("Head") || name.contains("Neck") {
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
    
    func setupGestures() {
        // Left swipe - next camera view
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeLeft.direction = .left
        view.addGestureRecognizer(swipeLeft)
        
        // Right swipe - previous camera view
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)
        
        print("👆 Swipe gestures enabled")
    }
    
    @objc func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        if gesture.direction == .left {
            // Next camera view
            currentCameraIndex = (currentCameraIndex + 1) % cameraPositions.count
        } else if gesture.direction == .right {
            // Previous camera view
            currentCameraIndex = (currentCameraIndex - 1 + cameraPositions.count) % cameraPositions.count
        }
        
        switchToCamera(index: currentCameraIndex)
    }
    
    func switchToCamera(index: Int) {
        let newPos = cameraPositions[index]
        
        // Animate camera transition
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        cameraNode.position = newPos.position
        cameraNode.look(at: newPos.lookAt)
        
        SCNTransaction.commit()
        
        print("📷 Switched to: \(newPos.name)")
    }
    
    func updateCOM() {
        var jointPositions: [String: SCNVector3] = [:]
        getBonePositions(characterNode, into: &jointPositions)
        
        let com = calculator.calculateBodyCOM(jointPositions: jointPositions)
        comMarker.position = com
        
        // Update UI labels
        xLabel.text = String(format: "X: %.2f cm", com.x)
        yLabel.text = String(format: "Y: %.2f cm", com.y)
        zLabel.text = String(format: "Z: %.2f cm", com.z)
        
        // Add to trail
        trailPositions.append(com)
        if trailPositions.count > maxTrailPoints {
            trailPositions.removeFirst()
        }
        
        updateTrailVisualization()
        
        print(String(format: "COM: (%.3f, %.3f, %.3f)", com.x, com.y, com.z))
    }
    
    func updateTrailVisualization() {
        // Remove old trail geometry
        comTrailNode.childNodes.forEach { $0.removeFromParentNode() }
        
        // Create spheres connecting trail points
        for (i, pos) in trailPositions.enumerated() {
            let alpha = Float(i) / Float(trailPositions.count)
            let sphere = SCNSphere(radius: 2)
            sphere.firstMaterial?.diffuse.contents = UIColor.cyan.withAlphaComponent(CGFloat(alpha))
            sphere.firstMaterial?.lightingModel = .constant
            
            let node = SCNNode(geometry: sphere)
            node.position = pos
            comTrailNode.addChildNode(node)
        }
    }
    
    func getBonePositions(_ node: SCNNode, into dict: inout [String: SCNVector3]) {
        if let name = node.name {
            dict[name] = node.worldPosition
        }
        for child in node.childNodes {
            getBonePositions(child, into: &dict)
        }
    }
    
    func findBone(named name: String) -> SCNNode? {
        return characterNode.childNode(withName: name, recursively: true)
    }
    
    // MARK: - Pose Functions
    
    @objc func applyLiberty() {
        print("Applying Liberty pose...")
        
        // Rotate right leg up to 90 degrees
        if let rightUpLeg = findBone(named: "mixamorig_RightUpLeg") {
            rightUpLeg.eulerAngles.z = -.pi / 2  // -90 degrees
            print("✓ Right leg rotated")
        } else {
            print("⚠️ Warning: Bone 'mixamorig_RightUpLeg' not found")
        }
        
        // Update COM after pose change
        updateCOM()
    }
    
    @objc func applyScale() {
        print("Applying Scale pose...")
        
        // Both legs up
        if let rightUpLeg = findBone(named: "mixamorig_RightUpLeg") {
            rightUpLeg.eulerAngles.z = -.pi / 2
        }
        if let leftUpLeg = findBone(named: "mixamorig_LeftUpLeg") {
            leftUpLeg.eulerAngles.z = .pi / 2
        }
        
        updateCOM()
    }
    
    @objc func resetPose() {
        print("Resetting pose...")
        
        // Reset all rotations (would need to store original rotations)
        if let rightUpLeg = findBone(named: "mixamorig_RightUpLeg") {
            rightUpLeg.eulerAngles = SCNVector3Zero
        }
        if let leftUpLeg = findBone(named: "mixamorig_LeftUpLeg") {
            leftUpLeg.eulerAngles = SCNVector3Zero
        }
        
        updateCOM()
    }
}

