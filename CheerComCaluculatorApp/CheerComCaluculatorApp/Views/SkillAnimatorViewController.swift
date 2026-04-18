import UIKit
import SceneKit
import ModelRigKit

/// Root view controller for Skill Animator mode.
///
/// This is the *only* authoring surface: joint controls live right here, editing
/// a joint at any timeline frame auto-creates/updates a keyframe at that frame,
/// and scrubbing between keyframes shows a slerp'd preview. Saved poses from
/// legacy Pose Mode are available as an optional import drawer.
final class SkillAnimatorViewController: UIViewController {

    // Scene
    private var sceneManager: CheerCOMSceneManager!
    private var viewportContainer: UIView!
    private var controlsPanel: UIView!
    private var controlsScrollView: UIScrollView!
    private var controlsStackView: UIStackView!
    private var savedPoseStackView: UIStackView!
    private var jointControlPanel: JointControlPanel!
    private var selectedKeyframeLabel: UILabel!
    private var selectedFrameLabel: UILabel!
    private var poseLibraryContainer: UIStackView!
    private var poseLibraryDisclosure: UIButton!
    private var poseLibraryExpanded = false
    private var mirrorToggleButton: UIButton!
    private var transformControlPanel: TransformControlPanel!

    // Playback
    private var playbackBar: UIStackView!
    private var playPauseButton: UIButton!
    private var playbackFrameLabel: UILabel!
    private var playbackLink: CADisplayLink?
    private var lastPlaybackTimestamp: CFTimeInterval = 0
    private var isPlaying = false
    private let playbackFps: Double = 30

    // Mirror + transform state
    private var mirrorEnabled = true
    private var currentTransformMode: TransformMode = .position
    private var transformStep: Float = 0.05
    private var transformStepMultiplier: Float = 1.0

    // Top controls
    private var skillPickerButton: UIButton!
    private var cameraAngleLabel: UILabel!
    private var vocabButton: UIButton!
    private var poseLibraryModalButton: UIButton!
    private var saveSessionButton: UIButton!
    private var exportButton: UIButton!

    // Timeline
    private var timelineView: SkillTimelineView!
    private var wideLayoutConstraints: [NSLayoutConstraint] = []
    private var compactLayoutConstraints: [NSLayoutConstraint] = []
    private var usesWideLayout = false

