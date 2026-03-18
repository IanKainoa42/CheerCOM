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
    private var poseLibraryToggleButton: UIButton!
    private var resetTPoseButton: UIButton!
    var viewLabel: UILabel!

    // State
    private var updateTimer: Timer?
    private var needsCOMUpdate = false
    private let updateInterval: TimeInterval = 0.033  // ~30 FPS

    // Validation
    private var validationHarness: CoMValidationHarness?

    // Transform State
    var currentTransformMode: TransformMode = .position
    var transformStep: Float = 5.0
    var transformStepMultiplier: Float = 1.0
    var fineTransform: Bool = false


    // Joint Control State
    var selectedJoint: SCNNode?
    var jointControlMode: JointAxis = .x
    private var selectedJointMarkerNode: SCNNode?
    private weak var highlightedJointMaterial: SCNMaterial?
    private var highlightedJointOriginalEmission: Any?

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
        // Bind calculator to scene nodes for optimized access
        calculator.bind(jointNodes: sceneManager.cachedBoneNodes)

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
        transformControlPanel.updateStepMultiplierSelection(transformStepMultiplier)

        poseLibraryToggleButton = UIButton(type: .system)
        poseLibraryToggleButton.frame = CGRect(x: 20, y: 60, width: 130, height: 40)
        poseLibraryToggleButton.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.85)
        poseLibraryToggleButton.setTitleColor(.white, for: .normal)
        poseLibraryToggleButton.titleLabel?.font = .boldSystemFont(ofSize: 14)
        poseLibraryToggleButton.layer.cornerRadius = 10
        poseLibraryToggleButton.addTarget(
            self, action: #selector(didTapPoseLibraryToggleButton), for: .touchUpInside)
        view.addSubview(poseLibraryToggleButton)

        resetTPoseButton = UIButton(type: .system)
        resetTPoseButton.frame = CGRect(x: 20, y: 105, width: 130, height: 40)
        resetTPoseButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.85)
        resetTPoseButton.setTitle("Reset T-Pose", for: .normal)
        resetTPoseButton.setTitleColor(.white, for: .normal)
        resetTPoseButton.titleLabel?.font = .boldSystemFont(ofSize: 14)
        resetTPoseButton.layer.cornerRadius = 10
        resetTPoseButton.addTarget(
            self, action: #selector(didTapResetTPoseButton), for: .touchUpInside)
        view.addSubview(resetTPoseButton)

        // Body Preset Selector
        let presetSelector = UISegmentedControl(items: ["Neutral", "Athletic F", "Athletic M"])
        presetSelector.frame = CGRect(x: 20, y: 155, width: 250, height: 35)
        presetSelector.selectedSegmentIndex = 0
        presetSelector.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        presetSelector.selectedSegmentTintColor = UIColor.systemBlue.withAlphaComponent(0.8)

        let normalTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        let selectedTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        presetSelector.setTitleTextAttributes(normalTextAttributes, for: .normal)
        presetSelector.setTitleTextAttributes(selectedTextAttributes, for: .selected)

        presetSelector.addTarget(self, action: #selector(didChangeBodyPreset(_:)), for: .valueChanged)
        view.addSubview(presetSelector)

        updatePoseLibraryToggleButton()

        // Validation Button
        let validationBtn = UIButton(type: .system)
        validationBtn.frame = CGRect(x: view.bounds.width - 160, y: 60, width: 140, height: 40)
        validationBtn.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        validationBtn.setTitle("Run Diagnostics", for: .normal)
        validationBtn.setTitleColor(.white, for: .normal)
        validationBtn.layer.cornerRadius = 10
        validationBtn.addTarget(self, action: #selector(didTapRunDiagnostics), for: .touchUpInside)
        view.addSubview(validationBtn)

        setTransformMode(currentTransformMode)
    }

    @objc private func didTapPoseLibraryToggleButton() {
        setPoseLibraryVisible(poseLibraryPanel.isHidden)
    }

    @objc private func didTapResetTPoseButton() {
        didTapResetPose()
    }

    @objc private func didChangeBodyPreset(_ sender: UISegmentedControl) {
        let preset: BodyPreset
        switch sender.selectedSegmentIndex {
        case 1: preset = .athleticFemale
        case 2: preset = .athleticMale
        default: preset = .averageNeutral
        }
        calculator.setPreset(preset)
        scheduleUpdateCOM()
        print("👤 Body preset changed to: \(preset)")
    }

    private func setPoseLibraryVisible(_ isVisible: Bool) {
        poseLibraryPanel.isHidden = !isVisible
        updatePoseLibraryToggleButton()
        print("🎭 Pose library \(isVisible ? "shown" : "hidden")")
    }

    private func updatePoseLibraryToggleButton() {
        let isVisible = !poseLibraryPanel.isHidden
        poseLibraryToggleButton?.setTitle(
            isVisible ? "Hide Pose Library" : "Show Pose Library",
            for: .normal
        )
        poseLibraryToggleButton?.backgroundColor = isVisible
            ? UIColor.systemPurple.withAlphaComponent(0.95)
            : UIColor.systemPurple.withAlphaComponent(0.75)
    }

    @objc func didTapRunDiagnostics() {
        if validationHarness != nil { return } // Already running

        print("▶️ Starting Diagnostics...")

        // Show Diagnostics Overlay
        let overlay = DiagnosticsOverlay(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(overlay)

        // Disable interaction with other controls while running
        sceneManager.sceneView.isUserInteractionEnabled = false
        jointControlPanel.isUserInteractionEnabled = false
        transformControlPanel.isUserInteractionEnabled = false
        poseLibraryPanel.isUserInteractionEnabled = false

        // Handle close
        overlay.onClose = { [weak self] in
            self?.sceneManager.sceneView.isUserInteractionEnabled = true
            self?.jointControlPanel.isUserInteractionEnabled = true
            self?.transformControlPanel.isUserInteractionEnabled = true
            self?.poseLibraryPanel.isUserInteractionEnabled = true
        }

        validationHarness = CoMValidationHarness()
        validationHarness?.runValidation(
            sceneManager: sceneManager,
            calculator: calculator,
            visualizationsManager: visualizationsManager,
            logger: { message in
                overlay.log(message)
            }
        ) { [weak self] in
            print("🏁 Diagnostics Finished")
            self?.validationHarness = nil
        }
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
        // Calculate COM directly using bound nodes
        // Optimization: Only compute detailed segments if advanced visualizations are enabled
        let result = calculator.calculateDetailedBodyCOM(
            detailed: visualizationsManager.showAdvancedVisualizations
        )

        // Update Visuals
        visualizationsManager.updateCOM(result: result)
        updateSelectedJointHighlightPosition()

        // Throttle UI updates
        updateCounter += 1
        if updateCounter >= uiUpdateInterval {
            updateCounter = 0
            let (margin, isStable) = visualizationsManager.calculateStabilityMargin(com: result.totalCOM)

            // Update UI
            comInfoPanel.update(com: result.totalCOM, isStable: isStable, margin: margin)
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
        case .keyboardF:
            fineTransform.toggle()
            setTransformMode(currentTransformMode)
            print("Fine transform: \(fineTransform)")

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
        clearSelectedJointHighlight()
        selectedJoint = nil

        if let joint = sceneManager.findBone(named: name) {
            selectedJoint = joint
            applySelectedJointHighlight(for: joint)

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

        var newAngles = joint.eulerAngles
        switch jointControlMode {
        case .x: newAngles.x += delta
        case .y: newAngles.y += delta
        case .z: newAngles.z += delta
        }

        if let jointName = joint.name {
            joint.eulerAngles = JointLimits.clampAngles(for: jointName, angles: newAngles)
        } else {
            joint.eulerAngles = newAngles
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

        var newAngles = joint.eulerAngles
        switch jointControlMode {
        case .x: newAngles.x = angle
        case .y: newAngles.y = angle
        case .z: newAngles.z = angle
        }

        if let jointName = joint.name {
            joint.eulerAngles = JointLimits.clampAngles(for: jointName, angles: newAngles)
        } else {
            joint.eulerAngles = newAngles
        }

        print("🎚️ Set \(jointControlMode.rawValue)-axis angle to \(value)°")

        scheduleUpdateCOM()
    }

    // Pose Library
    func didTapPoseLibrary() {
        setPoseLibraryVisible(poseLibraryPanel.isHidden)
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
                bone.eulerAngles = JointLimits.clampAngles(for: jointName, angles: angles)
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

    private func applySelectedJointHighlight(for joint: SCNNode) {
        if let material = joint.geometry?.firstMaterial {
            highlightedJointOriginalEmission = material.emission.contents
            material.emission.contents = UIColor.systemYellow
            highlightedJointMaterial = material
        } else {
            highlightedJointMaterial = nil
            highlightedJointOriginalEmission = nil
        }

        let markerGeometry = SCNSphere(radius: 1.8)
        markerGeometry.segmentCount = 18
        markerGeometry.firstMaterial?.diffuse.contents = UIColor.systemYellow.withAlphaComponent(0.45)
        markerGeometry.firstMaterial?.emission.contents = UIColor.systemYellow
        markerGeometry.firstMaterial?.lightingModel = .constant
        markerGeometry.firstMaterial?.isDoubleSided = true

        let markerNode = SCNNode(geometry: markerGeometry)
        markerNode.position = joint.presentation.worldPosition
        markerNode.name = "selected_joint_marker"
        sceneManager.scene.rootNode.addChildNode(markerNode)

        let pulseAnimation = CABasicAnimation(keyPath: "opacity")
        pulseAnimation.fromValue = 0.2
        pulseAnimation.toValue = 0.9
        pulseAnimation.duration = 0.65
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        markerNode.addAnimation(pulseAnimation, forKey: "pulse")

        selectedJointMarkerNode = markerNode
    }

    private func clearSelectedJointHighlight() {
        if let material = highlightedJointMaterial {
            material.emission.contents = highlightedJointOriginalEmission
        }
        highlightedJointMaterial = nil
        highlightedJointOriginalEmission = nil

        selectedJointMarkerNode?.removeAllAnimations()
        selectedJointMarkerNode?.removeFromParentNode()
        selectedJointMarkerNode = nil
    }

    private func updateSelectedJointHighlightPosition() {
        guard let selectedJoint = selectedJoint,
            let markerNode = selectedJointMarkerNode
        else {
            return
        }
        markerNode.position = selectedJoint.presentation.worldPosition
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

    func didSelectSavedPose(_ pose: SavedPose) {
        print("💾 Applying saved pose: \(pose.name)")
        applySavedPose(pose)
    }

    func didDeleteSavedPose(_ pose: SavedPose) {
        let alert = UIAlertController(
            title: "Delete Pose",
            message: "Are you sure you want to delete '\(pose.name)'?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            PoseStorageManager.shared.deletePose(id: pose.id)
            self?.poseLibraryPanel.refreshPoses()
            print("🗑️ Deleted pose: \(pose.name)")
        })

        present(alert, animated: true)
    }

    func didTapSavePose() {
        let alert = UIAlertController(title: "Save Pose", message: "Enter a name for this pose", preferredStyle: .alert)

        alert.addTextField { textField in
            textField.placeholder = "Pose Name"
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self,
                  let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return }

            self.saveCurrentPose(name: name)
        }
        saveAction.isEnabled = false // Initially disabled

        alert.addAction(cancelAction)
        alert.addAction(saveAction)

        present(alert, animated: true)

        // Add observer to enable button only when text is present
        NotificationCenter.default.addObserver(forName: UITextField.textDidChangeNotification, object: alert.textFields?.first, queue: OperationQueue.main) { notification in
            if let textField = notification.object as? UITextField,
               let text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                saveAction.isEnabled = true
            } else {
                saveAction.isEnabled = false
            }
        }
    }

    private func saveCurrentPose(name: String) {
        var jointPositions: [String: SCNVector3] = [:]

        // Iterate through all controllable joints and capture their Euler angles
        for jointName in sceneManager.controllableJoints {
            if let joint = sceneManager.cachedBoneNodes[jointName] {
                jointPositions[jointName] = joint.eulerAngles
            }
        }

        PoseStorageManager.shared.savePose(name: name, jointPositions: jointPositions)
        print("💾 Saved pose '\(name)' with \(jointPositions.count) joints")

        // Refresh library if it's showing saved poses
        poseLibraryPanel.refreshPoses()

        // Show confirmation
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
    }

    func didTapExportPoses() {
        guard let jsonString = PoseStorageManager.shared.exportPosesToJSON() else {
            print("❌ Nothing to export or export failed.")
            return
        }

        let alert = UIAlertController(title: "Export Poses", message: "Copy the JSON below to save your poses.", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = jsonString
        }
        alert.addAction(UIAlertAction(title: "Copy & Close", style: .default, handler: { _ in
            UIPasteboard.general.string = jsonString
            print("✅ Poses copied to clipboard")
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    func didTapImportPoses() {
        let alert = UIAlertController(title: "Import Poses", message: "Paste pose JSON below", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Paste JSON here"
        }
        alert.addAction(UIAlertAction(title: "Import", style: .default, handler: { [weak self] _ in
            if let text = alert.textFields?.first?.text, !text.isEmpty {
                PoseStorageManager.shared.importPosesFromJSON(jsonString: text)
                self?.poseLibraryPanel.refreshPoses()
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    func didTapClosePoseLibrary() {
        setPoseLibraryVisible(false)
    }

    private func applyPose(_ pose: PoseType) {
        let poseDefinition = PosePresets.shared.getPose(pose)
        applyJointAngles(poseDefinition.jointAngles, name: poseDefinition.name)
    }

    private func applySavedPose(_ pose: SavedPose) {
        var jointAngles: [String: SCNVector3] = [:]
        for (name, _) in pose.jointAngles {
            if let vector = pose.getVector(for: name) {
                jointAngles[name] = vector
            }
        }
        applyJointAngles(jointAngles, name: pose.name)
    }

    private func applyJointAngles(_ jointAngles: [String: SCNVector3], name: String) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.3

        // Apply joint angles
        for (jointName, angles) in jointAngles {
            if let bone = sceneManager.findBone(named: jointName) {
                bone.eulerAngles = JointLimits.clampAngles(for: jointName, angles: angles)
            }
        }

        SCNTransaction.completionBlock = { [weak self] in
            self?.scheduleUpdateCOM()
            print("✅ Applied \(name)")
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
        transformStep = baseTransformStep(for: mode) * transformStepMultiplier
        transformControlPanel.updateModeDisplay(mode: mode, step: transformStep)
        print("Mode: \(mode), step: \(transformStep)")
    }

    func didChangeTransformStepMultiplier(_ multiplier: Float) {
        transformStepMultiplier = multiplier
        transformStep = baseTransformStep(for: currentTransformMode) * transformStepMultiplier
        transformControlPanel.updateModeDisplay(mode: currentTransformMode, step: transformStep)
        print("Step multiplier: \(multiplier)x (step: \(transformStep))")
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

    private func baseTransformStep(for mode: TransformMode) -> Float {
        switch mode {
        case .position, .rotation:
            return fineTransform ? 1.0 : 5.0
        case .scale:
            return fineTransform ? 0.05 : 0.1
        }
    }
}
