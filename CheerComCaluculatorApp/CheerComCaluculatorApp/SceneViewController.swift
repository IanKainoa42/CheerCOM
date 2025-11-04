import SceneKit
import UIKit

class SceneViewController: UIViewController {

    var sceneView: SCNView!
    var scene: SCNScene!
    var characterNode: SCNNode!
    var comMarker: SCNNode!
    var calculator: COMCalculator!

    // Performance optimization
    private var updateTimer: Timer?
    private var needsCOMUpdate = false
    private let updateInterval: TimeInterval = 0.016  // ~60 FPS
    private var cachedBoneNodes: [String: SCNNode] = [:]
    private let calculationQueue = DispatchQueue(
        label: "com.cheercom.calculation", qos: .userInteractive)

    // Continuous control support
    private var continuousRotationTimer: Timer?
    private var currentRotationDirection: RotationDirection?
    private enum RotationDirection {
        case positive, negative
    }
    private var activeButtons: Set<UIButton> = []

    // UI Controls
    var comLabel: UILabel!
    var xLabel: UILabel!
    var yLabel: UILabel!
    var zLabel: UILabel!
    var viewLabel: UILabel!  // Shows current camera view
    var transformModeLabel: UILabel!  // Shows current transform mode

    // Transform modes
    enum TransformMode {
        case position, rotation, scale
    }
    var currentTransformMode: TransformMode = .position
    var transformStep: Float = 5.0  // Units for position/rotation adjustments

    // Joint control
    var selectedJoint: SCNNode?
    var jointSelectionButton: UIButton!
    var jointControlMode: JointAxis = .x
    var jointAngleSlider: UISlider!
    var jointAngleLabel: UILabel!

    enum JointAxis: String {
        case x = "X-Axis"
        case y = "Y-Axis"
        case z = "Z-Axis"
    }

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

    // COM Trail
    var comTrailNode: SCNNode!
    var trailPositions: [SCNVector3] = []
    let maxTrailPoints = 50

    // Camera views
    var cameraNode: SCNNode!
    var currentCameraIndex = 0
    let cameraPositions: [(position: SCNVector3, lookAt: SCNVector3, name: String)] = [
        (SCNVector3(x: 0, y: 90, z: 220), SCNVector3(x: 0, y: 90, z: 0), "Front"),
        (SCNVector3(x: 220, y: 90, z: 0), SCNVector3(x: 0, y: 90, z: 0), "Right"),
        (SCNVector3(x: 0, y: 90, z: -220), SCNVector3(x: 0, y: 90, z: 0), "Back"),
        (SCNVector3(x: -220, y: 90, z: 0), SCNVector3(x: 0, y: 90, z: 0), "Left"),
        (SCNVector3(x: 0, y: 300, z: 0), SCNVector3(x: 0, y: 0, z: 0), "Top"),
    ]

    // Advanced Visualizations
    var gravityLineNode: SCNNode!
    var bosNode: SCNNode!
    var gridNode: SCNNode!
    var showAdvancedVisualizations = false

    override func viewDidLoad() {
        super.viewDidLoad()

        print("🚀 SceneViewController loaded")

        setupScene()
        loadCharacter()

        // Automatically frame the character after it's loaded.
        let (min, max) = characterNode.boundingBox
        let center = SCNVector3((min.x + max.x) / 2, (min.y + max.y) / 2, (min.z + max.z) / 2)
        let characterHeight = max.y - min.y

        if let cameraNode = sceneView.pointOfView {
            cameraNode.position = SCNVector3(
                center.x, center.y, center.z + Float(characterHeight) * 1.5)
            cameraNode.look(at: center)
            print("✅ Character automatically framed.")
        }

        applyBodyPartColors()
        setupCOMMarker()
        setupCOMTrail()
        setupUI()
        setupGestures()
        setupVisualAids()

        // Initialize calculator (52.2 kg = 115 lbs)
        calculator = COMCalculator(bodyMass: 52.2)

        // Cache all bone nodes for faster lookup
        cacheBoneNodes()

        // Start the update timer
        startUpdateTimer()

        // Initialize COM in default pose
        scheduleUpdateCOM()

        print("✅ Scene setup complete")
    }

    func cacheBoneNodes() {
        // Cache all the joints we'll be accessing frequently
        let allJoints =
            controllableJoints + [
                "mixamorig_LeftToeBase", "mixamorig_RightToeBase",
            ]

        for jointName in allJoints {
            if let node = characterNode.childNode(withName: jointName, recursively: true) {
                cachedBoneNodes[jointName] = node
            }
        }

        // Cache all nodes for COM calculation
        characterNode.enumerateChildNodes { [weak self] (node, _) in
            if let name = node.name {
                self?.cachedBoneNodes[name] = node
            }
        }

        print("✅ Cached \(cachedBoneNodes.count) bone nodes")
    }

