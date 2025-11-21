import SceneKit
import UIKit

class SceneViewController: UIViewController {

    // Managers
    var sceneManager: CheerCOMSceneManager!
    var cameraManager: CameraManager!
    var visualizationsManager: VisualizationsManager!
    var calculator: COMCalculator!

    // Views
    var comInfoPanel: COMInfoPanel!
    var jointControlPanel: JointControlPanel!
    var transformControlPanel: TransformControlPanel!
    var poseLibraryPanel: PoseLibraryPanel!
    var viewLabel: UILabel!

    // State
    private var updateTimer: Timer?
    private var needsCOMUpdate = false
    private let updateInterval: TimeInterval = 0.033  // ~30 FPS

    // Transform State
    var currentTransformMode: TransformMode = .position
    var transformStep: Float = 5.0

    // Joint Control State
    var selectedJoint: SCNNode?
    var jointControlMode: JointAxis = .x

    // Continuous control support
    private var continuousRotationTimer: Timer?
    private var currentRotationDirection: RotationDirection?

    override func viewDidLoad() {
        super.viewDidLoad()

        print("🚀 SceneViewController loaded")

        // 1. Setup Managers
        sceneManager = CheerCOMSceneManager(view: view)
        sceneManager.loadCharacter()

        cameraManager = CameraManager(scene: sceneManager.scene)

        visualizationsManager = VisualizationsManager(
            scene: sceneManager.scene,
            sceneManager: sceneManager
        )

        // 2. Setup Calculator
        calculator = COMCalculator(bodyMass: 52.2)

        // 3. Setup UI
        setupUI()

        // 4. Frame Character
        sceneManager.frameCharacter()

        // 5. Start Loop
        startUpdateTimer()
        scheduleUpdateCOM()

        print("✅ Scene setup complete")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        resignFirstResponder()
        stopUpdateTimer()
    }

    deinit {
        stopUpdateTimer()
    }

    private func setupUI() {
        // COM Info Panel
        comInfoPanel = COMInfoPanel()
        view.addSubview(comInfoPanel)

        // Joint Control Panel
        jointControlPanel = JointControlPanel(width: view.bounds.width)
        jointControlPanel.delegate = self
        view.addSubview(jointControlPanel)

        // Pose Library Panel (initially hidden)
        poseLibraryPanel = PoseLibraryPanel(width: view.bounds.width)
        poseLibraryPanel.delegate = self
        poseLibraryPanel.isHidden = true
        view.addSubview(poseLibraryPanel)

        // Transform Control Panel
        transformControlPanel = TransformControlPanel(width: view.bounds.width)
        transformControlPanel.delegate = self
        view.addSubview(transformControlPanel)
    }

    // MARK: - Update Loop

    func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) {
            [weak self] _ in
            guard let self = self else { return }
            if self.needsCOMUpdate {
                self.performCOMUpdate()
                // Reset flag only after update is done
                self.needsCOMUpdate = false
            }
        }
        updateTimer?.tolerance = 0.002
        print("⏱️ Update timer started")
    }

    func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
        print("⏱️ Update timer stopped")
    }

    func scheduleUpdateCOM() {
        needsCOMUpdate = true
    }

    private var updateCounter = 0
    private let uiUpdateInterval = 10  // Update UI every 10 frames

    func performCOMUpdate() {
        // Gather positions
        var jointPositions: [String: SCNVector3] = [:]
        for (name, node) in sceneManager.cachedBoneNodes {
            jointPositions[name] = node.worldPosition
        }

        // Calculate COM
        let com = calculator.calculateBodyCOM(jointPositions: jointPositions)

        // Update Visuals
        visualizationsManager.updateCOM(position: com)

        // Throttle UI updates
        updateCounter += 1
        if updateCounter >= uiUpdateInterval {
            updateCounter = 0
            let (margin, isStable) = visualizationsManager.calculateStabilityMargin(com: com)

            // Update UI
            comInfoPanel.update(com: com, isStable: isStable, margin: margin)
        }
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
            // Cycle through transform modes
            switch currentTransformMode {
            case .position:
                setTransformMode(.rotation)
            case .rotation:
                setTransformMode(.scale)
            case .scale:
                setTransformMode(.position)
            }
        default:
            super.pressesBegan(presses, with: event)
        }
    }
}