    // State
    private var savedPoses: [SavedPose] = []
    /// Full authoring state: frame index -> complete bone euler snapshot.
    /// Every entry in this dict corresponds to a marker in `timelineView.keyframes`.
    private var keyframePoses: [Int: [String: SCNVector3]] = [:]
    private var selectedAtomId = "back_handspring"
    private var selectedJoint: SCNNode?
    private let totalFrames = 25
    private var workspaceSaveTimer: Timer?
    private var continuousTransformTimer: Timer?
    private var backgroundObservers: [NSObjectProtocol] = []
    private var saveButtonResetWorkItem: DispatchWorkItem?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupLayout()
        setupScene()
        setupControls()
        refreshSkillPickerTitle()
        registerWorkspaceObservers()
        if !restoreWorkspaceIfPresent() {
            seedInitialKeyframes()
        }
        refreshSavedPoses()
        updateSelectedFrameLabel()
    }

    deinit {
        workspaceSaveTimer?.invalidate()
        continuousTransformTimer?.invalidate()
        backgroundObservers.forEach(NotificationCenter.default.removeObserver)
    }

    private func setupLayout() {
        viewportContainer = UIView()
        viewportContainer.translatesAutoresizingMaskIntoConstraints = false
        viewportContainer.backgroundColor = .black
        view.addSubview(viewportContainer)

        controlsPanel = UIView()
        controlsPanel.translatesAutoresizingMaskIntoConstraints = false
        controlsPanel.backgroundColor = UIColor.secondarySystemBackground
        controlsPanel.layer.cornerRadius = 14
        controlsPanel.layer.borderWidth = 1
        controlsPanel.layer.borderColor = UIColor.separator.cgColor
        view.addSubview(controlsPanel)

        controlsScrollView = UIScrollView()
        controlsScrollView.translatesAutoresizingMaskIntoConstraints = false
        controlsScrollView.alwaysBounceVertical = true
        controlsPanel.addSubview(controlsScrollView)

        controlsStackView = UIStackView()
        controlsStackView.translatesAutoresizingMaskIntoConstraints = false
        controlsStackView.axis = .vertical
        controlsStackView.spacing = 12
        controlsScrollView.addSubview(controlsStackView)
        setupAuthoringPanel()

        timelineView = SkillTimelineView()
        timelineView.translatesAutoresizingMaskIntoConstraints = false
        timelineView.numFrames = totalFrames
        timelineView.keyframes = [0, 12, 24]
        timelineView.delegate = self
        view.addSubview(timelineView)

        setupPlaybackBar()

        let sharedConstraints = [
            viewportContainer.topAnchor.constraint(equalTo: view.topAnchor, constant: 60),

            playbackBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            playbackBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            playbackBar.bottomAnchor.constraint(equalTo: timelineView.topAnchor, constant: -8),
            playbackBar.heightAnchor.constraint(equalToConstant: 36),

            timelineView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            timelineView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            timelineView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            timelineView.heightAnchor.constraint(equalToConstant: 72),

            controlsScrollView.topAnchor.constraint(equalTo: controlsPanel.topAnchor, constant: 14),
            controlsScrollView.leadingAnchor.constraint(equalTo: controlsPanel.leadingAnchor, constant: 14),
            controlsScrollView.trailingAnchor.constraint(equalTo: controlsPanel.trailingAnchor, constant: -14),
            controlsScrollView.bottomAnchor.constraint(equalTo: controlsPanel.bottomAnchor, constant: -14),

            controlsStackView.topAnchor.constraint(equalTo: controlsScrollView.contentLayoutGuide.topAnchor),
            controlsStackView.leadingAnchor.constraint(equalTo: controlsScrollView.contentLayoutGuide.leadingAnchor),
            controlsStackView.trailingAnchor.constraint(equalTo: controlsScrollView.contentLayoutGuide.trailingAnchor),
            controlsStackView.bottomAnchor.constraint(equalTo: controlsScrollView.contentLayoutGuide.bottomAnchor),
            controlsStackView.widthAnchor.constraint(equalTo: controlsScrollView.frameLayoutGuide.widthAnchor)
        ]

        wideLayoutConstraints = [
            viewportContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            viewportContainer.trailingAnchor.constraint(equalTo: controlsPanel.leadingAnchor, constant: -12),
            viewportContainer.bottomAnchor.constraint(equalTo: playbackBar.topAnchor, constant: -8),

            controlsPanel.topAnchor.constraint(equalTo: viewportContainer.topAnchor),
            controlsPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            controlsPanel.bottomAnchor.constraint(equalTo: viewportContainer.bottomAnchor),
            controlsPanel.widthAnchor.constraint(equalToConstant: 300)
        ]

        compactLayoutConstraints = [
            viewportContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            viewportContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            viewportContainer.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.34),

            controlsPanel.topAnchor.constraint(equalTo: viewportContainer.bottomAnchor, constant: 12),
            controlsPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            controlsPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            controlsPanel.bottomAnchor.constraint(equalTo: playbackBar.topAnchor, constant: -8)
        ]

        NSLayoutConstraint.activate(sharedConstraints)
        NSLayoutConstraint.activate(compactLayoutConstraints)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateAuthoringPanelLayout()
    }

    private func setupScene() {
        sceneManager = CheerCOMSceneManager(view: viewportContainer)
        sceneManager.loadCharacter()
        sceneManager.frameCharacter()
    }

    private func setupControls() {
        skillPickerButton = UIButton(type: .system)
        skillPickerButton.translatesAutoresizingMaskIntoConstraints = false
        skillPickerButton.setTitle("Skill: (none)", for: .normal)
        skillPickerButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        skillPickerButton.addTarget(self, action: #selector(pickSkill), for: .touchUpInside)
        view.addSubview(skillPickerButton)

        cameraAngleLabel = UILabel()
        cameraAngleLabel.translatesAutoresizingMaskIntoConstraints = false
        cameraAngleLabel.text = "Camera: orbital (96)"
        cameraAngleLabel.textColor = .label
        cameraAngleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        view.addSubview(cameraAngleLabel)

        vocabButton = UIButton(type: .system)
        vocabButton.translatesAutoresizingMaskIntoConstraints = false
        vocabButton.setTitle("Vocab", for: .normal)
        vocabButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        vocabButton.addTarget(self, action: #selector(openVocabulary), for: .touchUpInside)
        view.addSubview(vocabButton)

        poseLibraryModalButton = UIButton(type: .system)
        poseLibraryModalButton.translatesAutoresizingMaskIntoConstraints = false
        var poseConfig = UIButton.Configuration.tinted()
        poseConfig.image = UIImage(systemName: "figure.stand")
        poseConfig.baseForegroundColor = .secondaryLabel
        poseConfig.cornerStyle = .capsule
        poseConfig.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
        poseLibraryModalButton.configuration = poseConfig
        poseLibraryModalButton.addTarget(self, action: #selector(openPoseLibraryModal), for: .touchUpInside)
        view.addSubview(poseLibraryModalButton)

        saveSessionButton = UIButton(type: .system)
        saveSessionButton.translatesAutoresizingMaskIntoConstraints = false
        var saveConfig = UIButton.Configuration.tinted()
        saveConfig.title = "Save Session"
        saveConfig.image = UIImage(systemName: "square.and.arrow.down")
        saveConfig.imagePadding = 6
        saveConfig.baseForegroundColor = .systemGreen
        saveConfig.cornerStyle = .medium
        saveConfig.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        saveSessionButton.configuration = saveConfig
        saveSessionButton.addTarget(self, action: #selector(saveSessionTapped), for: .touchUpInside)
        view.addSubview(saveSessionButton)

        exportButton = UIButton(type: .system)
        exportButton.translatesAutoresizingMaskIntoConstraints = false
        var exportConfiguration = UIButton.Configuration.filled()
        exportConfiguration.title = "Export (96 angles)"
        exportConfiguration.baseBackgroundColor = .systemBlue
        exportConfiguration.baseForegroundColor = .white
        exportConfiguration.cornerStyle = .medium
        exportConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        exportButton.configuration = exportConfiguration
        exportButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        exportButton.addTarget(self, action: #selector(exportTapped), for: .touchUpInside)
        view.addSubview(exportButton)

        NSLayoutConstraint.activate([
            skillPickerButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            skillPickerButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            skillPickerButton.trailingAnchor.constraint(lessThanOrEqualTo: vocabButton.leadingAnchor, constant: -8),

            cameraAngleLabel.centerYAnchor.constraint(equalTo: skillPickerButton.centerYAnchor),
            cameraAngleLabel.leadingAnchor.constraint(equalTo: skillPickerButton.trailingAnchor, constant: 24),

            saveSessionButton.centerYAnchor.constraint(equalTo: skillPickerButton.centerYAnchor),
            saveSessionButton.trailingAnchor.constraint(equalTo: exportButton.leadingAnchor, constant: -12),

            exportButton.centerYAnchor.constraint(equalTo: skillPickerButton.centerYAnchor),
            exportButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            vocabButton.centerYAnchor.constraint(equalTo: skillPickerButton.centerYAnchor),
            vocabButton.trailingAnchor.constraint(equalTo: poseLibraryModalButton.leadingAnchor, constant: -12),

            poseLibraryModalButton.centerYAnchor.constraint(equalTo: skillPickerButton.centerYAnchor),
            poseLibraryModalButton.trailingAnchor.constraint(equalTo: saveSessionButton.leadingAnchor, constant: -12)
        ])
    }

    private func setupAuthoringPanel() {
        let titleLabel = UILabel()
        titleLabel.text = "Keyframe Controls"
        titleLabel.textColor = .label
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)

        selectedKeyframeLabel = UILabel()
        selectedKeyframeLabel.textColor = .secondaryLabel
        selectedKeyframeLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        selectedKeyframeLabel.numberOfLines = 0

        selectedFrameLabel = UILabel()
        selectedFrameLabel.textColor = .secondaryLabel
        selectedFrameLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        selectedFrameLabel.numberOfLines = 0

        jointControlPanel = JointControlPanel(width: view.bounds.width)
        jointControlPanel.delegate = self
        jointControlPanel.heightAnchor.constraint(equalToConstant: 392).isActive = true

        // Mirror toggle row
        mirrorToggleButton = UIButton(type: .system)
        var mirrorConfig = UIButton.Configuration.tinted()
        mirrorConfig.image = UIImage(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
        mirrorConfig.title = "Mirror: ON"
        mirrorConfig.imagePadding = 6
        mirrorConfig.baseForegroundColor = .systemGreen
        mirrorConfig.cornerStyle = .medium
        mirrorConfig.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        mirrorToggleButton.configuration = mirrorConfig
        mirrorToggleButton.addTarget(self, action: #selector(toggleMirror), for: .touchUpInside)

        // Transform panel
        transformControlPanel = TransformControlPanel(width: view.bounds.width)
        transformControlPanel.delegate = self
        transformControlPanel.translatesAutoresizingMaskIntoConstraints = false
        transformControlPanel.updateModeDisplay(mode: currentTransformMode, step: transformStep)

        // Collapsible "Pose Library" drawer
        poseLibraryDisclosure = UIButton(type: .system)
        var discConfig = UIButton.Configuration.tinted()
        discConfig.title = "▸ Import from Pose Library"
        discConfig.baseForegroundColor = .secondaryLabel
        discConfig.cornerStyle = .medium
        discConfig.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        poseLibraryDisclosure.configuration = discConfig
        poseLibraryDisclosure.contentHorizontalAlignment = .leading
        poseLibraryDisclosure.addTarget(self, action: #selector(togglePoseLibrary), for: .touchUpInside)

        savedPoseStackView = UIStackView()
        savedPoseStackView.axis = .vertical
        savedPoseStackView.spacing = 8

        poseLibraryContainer = UIStackView(arrangedSubviews: [savedPoseStackView])
        poseLibraryContainer.axis = .vertical
        poseLibraryContainer.spacing = 8
        poseLibraryContainer.isHidden = true

        controlsStackView.addArrangedSubview(mirrorToggleButton)
        controlsStackView.addArrangedSubview(jointControlPanel)
        controlsStackView.addArrangedSubview(transformControlPanel)
        controlsStackView.addArrangedSubview(titleLabel)
        controlsStackView.addArrangedSubview(selectedKeyframeLabel)
        controlsStackView.addArrangedSubview(selectedFrameLabel)
        controlsStackView.addArrangedSubview(poseLibraryDisclosure)
        controlsStackView.addArrangedSubview(poseLibraryContainer)
        applyMirrorToggleAppearance()
    }

    private func setupPlaybackBar() {
        let restartButton = makePlaybackButton(systemName: "backward.end.fill", action: #selector(playbackRestart))
        playPauseButton = makePlaybackButton(systemName: "play.fill", action: #selector(playbackTogglePlay))
        let endButton = makePlaybackButton(systemName: "forward.end.fill", action: #selector(playbackJumpToEnd))

        playbackFrameLabel = UILabel()
        playbackFrameLabel.text = "0 / \(totalFrames - 1)"
        playbackFrameLabel.textColor = .secondaryLabel
        playbackFrameLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        playbackFrameLabel.textAlignment = .right

        playbackBar = UIStackView(arrangedSubviews: [
            restartButton, playPauseButton, endButton, UIView(), playbackFrameLabel
        ])
        playbackBar.axis = .horizontal
        playbackBar.spacing = 12
        playbackBar.alignment = .center
        playbackBar.distribution = .fill
        playbackBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playbackBar)
    }

    private func makePlaybackButton(systemName: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.tinted()
        config.image = UIImage(systemName: systemName)
        config.baseForegroundColor = .label
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        button.configuration = config
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func updateAuthoringPanelLayout() {
        let shouldUseWideLayout = view.bounds.width >= 820
        cameraAngleLabel?.isHidden = view.bounds.width < 520
        skillPickerButton?.titleLabel?.font = UIFont.preferredFont(
            forTextStyle: view.bounds.width < 520 ? .subheadline : .headline
        )
        guard shouldUseWideLayout != usesWideLayout else { return }

        NSLayoutConstraint.deactivate(shouldUseWideLayout ? compactLayoutConstraints : wideLayoutConstraints)
        NSLayoutConstraint.activate(shouldUseWideLayout ? wideLayoutConstraints : compactLayoutConstraints)
        usesWideLayout = shouldUseWideLayout
    }

    // MARK: - Keyframe state

    /// Snapshot current scene bone state across all controllable joints.
    private func currentPoseSnapshot() -> [String: SCNVector3] {
        var result: [String: SCNVector3] = [:]
        for joint in sceneManager.controllableJoints {
            if let node = sceneManager.cachedBoneNodes[joint.rawValue] {
                result[joint.rawValue] = node.eulerAngles
            }
        }
        return result
    }

    /// Seed each initial timeline keyframe with the current (T-pose) bone state.
    private func seedInitialKeyframes() {
        let snapshot = currentPoseSnapshot()
        for frame in timelineView.keyframes {
            keyframePoses[frame] = snapshot
        }
        timelineView.currentFrame = timelineView.keyframes.first ?? 0
        previewCurrentFrame(animated: false)
    }

    /// Build a KeyframeInterpolator from current authoring state.
    private func makeInterpolator() -> KeyframeInterpolator {
        let resolved: [KeyframeInterpolator.ResolvedKeyframe] = keyframePoses
            .sorted { $0.key < $1.key }
            .map { KeyframeInterpolator.ResolvedKeyframe(frameIndex: $0.key, jointAngles: $0.value) }
        return KeyframeInterpolator(keyframes: resolved, numFrames: totalFrames)
    }

    /// Apply the interpolated (or exact) pose at the current playhead frame.
    private func previewCurrentFrame(animated: Bool = true) {
        guard !keyframePoses.isEmpty else { return }
        let frame = timelineView.currentFrame
        let angles = makeInterpolator().angles(atFrame: frame)
        applyJointAngles(angles, animated: animated)
        // Keep joint slider display fresh if a joint is selected
        if let joint = selectedJoint {
            jointControlPanel.updateAngleDisplays(angles: joint.eulerAngles)
        }
        updateSelectedFrameLabel()
    }

    /// Capture the current bone state into the keyframe at `frame`,
    /// creating a new timeline marker if one does not already exist.
    private func captureKeyframe(at frame: Int) {
        let snapshot = currentPoseSnapshot()
        keyframePoses[frame] = snapshot

        if !timelineView.keyframes.contains(frame) {
            var updated = timelineView.keyframes + [frame]
            updated.sort()
            timelineView.keyframes = updated
        }
        updateSelectedFrameLabel()
        scheduleWorkspaceSave()
    }

    private func updateSelectedFrameLabel() {
        let frame = timelineView.currentFrame
        let isKeyframe = timelineView.keyframes.contains(frame)
        selectedKeyframeLabel?.text = isKeyframe
            ? "Frame \(frame) — keyframe (\(timelineView.keyframes.count) total)"
            : "Frame \(frame) — interpolated (edit to create keyframe)"
        selectedFrameLabel?.text = "Playhead: frame \(frame) of \(totalFrames - 1)"
        playbackFrameLabel?.text = "\(frame) / \(totalFrames - 1)"
    }

    private func registerWorkspaceObservers() {
        let notifications: [NSNotification.Name] = [
            UIApplication.didEnterBackgroundNotification,
            UIApplication.willTerminateNotification,
            UIApplication.willResignActiveNotification
        ]

        backgroundObservers = notifications.map {
            NotificationCenter.default.addObserver(
                forName: $0,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.persistWorkspace(showFeedback: false)
            }
        }
    }

    private func scheduleWorkspaceSave() {
        workspaceSaveTimer?.invalidate()
        workspaceSaveTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
            self?.persistWorkspace(showFeedback: false)
        }
    }

    private func persistWorkspace(showFeedback: Bool) {
        workspaceSaveTimer?.invalidate()
        workspaceSaveTimer = nil

        let state = AnimatorWorkspaceState(
            selectedAtomId: selectedAtomId,
            currentFrame: timelineView.currentFrame,
            keyframePoses: keyframePoses.mapValues { jointMap in
                jointMap.reduce(into: [String: [Float]]()) { partialResult, item in
                    partialResult[item.key] = Self.array(from: item.value)
                }
            },
            selectedJointName: selectedJoint?.name,
            mirrorEnabled: mirrorEnabled,
            transformMode: currentTransformMode,
            transformStepMultiplier: transformStepMultiplier,
            poseLibraryExpanded: poseLibraryExpanded,
            characterPosition: Self.array(from: sceneManager.characterNode.position),
            characterEulerAngles: Self.array(from: sceneManager.characterNode.eulerAngles),
            characterScale: Self.array(from: sceneManager.characterNode.scale)
        )

        do {
            try AnimatorWorkspaceStorage.shared.save(state)
            if showFeedback {
                showSaveConfirmation()
            }
        } catch {
            showAlert(title: "Save failed", message: "\(error)")
        }
    }

    private func restoreWorkspaceIfPresent() -> Bool {
        guard let state = AnimatorWorkspaceStorage.shared.loadIfPresent(), !state.keyframePoses.isEmpty else {
            return false
        }

        keyframePoses = state.keyframePoses.mapValues { jointMap in
            jointMap.reduce(into: [String: SCNVector3]()) { partialResult, item in
                partialResult[item.key] = Self.vector3(from: item.value)
            }
        }

        let restoredFrames = keyframePoses.keys.sorted()
        guard !restoredFrames.isEmpty else { return false }

        timelineView.keyframes = restoredFrames
        timelineView.currentFrame = min(max(0, state.currentFrame), totalFrames - 1)
        selectedAtomId = state.selectedAtomId
        mirrorEnabled = state.mirrorEnabled
        poseLibraryExpanded = state.poseLibraryExpanded
        currentTransformMode = state.transformMode
        transformStepMultiplier = state.transformStepMultiplier
        transformStep = baseTransformStep(for: currentTransformMode) * transformStepMultiplier

        sceneManager.characterNode.position = Self.vector3(from: state.characterPosition)
        sceneManager.characterNode.eulerAngles = Self.vector3(from: state.characterEulerAngles)
        sceneManager.characterNode.scale = Self.vector3(from: state.characterScale)

        refreshSkillPickerTitle()
        applyMirrorToggleAppearance()
        transformControlPanel.updateStepMultiplierSelection(transformStepMultiplier)
        transformControlPanel.updateModeDisplay(mode: currentTransformMode, step: transformStep)

        poseLibraryContainer.isHidden = !poseLibraryExpanded
        var disclosureConfig = poseLibraryDisclosure.configuration
        disclosureConfig?.title = poseLibraryExpanded ? "▾ Import from Pose Library" : "▸ Import from Pose Library"
        poseLibraryDisclosure.configuration = disclosureConfig

        if let selectedJointName = state.selectedJointName {
            selectJoint(named: selectedJointName)
        }

        previewCurrentFrame(animated: false)
        return true
    }

    // MARK: - Saved pose library (import drawer)

    private func refreshSavedPoses() {
        savedPoses = PoseStorageManager.shared.loadPoses()
        rebuildSavedPoseButtons()
    }

    @objc private func togglePoseLibrary() {
        poseLibraryExpanded.toggle()
        poseLibraryContainer.isHidden = !poseLibraryExpanded
        var config = poseLibraryDisclosure.configuration
        config?.title = poseLibraryExpanded ? "▾ Import from Pose Library" : "▸ Import from Pose Library"
        poseLibraryDisclosure.configuration = config
        if poseLibraryExpanded { refreshSavedPoses() }
        scheduleWorkspaceSave()
    }

    private func rebuildSavedPoseButtons() {
        savedPoseStackView.arrangedSubviews.forEach { view in
            savedPoseStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        guard !savedPoses.isEmpty else {
            let emptyLabel = UILabel()
            emptyLabel.text = "No saved poses yet. Open the legacy Pose Library (top-left button) to create some."
            emptyLabel.textColor = .secondaryLabel
            emptyLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
            emptyLabel.numberOfLines = 0
            savedPoseStackView.addArrangedSubview(emptyLabel)
            return
        }

        let hintLabel = UILabel()
        hintLabel.text = "Tap a saved pose to load it onto the model at the current playhead frame."
        hintLabel.textColor = .secondaryLabel
        hintLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        hintLabel.numberOfLines = 0
        savedPoseStackView.addArrangedSubview(hintLabel)

        for pose in savedPoses {
            let button = UIButton(type: .system)
            var configuration = UIButton.Configuration.tinted()
            configuration.title = pose.name
            configuration.subtitle = "Load into frame \(timelineView.currentFrame)"
            configuration.baseForegroundColor = .systemBlue
            configuration.cornerStyle = .medium
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
            button.configuration = configuration
            button.contentHorizontalAlignment = .leading
            button.addAction(UIAction { [weak self] _ in
                self?.importSavedPoseAtCurrentFrame(pose)
            }, for: .touchUpInside)
            savedPoseStackView.addArrangedSubview(button)
        }
    }

    private func importSavedPoseAtCurrentFrame(_ pose: SavedPose) {
        var angles: [String: SCNVector3] = [:]
        for (name, components) in pose.jointAngles where components.count == 3 {
            #if os(macOS)
            angles[name] = SCNVector3(
                CGFloat(components[0]), CGFloat(components[1]), CGFloat(components[2])
            )
            #else
            angles[name] = SCNVector3(components[0], components[1], components[2])
            #endif
        }
        applyJointAngles(angles, animated: true)
        captureKeyframe(at: timelineView.currentFrame)
        scheduleWorkspaceSave()
    }

    // MARK: - Actions

    @objc private func pickSkill() {
        let manifest = VocabularyManager.shared.load()
        let alert = UIAlertController(
            title: "Select Skill",
            message: manifest.atoms.isEmpty ? "No atoms yet — add some via Vocabulary" : nil,
            preferredStyle: .actionSheet
        )
        for atom in manifest.atoms {
            alert.addAction(UIAlertAction(title: atom.displayName, style: .default) { [weak self] _ in
                self?.selectedAtomId = atom.id
                self?.refreshSkillPickerTitle()
                self?.scheduleWorkspaceSave()
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = skillPickerButton
            popover.sourceRect = skillPickerButton.bounds
        }
        present(alert, animated: true)
    }

    @objc private func openVocabulary() {
        let vc = VocabularyManagementViewController(style: .insetGrouped)
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true)
    }

    @objc private func openPoseLibraryModal() {
        let poseVC = SceneViewController()
        poseVC.title = "Pose Library"
        let nav = UINavigationController(rootViewController: poseVC)
        nav.modalPresentationStyle = .fullScreen
        poseVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissPoseLibraryModal)
        )
        present(nav, animated: true)
    }

    @objc private func dismissPoseLibraryModal() {
        dismiss(animated: true) { [weak self] in
            // Refresh the import drawer in case user saved new poses.
            self?.refreshSavedPoses()
        }
    }

    @objc private func exportTapped() {
        runExport()
    }

    @objc private func saveSessionTapped() {
        persistWorkspace(showFeedback: true)
    }

    private func runExport() {
        let sortedFrames = keyframePoses.keys.sorted()
        guard sortedFrames.count >= 2 else {
            showAlert(title: "Export", message: "Need at least 2 keyframes to export. Scrub the timeline and edit a joint to create more.")
            return
        }

        let keyframes: [SkillKeyframe] = sortedFrames.map { frame in
            let angles = keyframePoses[frame] ?? [:]
            var inline: [String: [Float]] = [:]
            for (name, vec) in angles {
                inline[name] = [Float(vec.x), Float(vec.y), Float(vec.z)]
            }
            return SkillKeyframe(
                poseId: nil,
                inlineJointAngles: inline,
                frameIndex: frame,
                bodylineId: nil
            )
        }

        let animation = SkillAnimation(
            name: "manual_test",
            atomId: selectedAtomId,
            category: "tumbling",
            numFrames: totalFrames,
            keyframes: keyframes
        )

        // Inline angles are carried by the keyframes themselves; these resolvers
        // are only invoked for legacy poseId-based keyframes (none here).
        let poseResolver: (UUID) -> [String: SCNVector3]? = { _ in nil }
        let bodylineResolver: (UUID) -> String? = { _ in nil }

        let exporter = SkillAnimationExporter(
            sceneView: sceneManager.sceneView,
            characterNode: sceneManager.characterNode,
            boneNodes: sceneManager.cachedBoneNodes
        )

        do {
            let urls = try exporter.export(
                animation: animation,
                poseResolver: poseResolver,
                bodylineForPoseId: bodylineResolver
            )
            try? SkillAnimationStorage.shared.save(animation)
            showAlert(
                title: "Export complete",
                message: "Wrote \(urls.count) JSON files to CheerCOMAnimations/training_data/raw/"
            )
        } catch {
            showAlert(title: "Export failed", message: "\(error)")
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showSaveConfirmation() {
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)

        saveButtonResetWorkItem?.cancel()
        var config = saveSessionButton.configuration
        config?.title = "Saved"
        config?.baseForegroundColor = .systemGreen
        saveSessionButton.configuration = config

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            var resetConfig = self.saveSessionButton.configuration
            resetConfig?.title = "Save Session"
            resetConfig?.baseForegroundColor = .systemGreen
            self.saveSessionButton.configuration = resetConfig
        }
        saveButtonResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: workItem)
    }

    private func applyJointAngles(_ jointAngles: [String: SCNVector3], animated: Bool = true) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = animated ? 0.2 : 0.0
        for (jointName, angles) in jointAngles {
            if let bone = sceneManager.findBone(named: jointName) {
                bone.eulerAngles = JointLimits.clampAngles(for: jointName, angles: angles)
            }
        }
        SCNTransaction.commit()
    }

    private func refreshSkillPickerTitle() {
        let manifest = VocabularyManager.shared.load()
        let displayName = manifest.atoms.first(where: { $0.id == selectedAtomId })?.displayName ?? "(none)"
        skillPickerButton.setTitle("Skill: \(displayName)", for: .normal)
    }

    private func applyMirrorToggleAppearance() {
        var config = mirrorToggleButton.configuration
        config?.title = mirrorEnabled ? "Mirror: ON" : "Mirror: OFF"
        config?.baseForegroundColor = mirrorEnabled ? .systemGreen : .secondaryLabel
        mirrorToggleButton.configuration = config
    }

    private static func array(from vector: SCNVector3) -> [Float] {
        [vector.x, vector.y, vector.z]
    }

    private static func vector3(from values: [Float]) -> SCNVector3 {
        guard values.count == 3 else { return SCNVector3Zero }
        return SCNVector3(values[0], values[1], values[2])
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

// MARK: - SkillTimelineViewDelegate

extension SkillAnimatorViewController: SkillTimelineViewDelegate {
    func timelineView(_ view: SkillTimelineView, didTapKeyframeAt index: Int) {
        stopPlayback()
        let frame = view.keyframes[index]
        view.currentFrame = frame
        previewCurrentFrame(animated: true)
        scheduleWorkspaceSave()
    }

    func timelineView(_ view: SkillTimelineView, didMoveKeyframeAt index: Int, toFrame frame: Int) {
        let oldFrame = view.keyframes[index]
        guard oldFrame != frame else { return }

        // Move the pose data along with the marker.
        if let pose = keyframePoses.removeValue(forKey: oldFrame) {
            keyframePoses[frame] = pose
        }
        var kfs = view.keyframes
        kfs[index] = frame
        kfs.sort()
        view.keyframes = kfs
        view.currentFrame = frame
        previewCurrentFrame(animated: false)
        scheduleWorkspaceSave()
    }

    func timelineView(_ view: SkillTimelineView, didScrubToFrame frame: Int) {
        stopPlayback()
        view.currentFrame = frame
        previewCurrentFrame(animated: false)
        scheduleWorkspaceSave()
    }
}

// MARK: - TransformControlPanelDelegate

extension SkillAnimatorViewController: TransformControlPanelDelegate {
    func didChangeTransformMode(_ mode: TransformMode) {
        currentTransformMode = mode
        transformStep = baseTransformStep(for: mode) * transformStepMultiplier
        transformControlPanel.updateModeDisplay(mode: mode, step: transformStep)
        scheduleWorkspaceSave()
    }

    func didTapPoseLibraryFromTransformPanel() {
        openPoseLibraryModal()
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

    func didTapTransform(direction: TransformDirection) {
        switch direction {
        case .up: transformAxisStep(positive: true, vertical: true)
        case .down: transformAxisStep(positive: false, vertical: true)
        case .left: transformAxisStep(positive: false, vertical: false)
        case .right: transformAxisStep(positive: true, vertical: false)
        case .forward: transformDepthStep(positive: true)
        case .backward: transformDepthStep(positive: false)
        }
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

    func didTapResetTransform() {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.4
        sceneManager.characterNode.position = SCNVector3(0, 0, 0)
        sceneManager.characterNode.eulerAngles = SCNVector3(0, 0, 0)
        sceneManager.characterNode.scale = SCNVector3(1, 1, 1)
        SCNTransaction.commit()
        scheduleWorkspaceSave()
    }

    func didChangeTransformStepMultiplier(_ multiplier: Float) {
        transformStepMultiplier = multiplier
        transformStep = baseTransformStep(for: currentTransformMode) * multiplier
        transformControlPanel.updateModeDisplay(mode: currentTransformMode, step: transformStep)
        scheduleWorkspaceSave()
    }

    private func baseTransformStep(for mode: TransformMode) -> Float {
        switch mode {
        case .position: return 0.05
        case .rotation: return 5.0
        case .scale: return 0.1
        }
    }

    private func transformAxisStep(positive: Bool, vertical: Bool) {
        let sign: Float = positive ? 1 : -1
        let node = sceneManager.characterNode!
        switch currentTransformMode {
        case .position:
            if vertical {
                node.position.y += sign * transformStep
            } else {
                node.position.x += sign * transformStep
            }
        case .rotation:
            let rad = sign * transformStep * .pi / 180
            if vertical {
                node.eulerAngles.x += rad
            } else {
                node.eulerAngles.y += rad
            }
        case .scale:
            if vertical {
                let s = max(0.1, node.scale.y + sign * transformStep)
                node.scale = SCNVector3(s, s, s)
            }
        }
        scheduleWorkspaceSave()
    }

    private func transformDepthStep(positive: Bool) {
        let sign: Float = positive ? 1 : -1
        let node = sceneManager.characterNode!
        switch currentTransformMode {
        case .position:
            node.position.z += sign * transformStep
        case .rotation:
            node.eulerAngles.z += sign * transformStep * .pi / 180
        case .scale:
            break
        }
        scheduleWorkspaceSave()
    }
}

// MARK: - JointControlPanelDelegate

extension SkillAnimatorViewController: JointControlPanelDelegate {
    func didTapJointSelection(sourceView: UIView) {
        let picker = JointPickerViewController()
        picker.joints = sceneManager.controllableJoints
        picker.selectedJointName = selectedJoint?.name
        picker.onSelectJoint = { [weak self] jointName in
            self?.selectJoint(named: jointName)
            self?.scheduleWorkspaceSave()
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

    private func selectJoint(named name: String) {
        guard let joint = sceneManager.findBone(named: name) else {
            print("Failed to find animator joint: \(name)")
            return
        }

        selectedJoint = joint
        jointControlPanel.updateJointSelection(name: formatJointName(name), angles: joint.eulerAngles)
    }

    func didTapJointPresets(sourceView: UIView) {
        guard let joint = selectedJoint, let jointName = joint.name else {
            showAlert(title: "Joint Presets", message: "Select a joint first.")
            return
        }

        let presets = JointPresetStorageManager.shared.loadPresets(for: jointName)
        let alert = UIAlertController(
            title: formatJointName(jointName),
            message: presets.isEmpty ? "No saved presets for this joint yet." : "Load or delete a saved joint rotation.",
            preferredStyle: .actionSheet
        )

        for preset in presets {
            alert.addAction(UIAlertAction(title: preset.name, style: .default) { [weak self] _ in
                self?.applyJointPreset(preset)
            })
        }

        if !presets.isEmpty {
            alert.addAction(UIAlertAction(title: "Delete Preset…", style: .destructive) { [weak self] _ in
                self?.presentJointPresetDeletion(for: jointName, sourceView: sourceView)
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }
        present(alert, animated: true)
    }

    func didTapSaveJointPreset() {
        guard let joint = selectedJoint, let jointName = joint.name else {
            showAlert(title: "Save Joint Preset", message: "Select a joint first.")
            return
        }

        let alert = UIAlertController(
            title: "Save Joint Preset",
            message: "Save the current \(formatJointName(jointName)) rotation for reuse.",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.placeholder = "Preset name"
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let name, !name.isEmpty else { return }
            JointPresetStorageManager.shared.savePreset(name: name, jointName: jointName, angles: joint.eulerAngles)
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.success)
        })
        present(alert, animated: true)
    }

    func didChangeJointAngle(axis: JointAxis, value: Float) {
        guard let joint = selectedJoint else { return }
        let angle = value * .pi / 180

        var newAngles = joint.eulerAngles
        switch axis {
        case .x: newAngles.x = angle
        case .y: newAngles.y = angle
        case .z: newAngles.z = angle
        }

        if let jointName = joint.name {
            joint.eulerAngles = JointLimits.clampAngles(for: jointName, angles: newAngles)
            applyMirrorIfNeeded(sourceBoneName: jointName, sourceAngles: joint.eulerAngles)
        } else {
            joint.eulerAngles = newAngles
        }
        jointControlPanel.updateAngleDisplays(angles: joint.eulerAngles)
        captureKeyframe(at: timelineView.currentFrame)
    }

    func didIncrementAngle(axis: JointAxis) {
        rotateSelectedJoint(axis: axis, direction: .positive)
    }

    func didDecrementAngle(axis: JointAxis) {
        rotateSelectedJoint(axis: axis, direction: .negative)
    }

    func didBeginIncrementingAngle(axis: JointAxis) {}
    func didEndIncrementingAngle(axis: JointAxis) {}
    func didBeginDecrementingAngle(axis: JointAxis) {}
    func didEndDecrementingAngle(axis: JointAxis) {}

    private func rotateSelectedJoint(axis: JointAxis, direction: RotationDirection) {
        guard let joint = selectedJoint else { return }
        let delta: Float = (direction == .positive ? 1 : -1) * .pi / 180

        var newAngles = joint.eulerAngles
        switch axis {
        case .x: newAngles.x += delta
        case .y: newAngles.y += delta
        case .z: newAngles.z += delta
        }

        if let jointName = joint.name {
            joint.eulerAngles = JointLimits.clampAngles(for: jointName, angles: newAngles)
            applyMirrorIfNeeded(sourceBoneName: jointName, sourceAngles: joint.eulerAngles)
        } else {
            joint.eulerAngles = newAngles
        }
        jointControlPanel.updateAngleDisplays(angles: joint.eulerAngles)
        captureKeyframe(at: timelineView.currentFrame)
    }

    func didResetSelectedJoint() {
        guard let joint = selectedJoint else { return }
        joint.eulerAngles = SCNVector3Zero
        if let jointName = joint.name {
            applyMirrorIfNeeded(sourceBoneName: jointName, sourceAngles: joint.eulerAngles)
        }
        jointControlPanel.updateAngleDisplays(angles: joint.eulerAngles)
        captureKeyframe(at: timelineView.currentFrame)
    }

    private func applyMirrorIfNeeded(sourceBoneName: String, sourceAngles: SCNVector3) {
        guard mirrorEnabled,
              let partnerName = JointMirror.partner(of: sourceBoneName),
              let partnerBone = sceneManager.findBone(named: partnerName) else { return }
        let mirrored = JointMirror.mirroredAngles(sourceAngles)
        partnerBone.eulerAngles = JointLimits.clampAngles(for: partnerName, angles: mirrored)
    }

    @objc private func toggleMirror() {
        mirrorEnabled.toggle()
        applyMirrorToggleAppearance()
        scheduleWorkspaceSave()
    }

    // MARK: - Playback

    @objc private func playbackTogglePlay() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }

    @objc private func playbackRestart() {
        stopPlayback()
        timelineView.currentFrame = 0
        previewCurrentFrame(animated: false)
        updatePlaybackFrameLabel()
    }

    @objc private func playbackJumpToEnd() {
        stopPlayback()
        timelineView.currentFrame = totalFrames - 1
        previewCurrentFrame(animated: false)
        updatePlaybackFrameLabel()
    }

    private func startPlayback() {
        guard !isPlaying else { return }
        isPlaying = true
        // If at the end, restart from frame 0
        if timelineView.currentFrame >= totalFrames - 1 {
            timelineView.currentFrame = 0
        }
        lastPlaybackTimestamp = 0
        let link = CADisplayLink(target: self, selector: #selector(playbackTick(_:)))
        link.add(to: .main, forMode: .common)
        playbackLink = link
        var config = playPauseButton.configuration
        config?.image = UIImage(systemName: "pause.fill")
        playPauseButton.configuration = config
    }

    private func stopPlayback() {
        guard isPlaying else { return }
        isPlaying = false
        playbackLink?.invalidate()
        playbackLink = nil
        var config = playPauseButton.configuration
        config?.image = UIImage(systemName: "play.fill")
        playPauseButton.configuration = config
    }

    @objc private func playbackTick(_ link: CADisplayLink) {
        if lastPlaybackTimestamp == 0 {
            lastPlaybackTimestamp = link.timestamp
            return
        }
        let elapsed = link.timestamp - lastPlaybackTimestamp
        let framesAdvanced = Int((elapsed * playbackFps).rounded(.down))
        guard framesAdvanced >= 1 else { return }
        lastPlaybackTimestamp = link.timestamp

        var nextFrame = timelineView.currentFrame + framesAdvanced
        if nextFrame >= totalFrames - 1 {
            nextFrame = totalFrames - 1
            timelineView.currentFrame = nextFrame
            previewCurrentFrame(animated: false)
            updatePlaybackFrameLabel()
            stopPlayback()
            return
        }
        timelineView.currentFrame = nextFrame
        previewCurrentFrame(animated: false)
        updatePlaybackFrameLabel()
    }

    private func updatePlaybackFrameLabel() {
        playbackFrameLabel?.text = "\(timelineView.currentFrame) / \(totalFrames - 1)"
    }

    func didTapPoseLibrary() {
        togglePoseLibrary()
    }

    func didTapResetPose() {
        let tPoseDefinition = PosePresets.shared.getPose(.tPose)
        applyJointAngles(tPoseDefinition.jointAngles)
        if let selectedJoint {
            jointControlPanel.updateAngleDisplays(angles: selectedJoint.eulerAngles)
        }
        captureKeyframe(at: timelineView.currentFrame)
    }

    func didTapFitView() {
        sceneManager.frameCharacter()
    }

    func didTapToggleVisualizations() {
        sceneManager.sceneView.showsStatistics.toggle()
    }

    private func applyJointPreset(_ preset: SavedJointPreset) {
        guard let joint = selectedJoint, joint.name == preset.jointName else { return }
        joint.eulerAngles = Self.vector3(from: preset.jointAngles)
        if let jointName = joint.name {
            joint.eulerAngles = JointLimits.clampAngles(for: jointName, angles: joint.eulerAngles)
            applyMirrorIfNeeded(sourceBoneName: jointName, sourceAngles: joint.eulerAngles)
        }
        jointControlPanel.updateAngleDisplays(angles: joint.eulerAngles)
        captureKeyframe(at: timelineView.currentFrame)
    }

    private func presentJointPresetDeletion(for jointName: String, sourceView: UIView) {
        let presets = JointPresetStorageManager.shared.loadPresets(for: jointName)
        let alert = UIAlertController(
            title: "Delete Joint Preset",
            message: "Choose a preset to remove.",
            preferredStyle: .actionSheet
        )
        for preset in presets {
            alert.addAction(UIAlertAction(title: preset.name, style: .destructive) { _ in
                JointPresetStorageManager.shared.deletePreset(id: preset.id)
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }
        present(alert, animated: true)
    }
}