    func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) {
            [weak self] _ in
            guard let self = self else { return }
            if self.needsCOMUpdate {
                self.needsCOMUpdate = false
                self.performCOMUpdate()
            }
        }
        updateTimer?.tolerance = 0.002  // 2ms tolerance for better battery life
        print("⏱️ Update timer started")
    }

    func scheduleUpdateCOM() {
        needsCOMUpdate = true
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

        // Adjust clipping planes to prevent model clipping
        cameraNode.camera!.zNear = 1.0  // Very close objects visible
        cameraNode.camera!.zFar = 1000.0  // Far objects visible

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
            return
        }

        characterNode = SCNNode()
        for child in modelScene.rootNode.childNodes {
            characterNode.addChildNode(child)
        }

        scene.rootNode.addChildNode(characterNode)

        print("✅ Character loaded successfully")
    }

    func setupCOMMarker() {
        let sphere = SCNSphere(radius: 8)
        sphere.firstMaterial?.diffuse.contents = UIColor.red
        sphere.firstMaterial?.emission.contents = UIColor.red.withAlphaComponent(0.5)
        sphere.firstMaterial?.lightingModel = .constant

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
        // Top-left: COM coordinate panel
        let comPanel = UIView(frame: CGRect(x: 20, y: 60, width: 200, height: 140))
        comPanel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        comPanel.layer.cornerRadius = 10

        // COM header label
        comLabel = UILabel(frame: CGRect(x: 10, y: 10, width: 180, height: 25))
        comLabel.text = "Center of Mass"
        comLabel.textColor = .white
        comLabel.font = .boldSystemFont(ofSize: 16)
        comLabel.textAlignment = .center
        comPanel.addSubview(comLabel)

        // X coordinate label
        xLabel = UILabel(frame: CGRect(x: 10, y: 40, width: 180, height: 25))
        xLabel.text = "X: 0.00 cm"
        xLabel.textColor = .white
        xLabel.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        comPanel.addSubview(xLabel)

        // Y coordinate label
        yLabel = UILabel(frame: CGRect(x: 10, y: 70, width: 180, height: 25))
        yLabel.text = "Y: 0.00 cm"
        yLabel.textColor = .white
        yLabel.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        comPanel.addSubview(yLabel)

        // Z coordinate label
        zLabel = UILabel(frame: CGRect(x: 10, y: 100, width: 180, height: 25))
        zLabel.text = "Z: 0.00 cm"
        zLabel.textColor = .white
        zLabel.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        comPanel.addSubview(zLabel)

        view.addSubview(comPanel)

        // Top-right: Camera view label
        viewLabel = UILabel(
            frame: CGRect(x: view.bounds.width - 120, y: 60, width: 100, height: 40))
        viewLabel.text = "Front"
        viewLabel.textColor = .white
        viewLabel.font = .boldSystemFont(ofSize: 18)
        viewLabel.textAlignment = .center
        viewLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        viewLabel.layer.cornerRadius = 10
        viewLabel.layer.masksToBounds = true
        viewLabel.autoresizingMask = [.flexibleLeftMargin]
        view.addSubview(viewLabel)

        // Bottom: Control panel (made taller for joint controls)
        let controlHeight: CGFloat = 180
        let controlPanel = UIView(
            frame: CGRect(
                x: 0, y: view.bounds.height - controlHeight, width: view.bounds.width,
                height: controlHeight))
        controlPanel.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        controlPanel.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        view.addSubview(controlPanel)

        // Pose buttons
        let buttonWidth: CGFloat = 80
        let buttonSpacing: CGFloat = 10
        let row1Y: CGFloat = 10
        let row2Y: CGFloat = 55
        let row3Y: CGFloat = 100
        let row4Y: CGFloat = 135

        // Row 1: Joint Selection
        let jointLabelWidth: CGFloat = 100
        let jointLabel = UILabel(frame: CGRect(x: 10, y: row1Y, width: jointLabelWidth, height: 35))
        jointLabel.text = "Joint Control:"
        jointLabel.textColor = .white
        jointLabel.font = .boldSystemFont(ofSize: 14)
        jointLabel.textAlignment = .left
        controlPanel.addSubview(jointLabel)

        jointSelectionButton = UIButton(
            frame: CGRect(x: jointLabelWidth + 15, y: row1Y, width: 180, height: 35))
        jointSelectionButton.setTitle("Select Joint...", for: .normal)
        jointSelectionButton.setTitleColor(.white, for: .normal)
        jointSelectionButton.titleLabel?.font = .boldSystemFont(ofSize: 13)
        jointSelectionButton.backgroundColor = UIColor.systemTeal.withAlphaComponent(0.8)
        jointSelectionButton.layer.cornerRadius = 8
        jointSelectionButton.contentHorizontalAlignment = .center
        jointSelectionButton.addTarget(
            self, action: #selector(showJointSelectionMenu), for: .touchUpInside)
        controlPanel.addSubview(jointSelectionButton)

        // Joint axis buttons (X, Y, Z)
        let xAxisBtn = createButton(
            title: "X", x: jointLabelWidth + 200, y: row1Y, width: 35, height: 35,
            action: #selector(selectXAxis))
        xAxisBtn.backgroundColor = UIColor.systemRed.withAlphaComponent(0.9)
        controlPanel.addSubview(xAxisBtn)

        let yAxisBtn = createButton(
            title: "Y", x: jointLabelWidth + 240, y: row1Y, width: 35, height: 35,
            action: #selector(selectYAxis))
        yAxisBtn.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.6)
        controlPanel.addSubview(yAxisBtn)

        let zAxisBtn = createButton(
            title: "Z", x: jointLabelWidth + 280, y: row1Y, width: 35, height: 35,
            action: #selector(selectZAxis))
        zAxisBtn.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.6)
        controlPanel.addSubview(zAxisBtn)

        // Row 2: Joint rotation controls
        let jointRotLabel = UILabel(frame: CGRect(x: 10, y: row2Y, width: 100, height: 35))
        jointRotLabel.text = "Rotate Joint:"
        jointRotLabel.textColor = .white
        jointRotLabel.font = .boldSystemFont(ofSize: 14)
        jointRotLabel.textAlignment = .left
        controlPanel.addSubview(jointRotLabel)

        let jointDecBtn = createButton(
            title: "◀ -5°", x: jointLabelWidth + 15, y: row2Y, width: 80, height: 35,
            action: #selector(rotateJointNegative))
        // Add long press for continuous rotation
        jointDecBtn.addTarget(
            self, action: #selector(startContinuousRotationNegative), for: .touchDown)
        jointDecBtn.addTarget(
            self, action: #selector(stopContinuousRotation),
            for: [.touchUpInside, .touchUpOutside, .touchCancel])
        controlPanel.addSubview(jointDecBtn)

        let jointIncBtn = createButton(
            title: "+5° ▶", x: jointLabelWidth + 100, y: row2Y, width: 80, height: 35,
            action: #selector(rotateJointPositive))
        // Add long press for continuous rotation
        jointIncBtn.addTarget(
            self, action: #selector(startContinuousRotationPositive), for: .touchDown)
        jointIncBtn.addTarget(
            self, action: #selector(stopContinuousRotation),
            for: [.touchUpInside, .touchUpOutside, .touchCancel])
        controlPanel.addSubview(jointIncBtn)

        let jointResetBtn = createButton(
            title: "Reset Joint", x: jointLabelWidth + 185, y: row2Y, width: 90, height: 35,
            action: #selector(resetSelectedJoint))
        jointResetBtn.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.8)
        controlPanel.addSubview(jointResetBtn)

        // Angle slider (between row 2 and 3)
        let sliderY = row2Y + 40
        let sliderLabel = UILabel(frame: CGRect(x: 10, y: sliderY, width: 60, height: 25))
        sliderLabel.text = "Angle:"
        sliderLabel.textColor = .white
        sliderLabel.font = .boldSystemFont(ofSize: 12)
        controlPanel.addSubview(sliderLabel)

        jointAngleSlider = UISlider(frame: CGRect(x: 70, y: sliderY, width: 200, height: 25))
        jointAngleSlider.minimumValue = -180
        jointAngleSlider.maximumValue = 180
        jointAngleSlider.value = 0
        jointAngleSlider.tintColor = .systemBlue
        jointAngleSlider.addTarget(
            self, action: #selector(jointAngleSliderChanged), for: .valueChanged)
        controlPanel.addSubview(jointAngleSlider)

        jointAngleLabel = UILabel(frame: CGRect(x: 275, y: sliderY, width: 60, height: 25))
        jointAngleLabel.text = "0°"
        jointAngleLabel.textColor = .white
        jointAngleLabel.font = .monospacedSystemFont(ofSize: 12, weight: .bold)
        jointAngleLabel.textAlignment = .right
        controlPanel.addSubview(jointAngleLabel)

        // Row 3: Pose buttons
        let libertyBtn = createButton(
            title: "Liberty", x: 20, y: row3Y, width: buttonWidth, height: 30,
            action: #selector(applyLiberty))
        controlPanel.addSubview(libertyBtn)

        let scaleBtn = createButton(
            title: "Scale", x: 20 + buttonWidth + buttonSpacing, y: row3Y, width: buttonWidth,
            height: 30, action: #selector(applyScale))
        controlPanel.addSubview(scaleBtn)

        let arabesqueBtn = createButton(
            title: "Arabesque", x: 20 + (buttonWidth + buttonSpacing) * 2, y: row3Y,
            width: buttonWidth, height: 30, action: #selector(applyArabesque))
        controlPanel.addSubview(arabesqueBtn)

        let resetBtn = createButton(
            title: "Reset Pose", x: view.bounds.width - 110, y: row3Y, width: 90, height: 30,
            action: #selector(resetPose))
        resetBtn.backgroundColor = UIColor.systemRed.withAlphaComponent(0.8)
        resetBtn.autoresizingMask = [.flexibleLeftMargin]
        controlPanel.addSubview(resetBtn)

        // Row 4: View controls
        let prevBtn = createButton(
            title: "◀", x: 20, y: row4Y, width: 50, height: 30, action: #selector(previousView))
        controlPanel.addSubview(prevBtn)

        let nextBtn = createButton(
            title: "▶", x: 80, y: row4Y, width: 50, height: 30, action: #selector(nextView))
        controlPanel.addSubview(nextBtn)

        let fitBtn = createButton(
            title: "Fit View", x: view.bounds.width / 2 - 50, y: row4Y, width: 100, height: 30,
            action: #selector(fitToView))
        fitBtn.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.8)
        fitBtn.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin]
        controlPanel.addSubview(fitBtn)

        // Add transform mode label at top right
        transformModeLabel = UILabel(
            frame: CGRect(x: view.bounds.width - 240, y: 110, width: 220, height: 30))
        transformModeLabel.text = "Transform: Position"
        transformModeLabel.textColor = .white
        transformModeLabel.font = .boldSystemFont(ofSize: 16)
        transformModeLabel.textAlignment = .center
        transformModeLabel.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.7)
        transformModeLabel.layer.cornerRadius = 8
        transformModeLabel.layer.masksToBounds = true
        transformModeLabel.autoresizingMask = [.flexibleLeftMargin]
        view.addSubview(transformModeLabel)

        // Add transform control panel (right side)
        let transformPanel = UIView(
            frame: CGRect(x: view.bounds.width - 240, y: 150, width: 220, height: 200))
        transformPanel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        transformPanel.layer.cornerRadius = 10
        transformPanel.autoresizingMask = [.flexibleLeftMargin]
        view.addSubview(transformPanel)

        // Transform mode buttons
        let posTransformBtn = createButton(
            title: "Position", x: 10, y: 10, width: 65, height: 35,
            action: #selector(setPositionMode))
        posTransformBtn.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.9)
        transformPanel.addSubview(posTransformBtn)

        let rotTransformBtn = createButton(
            title: "Rotate", x: 78, y: 10, width: 65, height: 35, action: #selector(setRotationMode)
        )
        rotTransformBtn.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.6)
        transformPanel.addSubview(rotTransformBtn)

        let scaleTransformBtn = createButton(
            title: "Scale", x: 145, y: 10, width: 65, height: 35, action: #selector(setScaleMode))
        scaleTransformBtn.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.6)
        transformPanel.addSubview(scaleTransformBtn)

        // Arrow key-style controls
        let arrowSize: CGFloat = 45
        let centerX: CGFloat = 110
        let centerY: CGFloat = 100

        // Up arrow
        let upBtn = createButton(
            title: "↑", x: centerX - arrowSize / 2, y: centerY - arrowSize - 5, width: arrowSize,
            height: arrowSize, action: #selector(transformUp))
        upBtn.titleLabel?.font = .systemFont(ofSize: 24)
        transformPanel.addSubview(upBtn)

        // Down arrow
        let downBtn = createButton(
            title: "↓", x: centerX - arrowSize / 2, y: centerY + 5, width: arrowSize,
            height: arrowSize, action: #selector(transformDown))
        downBtn.titleLabel?.font = .systemFont(ofSize: 24)
        transformPanel.addSubview(downBtn)

        // Left arrow
        let leftBtn = createButton(
            title: "←", x: centerX - arrowSize - arrowSize / 2 - 5, y: centerY - arrowSize / 2,
            width: arrowSize, height: arrowSize, action: #selector(transformLeft))
        leftBtn.titleLabel?.font = .systemFont(ofSize: 24)
        transformPanel.addSubview(leftBtn)

        // Right arrow
        let rightBtn = createButton(
            title: "→", x: centerX + arrowSize / 2 + 5, y: centerY - arrowSize / 2,
            width: arrowSize, height: arrowSize, action: #selector(transformRight))
        rightBtn.titleLabel?.font = .systemFont(ofSize: 24)
        transformPanel.addSubview(rightBtn)

        // Reset transform button
        let resetTransformBtn = createButton(
            title: "Reset Position", x: 10, y: 155, width: 200, height: 35,
            action: #selector(resetTransform))
        resetTransformBtn.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.8)
        transformPanel.addSubview(resetTransformBtn)

        print("📊 UI controls created")
    }

    func createButton(
        title: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, action: Selector
    ) -> UIButton {
        let button = UIButton(frame: CGRect(x: x, y: y, width: width, height: height))
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 14)
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: action, for: .touchUpInside)

        // Add visual feedback on touch
        button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        button.addTarget(
            self, action: #selector(buttonTouchUp(_:)),
            for: [.touchUpInside, .touchUpOutside, .touchCancel])

        return button
    }

    @objc func buttonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.05) {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            sender.alpha = 1.0
        }
    }

    @objc func buttonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = .identity
        }
    }

    func setupVisualAids() {
        // Gravity Line
        let line = SCNCylinder(radius: 0.5, height: 1.0)
        line.firstMaterial?.diffuse.contents = UIColor.red
        gravityLineNode = SCNNode(geometry: line)
        gravityLineNode.isHidden = true
        scene.rootNode.addChildNode(gravityLineNode)

        // Base of Support
        bosNode = SCNNode()
        bosNode.isHidden = true
        scene.rootNode.addChildNode(bosNode)

        // Grid
        gridNode = SCNNode()
        let plane1 = SCNPlane(width: 300, height: 300)
        plane1.firstMaterial?.diffuse.contents = UIColor.purple.withAlphaComponent(0.3)
        plane1.firstMaterial?.isDoubleSided = true
        let planeNode1 = SCNNode(geometry: plane1)

        let plane2 = SCNPlane(width: 300, height: 300)
        plane2.firstMaterial?.diffuse.contents = UIColor.purple.withAlphaComponent(0.3)
        plane2.firstMaterial?.isDoubleSided = true
        let planeNode2 = SCNNode(geometry: plane2)
        planeNode2.eulerAngles.y = .pi / 2

        gridNode.addChildNode(planeNode1)
        gridNode.addChildNode(planeNode2)
        gridNode.isHidden = true
        scene.rootNode.addChildNode(gridNode)
    }

    @objc func toggleVisualizations() {
        showAdvancedVisualizations.toggle()

        gravityLineNode.isHidden = !showAdvancedVisualizations
        bosNode.isHidden = !showAdvancedVisualizations
        gridNode.isHidden = !showAdvancedVisualizations

        // Update visualizations if turning on
        if showAdvancedVisualizations {
            updateCOM()
            updateBOS()
        }
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

    // Wrapper for backwards compatibility - schedules update instead of immediate
    func updateCOM() {
        scheduleUpdateCOM()
    }

    // Optimized COM update - runs on timer
    func performCOMUpdate() {
        // Gather positions from cached nodes (much faster than recursive search)
        var jointPositions: [String: SCNVector3] = [:]
        for (name, node) in cachedBoneNodes {
            jointPositions[name] = node.worldPosition
        }

        // Calculate COM (fast calculation, no threading needed for this size)
        let com = calculator.calculateBodyCOM(jointPositions: jointPositions)

        // Update marker and labels on main thread
        comMarker.position = com

        xLabel.text = String(format: "X: %.2f cm", com.x)
        yLabel.text = String(format: "Y: %.2f cm", com.y)
        zLabel.text = String(format: "Z: %.2f cm", com.z)

        // Update trail
        trailPositions.append(com)
        if trailPositions.count > maxTrailPoints {
            trailPositions.removeFirst()
        }
        updateTrailVisualizationOptimized()

        // Update advanced visualizations if needed
        if showAdvancedVisualizations {
            updateGravityLine()
            gridNode.position = SCNVector3(comMarker.position.x, 150, comMarker.position.z)
        }
    }

    func updateGravityLine() {
        let comPosition = comMarker.position

        guard let cylinder = gravityLineNode.geometry as? SCNCylinder else { return }
        cylinder.height = CGFloat(comPosition.y)

        gravityLineNode.position = SCNVector3(comPosition.x, comPosition.y / 2, comPosition.z)
    }

    func updateBOS() {
        bosNode.childNodes.forEach { $0.removeFromParentNode() }

        guard let leftFoot = findBone(named: "mixamorig_LeftFoot"),
            let rightFoot = findBone(named: "mixamorig_RightFoot"),
            let leftToe = findBone(named: "mixamorig_LeftToeBase"),
            let rightToe = findBone(named: "mixamorig_RightToeBase")
        else {
            return
        }

        let lf = SCNVector3(leftFoot.worldPosition.x, 0.1, leftFoot.worldPosition.z)
        let rf = SCNVector3(rightFoot.worldPosition.x, 0.1, rightFoot.worldPosition.z)
        let lt = SCNVector3(leftToe.worldPosition.x, 0.1, leftToe.worldPosition.z)
        let rt = SCNVector3(rightToe.worldPosition.x, 0.1, rightToe.worldPosition.z)

        let path = UIBezierPath()
        path.move(to: CGPoint(x: CGFloat(lf.x), y: CGFloat(lf.z)))
        path.addLine(to: CGPoint(x: CGFloat(rf.x), y: CGFloat(rf.z)))
        path.addLine(to: CGPoint(x: CGFloat(rt.x), y: CGFloat(rt.z)))
        path.addLine(to: CGPoint(x: CGFloat(lt.x), y: CGFloat(lt.z)))
        path.close()

        let shape = SCNShape(path: path, extrusionDepth: 0)
        shape.firstMaterial?.diffuse.contents = UIColor.green.withAlphaComponent(0.5)

        let node = SCNNode(geometry: shape)
        node.eulerAngles.x = -.pi / 2

        bosNode.addChildNode(node)
    }

    func updateTrailVisualization() {
        // Old implementation - kept for compatibility but not used
        comTrailNode.childNodes.forEach { $0.removeFromParentNode() }

        for (i, pos) in trailPositions.enumerated() {
            let alpha = Float(i + 1) / Float(trailPositions.count)
            let sphere = SCNSphere(radius: 2)
            sphere.firstMaterial?.diffuse.contents = UIColor.cyan.withAlphaComponent(CGFloat(alpha))
            sphere.firstMaterial?.lightingModel = .constant

            let node = SCNNode(geometry: sphere)
            node.position = pos
            comTrailNode.addChildNode(node)
        }
    }

    // Optimized trail visualization - reuses existing nodes
    func updateTrailVisualizationOptimized() {
        let currentNodes = comTrailNode.childNodes
        let needed = trailPositions.count
        let existing = currentNodes.count

        // Add new nodes if we need more
        if existing < needed {
            for _ in existing..<needed {
                let sphere = SCNSphere(radius: 2)
                sphere.firstMaterial?.diffuse.contents = UIColor.cyan
                sphere.firstMaterial?.lightingModel = .constant
                let node = SCNNode(geometry: sphere)
                comTrailNode.addChildNode(node)
            }
        }
        // Remove excess nodes if we have too many
        else if existing > needed {
            for i in (needed..<existing).reversed() {
                currentNodes[i].removeFromParentNode()
            }
        }

        // Update positions and alpha for all nodes
        for (i, pos) in trailPositions.enumerated() {
            let node = comTrailNode.childNodes[i]
            node.position = pos

            // Update alpha
            let alpha = Float(i + 1) / Float(trailPositions.count)
            if let material = node.geometry?.firstMaterial {
                material.diffuse.contents = UIColor.cyan.withAlphaComponent(CGFloat(alpha))
            }
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

    // MARK: - Keyboard Support

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let key = presses.first?.key else {
            super.pressesBegan(presses, with: event)
            return
        }

        switch key.keyCode {
        case .keyboardUpArrow:
            transformUp()
        case .keyboardDownArrow:
            transformDown()
        case .keyboardLeftArrow:
            transformLeft()
        case .keyboardRightArrow:
            transformRight()
        case .keyboardSpacebar:
            // Cycle through transform modes with spacebar
            switch currentTransformMode {
            case .position:
                setRotationMode()
            case .rotation:
                setScaleMode()
            case .scale:
                setPositionMode()
            }
        default:
            super.pressesBegan(presses, with: event)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()  // Enable keyboard input
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        resignFirstResponder()
        stopUpdateTimer()
    }

    func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
        print("⏱️ Update timer stopped")
    }

    deinit {
        stopUpdateTimer()
    }

    @objc func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        if gesture.direction == .left {
            // Next camera view
            currentCameraIndex = (currentCameraIndex + 1) % cameraPositions.count
        } else if gesture.direction == .right {
            // Previous camera view
            currentCameraIndex =
                (currentCameraIndex - 1 + cameraPositions.count) % cameraPositions.count
        }

        switchToCamera(index: currentCameraIndex)
    }

    func switchToCamera(index: Int) {
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

        // Update view label
        viewLabel.text = newPos.name

        print("📷 Switched to: \(newPos.name) - Pos: \(newPos.position), LookAt: \(newPos.lookAt)")
    }

    @objc func previousView() {
        currentCameraIndex =
            (currentCameraIndex - 1 + cameraPositions.count) % cameraPositions.count
        switchToCamera(index: currentCameraIndex)
    }

    @objc func nextView() {
        currentCameraIndex = (currentCameraIndex + 1) % cameraPositions.count
        switchToCamera(index: currentCameraIndex)
    }

    @objc func fitToView() {
        // Reset to current camera position (smooth re-center)
        switchToCamera(index: currentCameraIndex)
    }

    // MARK: - Pose Functions

    @objc func applyLiberty() {
        print("Applying Liberty pose...")

        // Rotate right leg up to 90 degrees
        if let rightUpLeg = findBone(named: "mixamorig_RightUpLeg") {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.0

            rightUpLeg.eulerAngles.z = -.pi / 2  // -90 degrees

            SCNTransaction.completionBlock = { [weak self] in
                // Update COM after animation completes and world positions are updated
                self?.updateCOM()
            }
            SCNTransaction.commit()

            print("✓ Right leg rotated to \(rightUpLeg.eulerAngles)")
        } else {
            print("⚠️ Warning: Bone 'mixamorig_RightUpLeg' not found")
        }
    }

    @objc func applyScale() {
        print("Applying Scale pose...")

        // Both legs up
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.0

        if let rightUpLeg = findBone(named: "mixamorig_RightUpLeg") {
            rightUpLeg.eulerAngles.z = -.pi / 2
            print("✓ Right leg up")
        }
        if let leftUpLeg = findBone(named: "mixamorig_LeftUpLeg") {
            leftUpLeg.eulerAngles.z = .pi / 2
            print("✓ Left leg up")
        }

        SCNTransaction.completionBlock = { [weak self] in
            self?.updateCOM()
        }
        SCNTransaction.commit()
    }

    @objc func applyArabesque() {
        print("Applying Arabesque pose...")

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.0

        // Right leg back and up
        if let rightUpLeg = findBone(named: "mixamorig_RightUpLeg") {
            rightUpLeg.eulerAngles.x = .pi / 3  // 60 degrees back
            print("✓ Right leg extended back to \(rightUpLeg.eulerAngles)")
        } else {
            print("⚠️ Warning: Bone 'mixamorig_RightUpLeg' not found")
        }

        // Arms extended (optional - can adjust for more dramatic pose)
        if let rightArm = findBone(named: "mixamorig_RightArm") {
            rightArm.eulerAngles.z = -.pi / 4  // Arm raised
        }
        if let leftArm = findBone(named: "mixamorig_LeftArm") {
            leftArm.eulerAngles.z = .pi / 4  // Arm raised
        }

        SCNTransaction.completionBlock = { [weak self] in
            self?.updateCOM()
        }
        SCNTransaction.commit()
    }

    @objc func resetPose() {
        print("Resetting pose...")

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.0

        // Reset all rotations (would need to store original rotations)
        if let rightUpLeg = findBone(named: "mixamorig_RightUpLeg") {
            rightUpLeg.eulerAngles = SCNVector3Zero
        }
        if let leftUpLeg = findBone(named: "mixamorig_LeftUpLeg") {
            leftUpLeg.eulerAngles = SCNVector3Zero
        }
        if let rightArm = findBone(named: "mixamorig_RightArm") {
            rightArm.eulerAngles = SCNVector3Zero
        }
        if let leftArm = findBone(named: "mixamorig_LeftArm") {
            leftArm.eulerAngles = SCNVector3Zero
        }

        SCNTransaction.completionBlock = { [weak self] in
            self?.updateCOM()
        }
        SCNTransaction.commit()
    }

    // MARK: - Transform Mode Functions

    @objc func setPositionMode() {
        currentTransformMode = .position
        transformStep = 5.0
        transformModeLabel.text = "Transform: Position"
        print("📍 Mode: Position")
    }

    @objc func setRotationMode() {
        currentTransformMode = .rotation
        transformStep = 5.0  // 5 degrees
        transformModeLabel.text = "Transform: Rotation"
        print("🔄 Mode: Rotation")
    }

    @objc func setScaleMode() {
        currentTransformMode = .scale
        transformStep = 0.1
        transformModeLabel.text = "Transform: Scale"
        print("📏 Mode: Scale")
    }

    @objc func transformUp() {
        switch currentTransformMode {
        case .position:
            characterNode.position.y += transformStep
            print("Moving up: Y = \(characterNode.position.y)")
        case .rotation:
            characterNode.eulerAngles.x += transformStep * .pi / 180
            print("Rotating X: \(characterNode.eulerAngles.x * 180 / .pi)°")
        case .scale:
            let newScale = characterNode.scale.y + transformStep
            characterNode.scale = SCNVector3(newScale, newScale, newScale)
            print("Scaling up: \(newScale)")
        }
        updateCOM()
    }

    @objc func transformDown() {
        switch currentTransformMode {
        case .position:
            characterNode.position.y -= transformStep
            print("Moving down: Y = \(characterNode.position.y)")
        case .rotation:
            characterNode.eulerAngles.x -= transformStep * .pi / 180
            print("Rotating X: \(characterNode.eulerAngles.x * 180 / .pi)°")
        case .scale:
            let newScale = max(0.1, characterNode.scale.y - transformStep)
            characterNode.scale = SCNVector3(newScale, newScale, newScale)
            print("Scaling down: \(newScale)")
        }
        updateCOM()
    }

    @objc func transformLeft() {
        switch currentTransformMode {
        case .position:
            characterNode.position.x -= transformStep
            print("Moving left: X = \(characterNode.position.x)")
        case .rotation:
            characterNode.eulerAngles.y += transformStep * .pi / 180
            print("Rotating Y: \(characterNode.eulerAngles.y * 180 / .pi)°")
        case .scale:
            // In scale mode, left/right don't do anything (or could control Z scale)
            break
        }
        updateCOM()
    }

    @objc func transformRight() {
        switch currentTransformMode {
        case .position:
            characterNode.position.x += transformStep
            print("Moving right: X = \(characterNode.position.x)")
        case .rotation:
            characterNode.eulerAngles.y -= transformStep * .pi / 180
            print("Rotating Y: \(characterNode.eulerAngles.y * 180 / .pi)°")
        case .scale:
            // In scale mode, left/right don't do anything (or could control Z scale)
            break
        }
        updateCOM()
    }

    @objc func resetTransform() {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5

        characterNode.position = SCNVector3(0, 0, 0)
        characterNode.eulerAngles = SCNVector3(0, 0, 0)
        characterNode.scale = SCNVector3(1, 1, 1)

        SCNTransaction.completionBlock = { [weak self] in
            self?.updateCOM()
            print("✅ Transform reset")
        }

        SCNTransaction.commit()
    }

    // MARK: - Joint Control Functions

    @objc func showJointSelectionMenu() {
        let alert = UIAlertController(
            title: "Select Joint", message: "Choose a joint to control",
            preferredStyle: .actionSheet)

        // Add action for each controllable joint
        for jointName in controllableJoints {
            let displayName = formatJointName(jointName)
            let action = UIAlertAction(title: displayName, style: .default) { [weak self] _ in
                self?.selectJoint(named: jointName)
            }
            alert.addAction(action)
        }

        // Add cancel button
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alert.addAction(cancelAction)

        // For iPad: set the popover presentation
        if let popover = alert.popoverPresentationController {
            popover.sourceView = jointSelectionButton
            popover.sourceRect = jointSelectionButton.bounds
        }

        present(alert, animated: true)
    }

    func selectJoint(named name: String) {
        if let joint = findBone(named: name) {
            selectedJoint = joint
            let displayName = formatJointName(name)
            jointSelectionButton.setTitle(displayName, for: .normal)
            print("✅ Selected joint: \(displayName)")
            print(
                "   Current rotation: X=\(joint.eulerAngles.x * 180 / .pi)° Y=\(joint.eulerAngles.y * 180 / .pi)° Z=\(joint.eulerAngles.z * 180 / .pi)°"
            )

            // Update slider to reflect current joint angle
            updateSliderForCurrentJoint()
        } else {
            print("⚠️ Could not find joint: \(name)")
        }
    }

    func updateSliderForCurrentJoint() {
        guard let joint = selectedJoint else { return }

        let currentAngle: Float
        switch jointControlMode {
        case .x:
            currentAngle = joint.eulerAngles.x * 180 / .pi
        case .y:
            currentAngle = joint.eulerAngles.y * 180 / .pi
        case .z:
            currentAngle = joint.eulerAngles.z * 180 / .pi
        }

        jointAngleSlider.value = currentAngle
        jointAngleLabel.text = String(format: "%.1f°", currentAngle)
    }

    @objc func jointAngleSliderChanged() {
        guard let joint = selectedJoint else { return }

        let angle = jointAngleSlider.value * .pi / 180

        switch jointControlMode {
        case .x:
            joint.eulerAngles.x = angle
        case .y:
            joint.eulerAngles.y = angle
        case .z:
            joint.eulerAngles.z = angle
        }

        jointAngleLabel.text = String(format: "%.1f°", jointAngleSlider.value)
        scheduleUpdateCOM()
    }

    func formatJointName(_ name: String) -> String {
        // Remove "mixamorig_" prefix and make it more readable
        let clean = name.replacingOccurrences(of: "mixamorig_", with: "")

        // Add spaces before capital letters
        var result = ""
        for (index, char) in clean.enumerated() {
            if index > 0 && char.isUppercase {
                result += " "
            }
            result.append(char)
        }

        return result
    }

    @objc func selectXAxis() {
        jointControlMode = .x
        print("🔴 Joint control: X-Axis")
        updateSliderForCurrentJoint()
    }

    @objc func selectYAxis() {
        jointControlMode = .y
        print("🟢 Joint control: Y-Axis")
        updateSliderForCurrentJoint()
    }

    @objc func selectZAxis() {
        jointControlMode = .z
        print("🔵 Joint control: Z-Axis")
        updateSliderForCurrentJoint()
    }

    @objc func startContinuousRotationPositive() {
        currentRotationDirection = .positive
        rotateJointPositive()  // Immediate first rotation

        // Start continuous rotation after short delay
        continuousRotationTimer?.invalidate()
        continuousRotationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) {
            [weak self] _ in
            self?.rotateJointPositive()
        }
    }

    @objc func startContinuousRotationNegative() {
        currentRotationDirection = .negative
        rotateJointNegative()  // Immediate first rotation

        // Start continuous rotation after short delay
        continuousRotationTimer?.invalidate()
        continuousRotationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) {
            [weak self] _ in
            self?.rotateJointNegative()
        }
    }

    @objc func stopContinuousRotation() {
        continuousRotationTimer?.invalidate()
        continuousRotationTimer = nil
        currentRotationDirection = nil
    }

    @objc func rotateJointPositive() {
        guard let joint = selectedJoint else {
            if currentRotationDirection != nil {
                // Silently stop continuous rotation if no joint
                stopContinuousRotation()
            }
            return
        }

        let rotationAmount: Float = 2.5 * .pi / 180  // 2.5 degrees for smoother continuous rotation

        switch jointControlMode {
        case .x:
            joint.eulerAngles.x += rotationAmount
        case .y:
            joint.eulerAngles.y += rotationAmount
        case .z:
            joint.eulerAngles.z += rotationAmount
        }

        updateSliderForCurrentJoint()
        scheduleUpdateCOM()
    }

    @objc func rotateJointNegative() {
        guard let joint = selectedJoint else {
            if currentRotationDirection != nil {
                // Silently stop continuous rotation if no joint
                stopContinuousRotation()
            }
            return
        }

        let rotationAmount: Float = 2.5 * .pi / 180  // 2.5 degrees for smoother continuous rotation

        switch jointControlMode {
        case .x:
            joint.eulerAngles.x -= rotationAmount
        case .y:
            joint.eulerAngles.y -= rotationAmount
        case .z:
            joint.eulerAngles.z -= rotationAmount
        }

        updateSliderForCurrentJoint()
        scheduleUpdateCOM()
    }

    @objc func resetSelectedJoint() {
        guard let joint = selectedJoint else {
            print("⚠️ No joint selected. Please select a joint first.")
            return
        }

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.0

        joint.eulerAngles = SCNVector3Zero

        SCNTransaction.completionBlock = { [weak self] in
            self?.updateCOM()
            print("✅ Joint \(joint.name ?? "unknown") reset")
        }

        SCNTransaction.commit()
    }
}