// MARK: - JointControlPanelDelegate
extension SceneViewController: JointControlPanelDelegate {
    func didTapJointSelection(sourceView: UIView) {
        let alert = UIAlertController(
            title: "Select Joint", message: "Choose a joint to control",
            preferredStyle: .actionSheet)

        for jointName in sceneManager.controllableJoints {
            let displayName = formatJointName(jointName)
            let action = UIAlertAction(title: displayName, style: .default) { [weak self] _ in
                self?.selectJoint(named: jointName)
            }
            alert.addAction(action)
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alert.addAction(cancelAction)

        if let popover = alert.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }

        present(alert, animated: true)
    }

    func selectJoint(named name: String) {
        if let joint = sceneManager.findBone(named: name) {
            selectedJoint = joint
            let displayName = formatJointName(name)

            // Update UI
            let currentAngle = getAngleForCurrentAxis(joint: joint)
            jointControlPanel.updateJointSelection(name: displayName, angle: currentAngle)
            jointControlPanel.updateSelectedAxis(jointControlMode)

            print("✅ Selected joint: \(displayName)")
            print(
                "   Current euler angles: x=\(joint.eulerAngles.x * 180 / .pi)°, y=\(joint.eulerAngles.y * 180 / .pi)°, z=\(joint.eulerAngles.z * 180 / .pi)°"
            )
            print("   World position: \(joint.worldPosition)")
        } else {
            print("❌ Failed to find joint: \(name)")
        }
    }

    func didSelectAxis(_ axis: JointAxis) {
        jointControlMode = axis
        print("🔄 Switched to \(axis.rawValue)-axis control")
        if let joint = selectedJoint {
            let angle = getAngleForCurrentAxis(joint: joint)
            jointControlPanel.updateAngleDisplay(angle: angle)
            jointControlPanel.updateSelectedAxis(axis)
            print("   Current \(axis.rawValue) angle: \(angle)°")
        }
    }

    func didIncrementAngle() {
        didRotateJoint(direction: .positive)
    }

    func didDecrementAngle() {
        didRotateJoint(direction: .negative)
    }

    func didRotateJoint(direction: RotationDirection) {
        guard let joint = selectedJoint else {
            print("⚠️ No joint selected for rotation")
            return
        }

        let rotationAmount: Float = 1.0 * .pi / 180  // 1 degree fine tuning
        let delta = (direction == .positive) ? rotationAmount : -rotationAmount

        let oldAngle = getAngleForCurrentAxis(joint: joint)

        switch jointControlMode {
        case .x: joint.eulerAngles.x += delta
        case .y: joint.eulerAngles.y += delta
        case .z: joint.eulerAngles.z += delta
        }

        let newAngle = getAngleForCurrentAxis(joint: joint)
        print("🎮 Rotated joint on \(jointControlMode.rawValue)-axis: \(oldAngle)° → \(newAngle)°")

        jointControlPanel.updateAngleDisplay(angle: newAngle)
        scheduleUpdateCOM()
    }

    func didResetSelectedJoint() {
        guard let joint = selectedJoint else { return }

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.0
        joint.eulerAngles = SCNVector3Zero
        SCNTransaction.completionBlock = { [weak self] in
            self?.scheduleUpdateCOM()
        }
        SCNTransaction.commit()

        jointControlPanel.updateAngleDisplay(angle: 0)
    }

    func didChangeJointAngle(value: Float) {
        guard let joint = selectedJoint else {
            print("⚠️ No joint selected for angle change")
            return
        }
        let angle = value * .pi / 180

        switch jointControlMode {
        case .x: joint.eulerAngles.x = angle
        case .y: joint.eulerAngles.y = angle
        case .z: joint.eulerAngles.z = angle
        }

        print("🎚️ Set \(jointControlMode.rawValue)-axis angle to \(value)°")

        scheduleUpdateCOM()
    }

    // Pose Library
    func didTapPoseLibrary() {
        // Toggle pose library visibility
        poseLibraryPanel.isHidden = !poseLibraryPanel.isHidden
        print("🎭 Pose library \(poseLibraryPanel.isHidden ? "hidden" : "shown")")
    }

    func didTapResetPose() {
        print("🔄 Resetting to T-Pose...")

        // Apply T-Pose instead of just zeroing joints
        let tPose = PoseType.tPose
        let tPoseDefinition = PosePresets.shared.getPose(tPose)

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.3

        // Apply T-Pose joint angles
        for (jointName, angles) in tPoseDefinition.jointAngles {
            if let bone = sceneManager.findBone(named: jointName) {
                bone.eulerAngles = angles
            }
        }

        SCNTransaction.completionBlock = { [weak self] in
            self?.scheduleUpdateCOM()
            print("✅ Reset to T-Pose complete")
        }
        SCNTransaction.commit()
    }

    // View Controls
    func didTapFitView() {
        cameraManager.fitToView()
    }

