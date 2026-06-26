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
    private var clampWarningLabel: UILabel!
    private var clampWarningTimer: Timer?
    var transformControlPanel: TransformControlPanel!
    var poseLibraryPanel: PoseLibraryPanel!
    private var backdropView: CheerGradientBackdropView!
    private var chromeScrollView: UIScrollView!
    private var chromeContentView: UIView!
    private var chromeStackView: UIStackView!
    private var toolRailView: CheerGlassPanel!
    private var toolRailStackView: UIStackView!
    private var mainRegionStackView: UIStackView!
    private var mainActionsPanel: CheerGlassPanel!
    private var mainActionsTopRow: UIStackView!
    private var mainActionsBottomRow: UIStackView!
    private var inspectorStackView: UIStackView!
    private var topCardsStackView: UIStackView!
    private var headerPanel: CheerGlassPanel!
    private var headerRowStack: UIStackView!
    private var diagnosticsButton: CheerButton!
    private var bodyPresetSelector: UISegmentedControl!
    private var controlsToggleButton: CheerButton!
    private var sceneCard: CheerGlassPanel!
    private var sceneViewportContainer: UIView!
    private var sceneViewportHeightConstraint: NSLayoutConstraint!
    private var toolRailWidthConstraint: NSLayoutConstraint!
    private var toolRailHeightConstraint: NSLayoutConstraint!
    private var inspectorWidthConstraint: NSLayoutConstraint!
    private var jointPanelHeightConstraint: NSLayoutConstraint!
    private var poseLibraryHeightConstraint: NSLayoutConstraint!
    private var poseLibraryVisible = false
    private var chromeVisible = true
    private var didApplyInitialChromePreference = false

    // State
    private var updateTimer: Timer?
    private var needsCOMUpdate = false
    private let updateInterval: TimeInterval = 0.033  // ~30 FPS

    // Validation
    private var validationHarness: CoMValidationHarness?
    private var validationOverlay: ValidationOverlayPanel?

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
    private var continuousTransformTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()

        print("🚀 SceneViewController loaded")

        setupBackdrop()
        setupUI()
        setupValidationOverlay()

        // 1. Setup Managers
        sceneManager = CheerCOMSceneManager(view: sceneViewportContainer)
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateAdaptiveLayout()

        if !didApplyInitialChromePreference {
            didApplyInitialChromePreference = true
            setChromeVisible(true, animated: false)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        resignFirstResponder()
        stopUpdateTimer()
        NotificationCenter.default.removeObserver(self, name: .jointAngleClamped, object: nil)
    }

    deinit {
        stopUpdateTimer()
        NotificationCenter.default.removeObserver(self, name: .jointAngleClamped, object: nil)
    }

    private func setupClampWarningToast() {
        clampWarningLabel = UILabel()
        clampWarningLabel.translatesAutoresizingMaskIntoConstraints = false
        clampWarningLabel.backgroundColor = CheerPalette.danger.withAlphaComponent(0.85)
        clampWarningLabel.textColor = .white
        clampWarningLabel.font = cheerRoundedFont(.subheadline, weight: .bold)
        clampWarningLabel.textAlignment = .center
        clampWarningLabel.layer.cornerRadius = 12
        clampWarningLabel.layer.masksToBounds = true
        clampWarningLabel.numberOfLines = 0
        clampWarningLabel.alpha = 0
        clampWarningLabel.layer.zPosition = 1000 // Ensure it sits well above the SceneKit view

        // Add padding
        let paddingView = UIView()
        paddingView.translatesAutoresizingMaskIntoConstraints = false
        paddingView.backgroundColor = .clear
        paddingView.addSubview(clampWarningLabel)

        view.addSubview(clampWarningLabel)

        NSLayoutConstraint.activate([
            clampWarningLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            clampWarningLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            clampWarningLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -40),
            clampWarningLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])

        // Add some internal padding
        // UILabel doesn't have intrinsic padding, so we just use the constraints above
        // but we'll add spaces or a custom view if we want real padding.
        // For a simple toast, this is okay, but let's make it look nicer by adjusting bounds.
        // Actually, let's just make sure it's wide enough for text.

        NotificationCenter.default.addObserver(self, selector: #selector(handleJointClamped(_:)), name: .jointAngleClamped, object: nil)
    }

    @objc private func handleJointClamped(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let jointName = userInfo["jointName"] as? String else { return }

        // Format the joint name to be more readable
        let readableName = jointName.replacingOccurrences(of: "mixamorig_", with: "").replacingOccurrences(of: "Right", with: "R ").replacingOccurrences(of: "Left", with: "L ")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.clampWarningLabel.text = " ⚠️ Limit Reached: \(readableName) "

            // Ensure the toast is brought to the front of the view hierarchy
            self.view.bringSubviewToFront(self.clampWarningLabel)

            // Provide a visual warning on the 3D model itself
            self.visualizationsManager?.highlightJoint(named: jointName, color: .orange)

            self.clampWarningTimer?.invalidate()

            UIView.animate(withDuration: 0.2) {
                self.clampWarningLabel.alpha = 1.0
                self.clampWarningLabel.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            } completion: { _ in
                UIView.animate(withDuration: 0.1) {
                    self.clampWarningLabel.transform = .identity
                }
            }

            self.clampWarningTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                UIView.animate(withDuration: 0.3) {
                    self?.clampWarningLabel.alpha = 0.0
                }
                self?.visualizationsManager?.resetSegmentHighlights()
            }
        }
    }

    private func setupBackdrop() {
        view.backgroundColor = CheerPalette.midnight

        backdropView = CheerGradientBackdropView()
        view.addSubview(backdropView)

        NSLayoutConstraint.activate([
            backdropView.topAnchor.constraint(equalTo: view.topAnchor),
            backdropView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdropView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdropView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - Validation Overlay

    private func setupValidationOverlay() {
        let overlay = ValidationOverlayPanel()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.isHidden = true
        view.addSubview(overlay)

        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            overlay.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            overlay.widthAnchor.constraint(equalToConstant: 300),
            overlay.heightAnchor.constraint(equalToConstant: 400)
        ])

        self.validationOverlay = overlay
    }

    private func setupUI() {
        setupClampWarningToast()

        chromeScrollView = UIScrollView()
        chromeScrollView.translatesAutoresizingMaskIntoConstraints = false
        chromeScrollView.alwaysBounceVertical = true
        chromeScrollView.showsVerticalScrollIndicator = false
        chromeScrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(chromeScrollView)

        chromeContentView = UIView()
        chromeContentView.translatesAutoresizingMaskIntoConstraints = false
        chromeScrollView.addSubview(chromeContentView)

        chromeStackView = UIStackView()
        chromeStackView.translatesAutoresizingMaskIntoConstraints = false
        chromeStackView.axis = .vertical
        chromeStackView.spacing = 16
        chromeStackView.alignment = .fill
        chromeContentView.addSubview(chromeStackView)

        toolRailView = makeToolRail()
        toolRailView.isHidden = true
        chromeStackView.addArrangedSubview(toolRailView)

        mainRegionStackView = UIStackView()
        mainRegionStackView.translatesAutoresizingMaskIntoConstraints = false
        mainRegionStackView.axis = .vertical
        mainRegionStackView.spacing = 12
        chromeStackView.addArrangedSubview(mainRegionStackView)

        inspectorStackView = UIStackView()
        inspectorStackView.translatesAutoresizingMaskIntoConstraints = false
        inspectorStackView.axis = .vertical
        inspectorStackView.spacing = 10
        inspectorStackView.isHidden = true
        chromeStackView.addArrangedSubview(inspectorStackView)

        transformControlPanel = TransformControlPanel(width: view.bounds.width)
        transformControlPanel.delegate = self
        transformControlPanel.updateStepMultiplierSelection(transformStepMultiplier)

        sceneCard = makeSceneCard()
        mainRegionStackView.addArrangedSubview(sceneCard)

        jointControlPanel = JointControlPanel(width: view.bounds.width)
        jointControlPanel.delegate = self
        mainRegionStackView.addArrangedSubview(jointControlPanel)

        mainActionsPanel = makeMainActionsPanel()
        mainActionsPanel.isHidden = true
        mainRegionStackView.addArrangedSubview(mainActionsPanel)

        headerPanel = makeHeaderPanel()
        headerPanel.isHidden = true
        mainRegionStackView.addArrangedSubview(headerPanel)

        comInfoPanel = COMInfoPanel()
        comInfoPanel.isHidden = true
        inspectorStackView.addArrangedSubview(comInfoPanel)

        poseLibraryPanel = PoseLibraryPanel(width: view.bounds.width)
        poseLibraryPanel.delegate = self
        poseLibraryPanel.alpha = 0
        poseLibraryPanel.transform = CGAffineTransform(translationX: 0, y: 24)
        poseLibraryPanel.isUserInteractionEnabled = false
        view.addSubview(poseLibraryPanel)

        jointPanelHeightConstraint = jointControlPanel.heightAnchor.constraint(equalToConstant: 392)
        jointPanelHeightConstraint.isActive = true
        poseLibraryHeightConstraint = poseLibraryPanel.heightAnchor.constraint(equalToConstant: 360)

        toolRailWidthConstraint = toolRailView.widthAnchor.constraint(equalToConstant: 64)
        toolRailHeightConstraint = toolRailView.heightAnchor.constraint(equalToConstant: 56)
        inspectorWidthConstraint = inspectorStackView.widthAnchor.constraint(equalToConstant: 280)

        NSLayoutConstraint.activate([
            chromeScrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            chromeScrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            chromeScrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            chromeScrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            chromeContentView.topAnchor.constraint(equalTo: chromeScrollView.contentLayoutGuide.topAnchor),
            chromeContentView.leadingAnchor.constraint(equalTo: chromeScrollView.contentLayoutGuide.leadingAnchor),
            chromeContentView.trailingAnchor.constraint(equalTo: chromeScrollView.contentLayoutGuide.trailingAnchor),
            chromeContentView.bottomAnchor.constraint(equalTo: chromeScrollView.contentLayoutGuide.bottomAnchor),
            chromeContentView.widthAnchor.constraint(equalTo: chromeScrollView.frameLayoutGuide.widthAnchor),
            chromeContentView.heightAnchor.constraint(greaterThanOrEqualTo: chromeScrollView.frameLayoutGuide.heightAnchor),

            chromeStackView.topAnchor.constraint(equalTo: chromeContentView.topAnchor),
            chromeStackView.leadingAnchor.constraint(equalTo: chromeContentView.leadingAnchor),
            chromeStackView.trailingAnchor.constraint(equalTo: chromeContentView.trailingAnchor),
            chromeStackView.bottomAnchor.constraint(equalTo: chromeContentView.bottomAnchor),

            poseLibraryPanel.leadingAnchor.constraint(equalTo: mainRegionStackView.leadingAnchor),
            poseLibraryPanel.trailingAnchor.constraint(equalTo: mainRegionStackView.trailingAnchor),
            poseLibraryPanel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            poseLibraryHeightConstraint
        ])

        toolRailWidthConstraint.isActive = false
        toolRailHeightConstraint.isActive = true
        inspectorWidthConstraint.isActive = false
        updateAdaptiveLayout()
        updateControlsToggleButton()
        setTransformMode(currentTransformMode)
    }

    private func makeHeaderPanel() -> CheerGlassPanel {
        let panel = CheerGlassPanel(padding: .init(top: 16, leading: 18, bottom: 16, trailing: 18))

        let eyebrowLabel = PaddingLabel()
        eyebrowLabel.text = "// CHEERCOM / POSE CONTROLS"
        eyebrowLabel.textColor = CheerPalette.accentMint
        eyebrowLabel.font = cheerMonospacedFont(size: 11, weight: .bold)
        eyebrowLabel.backgroundColor = .clear
        eyebrowLabel.contentInsets = .zero

        let titleLabel = UILabel()
        titleLabel.text = "POSE CONTROLS"
        titleLabel.textColor = CheerPalette.textPrimary
        titleLabel.font = cheerRoundedFont(.largeTitle, weight: .bold)
        titleLabel.numberOfLines = 0

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Adjust joints, apply saved poses, and check center of mass only when you need it."
        subtitleLabel.textColor = CheerPalette.textSecondary
        subtitleLabel.font = cheerMonospacedFont(size: 12, weight: .regular)
        subtitleLabel.numberOfLines = 0

        let textStack = UIStackView(arrangedSubviews: [eyebrowLabel, titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 8
        textStack.alignment = .leading

        let liveBadge = PaddingLabel()
        liveBadge.text = "COM"
        liveBadge.textColor = CheerPalette.midnight
        liveBadge.font = cheerMonospacedFont(size: 11, weight: .bold)
        liveBadge.backgroundColor = CheerPalette.accentMint

        headerRowStack = UIStackView(arrangedSubviews: [textStack, UIView(), liveBadge])
        headerRowStack.axis = .horizontal
        headerRowStack.spacing = 12
        headerRowStack.alignment = .top
        headerRowStack.distribution = .fill

        panel.contentStack.addArrangedSubview(headerRowStack)

        let presetLabel = UILabel()
        presetLabel.text = "BODY PRESET"
        presetLabel.textColor = CheerPalette.textSecondary
        presetLabel.font = cheerMonospacedFont(size: 11, weight: .bold)

        let presetItems = BodyPreset.allCases.map { $0.rawValue }
        bodyPresetSelector = makeCheerSegmentedControl(items: presetItems)
        bodyPresetSelector.selectedSegmentIndex = 0
        bodyPresetSelector.addTarget(self, action: #selector(didChangeBodyPreset(_:)), for: .valueChanged)

        let presetStack = UIStackView(arrangedSubviews: [presetLabel, bodyPresetSelector])
        presetStack.axis = .vertical
        presetStack.spacing = 8
        panel.contentStack.addArrangedSubview(presetStack)

        return panel
    }

    private func makeToolRail() -> CheerGlassPanel {
        let panel = CheerGlassPanel(padding: .init(top: 10, leading: 10, bottom: 10, trailing: 10))

        toolRailStackView = UIStackView()
        toolRailStackView.axis = .vertical
        toolRailStackView.spacing = 10
        toolRailStackView.alignment = .center
        toolRailStackView.distribution = .fill

        let logoLabel = UILabel()
        logoLabel.text = "CC"
        logoLabel.textAlignment = .center
        logoLabel.textColor = CheerPalette.accentMint
        logoLabel.font = cheerMonospacedFont(size: 15, weight: .bold)

        let diagnosticsRailButton = makeRailButton(symbol: "waveform.path.ecg", accessibilityLabel: "Run diagnostics", action: #selector(didTapRunDiagnostics))
        let libraryRailButton = makeRailButton(symbol: "square.grid.2x2", accessibilityLabel: "Open pose library", action: #selector(didTapQuickPoseLibrary))
        let fitRailButton = makeRailButton(symbol: "viewfinder", accessibilityLabel: "Fit scene to view", action: #selector(didTapQuickFitView))
        let visualsRailButton = makeRailButton(symbol: "sparkles", accessibilityLabel: "Toggle visualizations", action: #selector(didTapQuickVisuals))

        toolRailStackView.addArrangedSubview(logoLabel)
        toolRailStackView.addArrangedSubview(diagnosticsRailButton)
        toolRailStackView.addArrangedSubview(libraryRailButton)
        toolRailStackView.addArrangedSubview(fitRailButton)
        toolRailStackView.addArrangedSubview(visualsRailButton)

        panel.contentStack.addArrangedSubview(toolRailStackView)
        return panel
    }

    private func makeMainActionsPanel() -> CheerGlassPanel {
        let panel = CheerGlassPanel(padding: .init(top: 12, leading: 12, bottom: 12, trailing: 12))

        diagnosticsButton = CheerButton(title: "Run Diagnostics", symbol: "play.fill", style: .accent, compact: true)
        diagnosticsButton.addTarget(self, action: #selector(didTapRunDiagnostics), for: .touchUpInside)

        let poseLibraryButton = CheerButton(title: "Pose Library", symbol: "square.grid.2x2", style: .secondary, compact: true)
        poseLibraryButton.addTarget(self, action: #selector(didTapQuickPoseLibrary), for: .touchUpInside)

        let fitViewButton = CheerButton(title: "Fit View", symbol: "viewfinder", style: .neutral, compact: true)
        fitViewButton.addTarget(self, action: #selector(didTapQuickFitView), for: .touchUpInside)

        let visualsButton = CheerButton(title: "Visuals", symbol: "sparkles", style: .positive, compact: true)
        visualsButton.addTarget(self, action: #selector(didTapQuickVisuals), for: .touchUpInside)

        mainActionsTopRow = UIStackView(arrangedSubviews: [diagnosticsButton, poseLibraryButton])
        mainActionsTopRow.axis = .horizontal
        mainActionsTopRow.spacing = 10
        mainActionsTopRow.distribution = .fillEqually

        mainActionsBottomRow = UIStackView(arrangedSubviews: [fitViewButton, visualsButton])
        mainActionsBottomRow.axis = .horizontal
        mainActionsBottomRow.spacing = 10
        mainActionsBottomRow.distribution = .fillEqually

        panel.contentStack.spacing = 10
        panel.contentStack.addArrangedSubview(mainActionsTopRow)
        panel.contentStack.addArrangedSubview(mainActionsBottomRow)
        return panel
    }

    private func makeSceneCard() -> CheerGlassPanel {
        let panel = CheerGlassPanel(padding: .init(top: 12, leading: 12, bottom: 12, trailing: 12))

        let statusLabel = UILabel()
        statusLabel.text = "MODEL"
        statusLabel.textColor = CheerPalette.textPrimary
        statusLabel.font = cheerMonospacedFont(size: 11, weight: .bold)

        let metaLabel = UILabel()
        metaLabel.text = "Pose workspace"
        metaLabel.textColor = CheerPalette.textSecondary
        metaLabel.font = cheerMonospacedFont(size: 11, weight: .medium)

        controlsToggleButton = CheerButton(title: "Focus", symbol: "rectangle.compress.vertical", style: .neutral, compact: true)
        controlsToggleButton.addTarget(self, action: #selector(didTapToggleChromeVisibility), for: .touchUpInside)
        controlsToggleButton.accessibilityHint = "Hide or show the interface controls."

        let statusRow = UIStackView(arrangedSubviews: [statusLabel, UIView(), metaLabel, controlsToggleButton])
        statusRow.axis = .horizontal
        statusRow.alignment = .center
        statusRow.spacing = 10
        panel.contentStack.addArrangedSubview(statusRow)

        sceneViewportContainer = UIView()
        sceneViewportContainer.translatesAutoresizingMaskIntoConstraints = false
        sceneViewportContainer.backgroundColor = CheerPalette.nightfall
        sceneViewportContainer.layer.cornerCurve = .continuous
        sceneViewportContainer.layer.cornerRadius = 10
        sceneViewportContainer.layer.borderWidth = 1
        sceneViewportContainer.layer.borderColor = UIColor(hex: 0x1F1F1F).cgColor
        panel.contentStack.addArrangedSubview(sceneViewportContainer)

        sceneViewportHeightConstraint = sceneViewportContainer.heightAnchor.constraint(equalToConstant: 360)
        sceneViewportHeightConstraint.isActive = true

        panel.contentStack.addArrangedSubview(transformControlPanel)

        return panel
    }

    private func makeLegendLabel(_ text: String, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = color
        label.font = cheerMonospacedFont(size: 10, weight: .bold)
        return label
    }

    private func makeRailButton(symbol: String, accessibilityLabel: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: symbol)
        configuration.baseForegroundColor = CheerPalette.textSecondary
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        button.configuration = configuration
        button.backgroundColor = CheerPalette.nightfall
        button.layer.cornerCurve = .continuous
        button.layer.cornerRadius = 10
        button.layer.borderWidth = 1
        button.layer.borderColor = CheerPalette.panelBorder.cgColor
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true
        button.widthAnchor.constraint(equalToConstant: 40).isActive = true
        button.accessibilityLabel = accessibilityLabel
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func updateAdaptiveLayout() {
        let regularShell = view.bounds.width >= 860
        chromeStackView.axis = .vertical
        chromeStackView.spacing = 12

        toolRailStackView.axis = regularShell ? .vertical : .horizontal
        toolRailStackView.spacing = regularShell ? 10 : 8
        toolRailStackView.alignment = .center

        toolRailWidthConstraint.isActive = false
        toolRailHeightConstraint.isActive = false
        inspectorWidthConstraint.isActive = false

        let compactHeader = view.bounds.width < 640
        headerRowStack.axis = compactHeader ? .vertical : .horizontal
        headerRowStack.alignment = compactHeader ? .leading : .top

        jointPanelHeightConstraint.constant = regularShell ? 392 : 408
        poseLibraryHeightConstraint.constant = min(max(view.bounds.height * 0.48, 320), 540)
        sceneViewportHeightConstraint.constant = regularShell
            ? min(max(view.bounds.height * 0.56, 360), 700)
            : min(max(view.bounds.width * 0.74, 260), 420)
    }

    @objc private func didChangeBodyPreset(_ sender: UISegmentedControl) {
        let preset = BodyPreset.allCases[sender.selectedSegmentIndex]
        calculator.setPreset(preset)
        scheduleUpdateCOM()
        print("👤 Body preset changed to: \(preset)")
    }

    @objc private func didTapToggleChromeVisibility() {
        setChromeVisible(!chromeVisible)
    }

    @objc private func didTapQuickPoseLibrary() {
        didTapPoseLibrary()
    }

    @objc private func didTapQuickFitView() {
        didTapFitView()
    }

    @objc private func didTapQuickVisuals() {
        didTapToggleVisualizations()
    }

    private func setPoseLibraryVisible(_ isVisible: Bool, animated: Bool = true) {
        poseLibraryVisible = isVisible
        poseLibraryPanel.isUserInteractionEnabled = isVisible && chromeVisible

        let updates = {
            self.poseLibraryPanel.alpha = isVisible ? 1 : 0
            self.poseLibraryPanel.transform = isVisible ? .identity : CGAffineTransform(translationX: 0, y: 24)
        }

        if animated {
            UIView.animate(
                withDuration: 0.28,
                delay: 0,
                usingSpringWithDamping: 0.9,
                initialSpringVelocity: 0.4,
                options: [.beginFromCurrentState, .curveEaseInOut],
                animations: updates
            )
        } else {
            updates()
        }
        print("🎭 Pose library \(isVisible ? "shown" : "hidden")")
    }

    private func setChromeVisible(_ isVisible: Bool, animated: Bool = true) {
        guard chromeVisible != isVisible || animated == false else { return }

        chromeVisible = isVisible
        if !isVisible && poseLibraryVisible {
            setPoseLibraryVisible(false, animated: animated)
        }

        toolRailView.isUserInteractionEnabled = false
        headerPanel.isUserInteractionEnabled = false
        mainActionsPanel.isUserInteractionEnabled = false
        inspectorStackView.isUserInteractionEnabled = false
        jointControlPanel.isUserInteractionEnabled = isVisible
        transformControlPanel.isUserInteractionEnabled = isVisible

        let updates = {
            self.jointControlPanel.alpha = isVisible ? 1 : 0
            self.jointControlPanel.transform = isVisible ? .identity : CGAffineTransform(translationX: 0, y: 14)
            self.transformControlPanel.alpha = isVisible ? 1 : 0
            self.transformControlPanel.transform = isVisible ? .identity : CGAffineTransform(translationX: 0, y: 14)
            self.updateControlsToggleButton()
        }

        if animated {
            UIView.animate(
                withDuration: 0.25,
                delay: 0,
                usingSpringWithDamping: 0.94,
                initialSpringVelocity: 0.4,
                options: [.beginFromCurrentState, .curveEaseInOut],
                animations: updates
            )
        } else {
            updates()
        }

        print(isVisible ? "🧩 Controls shown" : "🎬 Focus mode enabled")
    }

    private func updateControlsToggleButton() {
        let title = chromeVisible ? "Focus" : "Controls"
        controlsToggleButton.setTitle(title, for: .normal)
        controlsToggleButton.accessibilityLabel = chromeVisible ? "Hide controls" : "Show controls"
    }

    private func prefersFocusModeByDefault() -> Bool {
        let shortSide = min(view.bounds.width, view.bounds.height)
        let compactHeight = view.bounds.height < 760
        return traitCollection.horizontalSizeClass == .compact && (shortSide < 430 || compactHeight)
    }

    @objc func didTapRunDiagnostics() {
        if validationHarness != nil { return } // Already running

        print("▶️ Starting Diagnostics...")

        validationOverlay?.isHidden = false

        // Show Diagnostics Overlay
        let overlay = DiagnosticsOverlay(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(overlay)

        // Disable interaction with other controls while running
        sceneManager.sceneView.isUserInteractionEnabled = false
        chromeScrollView.isUserInteractionEnabled = false
        jointControlPanel.isUserInteractionEnabled = false
        transformControlPanel.isUserInteractionEnabled = false
        poseLibraryPanel.isUserInteractionEnabled = false

        // Handle close
        overlay.onClose = { [weak self] in
            self?.sceneManager.sceneView.isUserInteractionEnabled = true
            self?.chromeScrollView.isUserInteractionEnabled = true
            self?.jointControlPanel.isUserInteractionEnabled = self?.chromeVisible ?? false
            self?.transformControlPanel.isUserInteractionEnabled = self?.chromeVisible ?? false
            self?.poseLibraryPanel.isUserInteractionEnabled = (self?.poseLibraryVisible ?? false) && (self?.chromeVisible ?? false)
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
            self?.validationOverlay?.isHidden = true
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

        if validationHarness != nil {
            DispatchQueue.main.async { [weak self] in
                self?.validationOverlay?.updateMetrics(result: result)
            }
        }

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
        case .keyboardH:
            setChromeVisible(!chromeVisible)
        default:
            super.pressesBegan(presses, with: event)
        }
    }
}

// MARK: - JointControlPanelDelegate
extension SceneViewController: JointControlPanelDelegate {
    func didTapJointSelection(sourceView: UIView) {
        let picker = JointPickerViewController()
        picker.joints = sceneManager.controllableJoints
        picker.selectedJointName = selectedJoint?.name
        picker.onSelectJoint = { [weak self] jointName in
            self?.selectJoint(named: jointName)
        }

        let navigationController = UINavigationController(rootViewController: picker)
        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        if let popover = navigationController.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }

        present(navigationController, animated: true)
    }

    func selectJoint(named name: String) {
        clearSelectedJointHighlight()
        selectedJoint = nil

        if let joint = sceneManager.findBone(named: name) {
            selectedJoint = joint
            applySelectedJointHighlight(for: joint)

            let displayName = formatJointName(name)

            // Update UI
            jointControlPanel.updateJointSelection(name: displayName, angles: joint.eulerAngles)

            print("✅ Selected joint: \(displayName)")
            print(
                "   Current euler angles: x=\(joint.eulerAngles.x * 180 / .pi)°, y=\(joint.eulerAngles.y * 180 / .pi)°, z=\(joint.eulerAngles.z * 180 / .pi)°"
            )
            print("   World position: \(joint.presentation.worldPosition)")
        } else {
            print("❌ Failed to find joint: \(name)")
        }
    }

    func didIncrementAngle(axis: JointAxis) {
        didRotateJoint(axis: axis, direction: .positive)
    }

    func didDecrementAngle(axis: JointAxis) {
        didRotateJoint(axis: axis, direction: .negative)
    }

    func didBeginIncrementingAngle(axis: JointAxis) {}
    func didEndIncrementingAngle(axis: JointAxis) {}
    func didBeginDecrementingAngle(axis: JointAxis) {}
    func didEndDecrementingAngle(axis: JointAxis) {}
    func didTapJointPresets(sourceView: UIView) {
        let alert = UIAlertController(
            title: "Joint Presets",
            message: "Joint presets are available in the animator workspace.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func didTapSaveJointPreset() {
        let alert = UIAlertController(
            title: "Joint Presets",
            message: "Save joint presets in the animator workspace.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func didRotateJoint(axis: JointAxis, direction: RotationDirection) {
        guard let joint = selectedJoint else {
            print("⚠️ No joint selected for rotation")
            return
        }

        let rotationAmount: Float = 1.0 * .pi / 180  // 1 degree fine tuning
        let delta = (direction == .positive) ? rotationAmount : -rotationAmount

        var newAngles = joint.eulerAngles
        switch axis {
        case .xAxis: newAngles.x += delta
        case .yAxis: newAngles.y += delta
        case .zAxis: newAngles.z += delta
        }

        if let jointName = joint.name {
            joint.eulerAngles = JointLimits.clampAngles(for: jointName, angles: newAngles)
        } else {
            joint.eulerAngles = newAngles
        }

        let x = joint.eulerAngles.x * 180 / .pi
        let y = joint.eulerAngles.y * 180 / .pi
        let z = joint.eulerAngles.z * 180 / .pi
        print("🎮 Rotated joint on \(axis.rawValue)-axis. New angles: (x: \(x)°, y: \(y)°, z: \(z)°)")

        jointControlPanel.updateAngleDisplays(angles: joint.eulerAngles)
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

        jointControlPanel.updateAngleDisplays(angles: joint.eulerAngles)
    }

    func didChangeJointAngle(axis: JointAxis, value: Float) {
        guard let joint = selectedJoint else {
            print("⚠️ No joint selected for angle change")
            return
        }
        let angle = value * .pi / 180

        var newAngles = joint.eulerAngles
        switch axis {
        case .xAxis: newAngles.x = angle
        case .yAxis: newAngles.y = angle
        case .zAxis: newAngles.z = angle
        }

        if let jointName = joint.name {
            joint.eulerAngles = JointLimits.clampAngles(for: jointName, angles: newAngles)
        } else {
            joint.eulerAngles = newAngles
        }

        print("🎚️ Set \(axis.rawValue)-axis angle to \(value)°")

        scheduleUpdateCOM()
    }

    // Pose Library
    func didTapPoseLibrary() {
        setPoseLibraryVisible(!poseLibraryVisible)
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
        _ = cameraManager.fitToView()
    }

    func didTapToggleVisualizations() {
        visualizationsManager.toggleVisualizations()
    }

    // Helpers
    private func getAngleForCurrentAxis(joint: SCNNode) -> Float {
        switch jointControlMode {
        case .xAxis: return joint.eulerAngles.x * 180 / .pi
        case .yAxis: return joint.eulerAngles.y * 180 / .pi
        case .zAxis: return joint.eulerAngles.z * 180 / .pi
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
        for joint in sceneManager.controllableJoints {
            let jointName = joint.rawValue
            if let boneNode = sceneManager.cachedBoneNodes[jointName] {
                jointPositions[jointName] = boneNode.eulerAngles
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
        for (name, components) in pose.jointAngles where components.count == 3 {
            #if os(macOS)
            jointAngles[name] = SCNVector3(
                CGFloat(components[0]), CGFloat(components[1]), CGFloat(components[2])
            )
            #else
            jointAngles[name] = SCNVector3(components[0], components[1], components[2])
            #endif
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

    func didTapPoseLibraryFromTransformPanel() {
        didTapPoseLibrary()
    }

    func didTapResetPoseFromTransformPanel() {
        didTapResetPose()
    }

    func didTapFitViewFromTransformPanel() {
        didTapFitView()
    }

    func didTapToggleVisualizationsFromTransformPanel() {
        didTapToggleVisualizations()
    }

    func didBeginContinuousTransform(direction: TransformDirection) {
        continuousTransformTimer?.invalidate()
        continuousTransformTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            self?.didTapTransform(direction: direction)
        }
        didTapTransform(direction: direction)
    }

    func didEndContinuousTransform() {
        continuousTransformTimer?.invalidate()
        continuousTransformTimer = nil
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
        case .forward: transformForward()
        case .backward: transformBackward()
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

    func transformForward() {
        switch currentTransformMode {
        case .position: sceneManager.characterNode.position.z += transformStep
        case .rotation: sceneManager.characterNode.eulerAngles.z += transformStep * .pi / 180
        case .scale: break
        }
        scheduleUpdateCOM()
    }

    func transformBackward() {
        switch currentTransformMode {
        case .position: sceneManager.characterNode.position.z -= transformStep
        case .rotation: sceneManager.characterNode.eulerAngles.z -= transformStep * .pi / 180
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
