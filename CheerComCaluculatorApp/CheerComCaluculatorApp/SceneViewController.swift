import UIKit
import SceneKit

class SceneViewController: UIViewController {
    
    var sceneView: SCNView!
    var scene: SCNScene!
    var characterNode: SCNNode!
    var comMarker: SCNNode!
    var calculator: COMCalculator!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("🚀 SceneViewController loaded")
        
        setupScene()
        loadCharacter()
        setupCOMMarker()
        
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
        
        // Enable camera controls (FREE orbit/zoom/pan with touch!)
        sceneView.allowsCameraControl = true
        sceneView.backgroundColor = UIColor(white: 0.15, alpha: 1.0)  // Dark gray background
        
        // Show statistics (FPS, etc)
        sceneView.showsStatistics = true
        
        print("📷 Scene view frame: \(view.bounds)")
        
        // Add camera - positioned to see full character nicely framed
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 90, z: 220)  // Back and slightly elevated
        cameraNode.look(at: SCNVector3(x: 0, y: 90, z: 0))  // Look at character's center of mass area
        scene.rootNode.addChildNode(cameraNode)
        
        print("📷 Camera positioned")
        
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
    
    func updateCOM() {
        var jointPositions: [String: SCNVector3] = [:]
        getBonePositions(characterNode, into: &jointPositions)
        
        let com = calculator.calculateBodyCOM(jointPositions: jointPositions)
        comMarker.position = com
        
        print(String(format: "COM: (%.3f, %.3f, %.3f)", com.x, com.y, com.z))
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