    func didTapToggleVisualizations() {
        visualizationsManager.toggleVisualizations()
    }

    // Helpers
    private func getAngleForCurrentAxis(joint: SCNNode) -> Float {
        switch jointControlMode {
        case .x: return joint.eulerAngles.x * 180 / .pi
        case .y: return joint.eulerAngles.y * 180 / .pi
        case .z: return joint.eulerAngles.z * 180 / .pi
        }
    }

    private func formatJointName(_ name: String) -> String {
        let clean = name.replacingOccurrences(of: "mixamorig_", with: "")
        var result = ""
        for (index, char) in clean.enumerated() {
            if index > 0 && char.isUppercase {
                result += " "
            }
            result.append(char)
        }
        return result
    }
}

// MARK: - PoseLibraryPanelDelegate
extension SceneViewController: PoseLibraryPanelDelegate {
    func didSelectPose(_ pose: PoseType) {
        print("🎭 Applying pose: \(pose.displayName)")
        applyPose(pose)
    }

    func didTapMirrorPose() {
        print("↔️ Mirror pose functionality coming soon")
        // TODO: Implement pose mirroring
    }

    func didTapSavePose() {
        print("💾 Save pose functionality coming soon")
        // TODO: Implement pose saving
    }

    func didTapClosePoseLibrary() {
        poseLibraryPanel.isHidden = true
        print("🎭 Pose library closed")
    }

    private func applyPose(_ pose: PoseType) {
        let poseDefinition = PosePresets.shared.getPose(pose)

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.3

        // Apply joint angles from the pose definition
        for (jointName, angles) in poseDefinition.jointAngles {
            if let bone = sceneManager.findBone(named: jointName) {
                bone.eulerAngles = angles
            }
        }

        SCNTransaction.completionBlock = { [weak self] in
            self?.scheduleUpdateCOM()
            print("✅ Applied \(poseDefinition.name)")
        }
        SCNTransaction.commit()
    }
}

// MARK: - TransformControlPanelDelegate
extension SceneViewController: TransformControlPanelDelegate {
    func didChangeTransformMode(_ mode: TransformMode) {
        setTransformMode(mode)
    }

    func setTransformMode(_ mode: TransformMode) {
        currentTransformMode = mode
        switch mode {
        case .position: transformStep = 5.0
        case .rotation: transformStep = 5.0
        case .scale: transformStep = 0.1
        }
        transformControlPanel.updateModeDisplay(mode: mode)
        print("Mode: \(mode)")
    }

    func didTapTransform(direction: TransformDirection) {
        switch direction {
        case .up: transformUp()
        case .down: transformDown()
        case .left: transformLeft()
        case .right: transformRight()
        }
    }

    func didTapResetTransform() {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        sceneManager.characterNode.position = SCNVector3(0, 0, 0)
        sceneManager.characterNode.eulerAngles = SCNVector3(0, 0, 0)
        sceneManager.characterNode.scale = SCNVector3(1, 1, 1)
        SCNTransaction.completionBlock = { [weak self] in
            self?.scheduleUpdateCOM()
            print("✅ Transform reset")
        }
        SCNTransaction.commit()
    }

    // Transform Logic
    func transformUp() {
        switch currentTransformMode {
        case .position: sceneManager.characterNode.position.y += transformStep
        case .rotation: sceneManager.characterNode.eulerAngles.x += transformStep * .pi / 180
        case .scale:
            let newScale = sceneManager.characterNode.scale.y + transformStep
            sceneManager.characterNode.scale = SCNVector3(newScale, newScale, newScale)
        }
        scheduleUpdateCOM()
    }

    func transformDown() {
        switch currentTransformMode {
        case .position: sceneManager.characterNode.position.y -= transformStep
        case .rotation: sceneManager.characterNode.eulerAngles.x -= transformStep * .pi / 180
        case .scale:
            let newScale = max(0.1, sceneManager.characterNode.scale.y - transformStep)
            sceneManager.characterNode.scale = SCNVector3(newScale, newScale, newScale)
        }
        scheduleUpdateCOM()
    }

    func transformLeft() {
        switch currentTransformMode {
        case .position: sceneManager.characterNode.position.x -= transformStep
        case .rotation: sceneManager.characterNode.eulerAngles.y += transformStep * .pi / 180
        case .scale: break
        }
        scheduleUpdateCOM()
    }

    func transformRight() {
        switch currentTransformMode {
        case .position: sceneManager.characterNode.position.x += transformStep
        case .rotation: sceneManager.characterNode.eulerAngles.y -= transformStep * .pi / 180
        case .scale: break
        }
        scheduleUpdateCOM()
    }
}
