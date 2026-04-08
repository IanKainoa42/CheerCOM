import UIKit
import SceneKit
import ModelRigKit

/// Root view controller for Skill Animator mode.
/// Hosts a 3D viewport (rigged character), top controls (skill picker, vocabulary,
/// export button, camera label), and a timeline keyframe bar.
final class SkillAnimatorViewController: UIViewController {

    // Scene
    private var sceneManager: CheerCOMSceneManager!
    private var viewportContainer: UIView!
    private var controlsPanel: UIView!
    private var controlsScrollView: UIScrollView!
    private var controlsStackView: UIStackView!
    private var savedPoseStackView: UIStackView!
    private var selectedKeyframeLabel: UILabel!
    private var selectedPoseLabel: UILabel!

    // Top controls
    private var skillPickerButton: UIButton!
    private var cameraAngleLabel: UILabel!
    private var vocabButton: UIButton!
    private var exportButton: UIButton!

    // Timeline
    private var timelineView: SkillTimelineView!
    private var wideLayoutConstraints: [NSLayoutConstraint] = []
    private var compactLayoutConstraints: [NSLayoutConstraint] = []
    private var usesWideLayout = false

    // State
    private var savedPoses: [SavedPose] = []
    private var keyframePoseIds: [Int: UUID] = [:]
    private var selectedKeyframeIndex = 0
    private var selectedAtomId = "back_handspring"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupLayout()
        setupScene()
        setupControls()
        refreshSavedPoses()
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
        timelineView.numFrames = 25
        timelineView.keyframes = [0, 12, 24]
        timelineView.delegate = self
        view.addSubview(timelineView)

        let sharedConstraints = [
            viewportContainer.topAnchor.constraint(equalTo: view.topAnchor, constant: 60),

            timelineView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            timelineView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            timelineView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            timelineView.heightAnchor.constraint(equalToConstant: 120),

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
            viewportContainer.bottomAnchor.constraint(equalTo: timelineView.topAnchor, constant: -16),

            controlsPanel.topAnchor.constraint(equalTo: viewportContainer.topAnchor),
            controlsPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            controlsPanel.bottomAnchor.constraint(equalTo: viewportContainer.bottomAnchor),
            controlsPanel.widthAnchor.constraint(equalToConstant: 300)
        ]

        compactLayoutConstraints = [
            viewportContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            viewportContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            viewportContainer.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.48),

            controlsPanel.topAnchor.constraint(equalTo: viewportContainer.bottomAnchor, constant: 12),
            controlsPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            controlsPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            controlsPanel.bottomAnchor.constraint(equalTo: timelineView.topAnchor, constant: -12)
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
        vocabButton.setTitle("Vocabulary", for: .normal)
        vocabButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        vocabButton.addTarget(self, action: #selector(openVocabulary), for: .touchUpInside)
        view.addSubview(vocabButton)

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

            cameraAngleLabel.centerYAnchor.constraint(equalTo: skillPickerButton.centerYAnchor),
            cameraAngleLabel.leadingAnchor.constraint(equalTo: skillPickerButton.trailingAnchor, constant: 24),

            exportButton.centerYAnchor.constraint(equalTo: skillPickerButton.centerYAnchor),
            exportButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            vocabButton.centerYAnchor.constraint(equalTo: skillPickerButton.centerYAnchor),
            vocabButton.trailingAnchor.constraint(equalTo: exportButton.leadingAnchor, constant: -16)
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

        selectedPoseLabel = UILabel()
        selectedPoseLabel.textColor = .secondaryLabel
        selectedPoseLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        selectedPoseLabel.numberOfLines = 0

        let reloadButton = UIButton(type: .system)
        reloadButton.setTitle("Reload Saved Poses", for: .normal)
        reloadButton.addTarget(self, action: #selector(reloadSavedPosesTapped), for: .touchUpInside)

        savedPoseStackView = UIStackView()
        savedPoseStackView.axis = .vertical
        savedPoseStackView.spacing = 8

        controlsStackView.addArrangedSubview(titleLabel)
        controlsStackView.addArrangedSubview(selectedKeyframeLabel)
        controlsStackView.addArrangedSubview(selectedPoseLabel)
        controlsStackView.addArrangedSubview(reloadButton)
        controlsStackView.addArrangedSubview(savedPoseStackView)
    }

    private func updateAuthoringPanelLayout() {
        let shouldUseWideLayout = view.bounds.width >= 820
        guard shouldUseWideLayout != usesWideLayout else { return }

        NSLayoutConstraint.deactivate(shouldUseWideLayout ? compactLayoutConstraints : wideLayoutConstraints)
        NSLayoutConstraint.activate(shouldUseWideLayout ? wideLayoutConstraints : compactLayoutConstraints)
        usesWideLayout = shouldUseWideLayout
    }

    private func refreshSavedPoses() {
        savedPoses = PoseStorageManager.shared.loadPoses()
        seedKeyframeAssignmentsIfNeeded()
        rebuildSavedPoseButtons()
        previewSelectedKeyframePose()
        updateSelectedKeyframeLabels()
    }

    private func seedKeyframeAssignmentsIfNeeded() {
        guard keyframePoseIds.isEmpty else { return }
        for (index, pose) in savedPoses.prefix(timelineView.keyframes.count).enumerated() {
            keyframePoseIds[index] = pose.id
        }
    }

    private func rebuildSavedPoseButtons() {
        savedPoseStackView.arrangedSubviews.forEach { view in
            savedPoseStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        guard !savedPoses.isEmpty else {
            let emptyLabel = UILabel()
            emptyLabel.text = "No saved poses yet. Save poses in Pose mode, then come back here."
            emptyLabel.textColor = .secondaryLabel
            emptyLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
            emptyLabel.numberOfLines = 0
            savedPoseStackView.addArrangedSubview(emptyLabel)
            return
        }

        let hintLabel = UILabel()
        hintLabel.text = "Tap a saved pose to assign it to the selected keyframe and preview it on the model."
        hintLabel.textColor = .secondaryLabel
        hintLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        hintLabel.numberOfLines = 0
        savedPoseStackView.addArrangedSubview(hintLabel)

        for pose in savedPoses {
            let button = UIButton(type: .system)
            var configuration = UIButton.Configuration.filled()
            configuration.title = pose.name
            configuration.subtitle = "Use for keyframe \(selectedKeyframeIndex + 1)"
            configuration.baseBackgroundColor = .systemBlue
            configuration.baseForegroundColor = .white
            configuration.cornerStyle = .medium
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
            button.configuration = configuration
            button.contentHorizontalAlignment = .leading
            button.addAction(UIAction { [weak self] _ in
                self?.assignPoseToSelectedKeyframe(pose)
            }, for: .touchUpInside)
            savedPoseStackView.addArrangedSubview(button)
        }
    }

    private func assignPoseToSelectedKeyframe(_ pose: SavedPose) {
        keyframePoseIds[selectedKeyframeIndex] = pose.id
        applySavedPose(pose)
        updateSelectedKeyframeLabels()
        rebuildSavedPoseButtons()
    }

    private func previewSelectedKeyframePose() {
        guard let poseId = keyframePoseIds[selectedKeyframeIndex],
              let pose = savedPoses.first(where: { $0.id == poseId }) else { return }
        applySavedPose(pose, animated: false)
    }

    private func updateSelectedKeyframeLabels() {
        let frame = timelineView.keyframes.indices.contains(selectedKeyframeIndex)
            ? timelineView.keyframes[selectedKeyframeIndex]
            : timelineView.currentFrame
        selectedKeyframeLabel?.text = "Selected keyframe \(selectedKeyframeIndex + 1) at frame \(frame)"

        if let poseId = keyframePoseIds[selectedKeyframeIndex],
           let pose = savedPoses.first(where: { $0.id == poseId }) {
            selectedPoseLabel?.text = "Assigned pose: \(pose.name)"
        } else {
            selectedPoseLabel?.text = "Assigned pose: none"
        }
    }

    private func applySavedPose(_ pose: SavedPose, animated: Bool = true) {
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

        SCNTransaction.begin()
        SCNTransaction.animationDuration = animated ? 0.25 : 0.0
        for (jointName, angles) in jointAngles {
            if let bone = sceneManager.findBone(named: jointName) {
                bone.eulerAngles = JointLimits.clampAngles(for: jointName, angles: angles)
            }
        }
        SCNTransaction.commit()
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
                self?.skillPickerButton.setTitle("Skill: \(atom.displayName)", for: .normal)
                self?.selectedAtomId = atom.id
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

    @objc private func exportTapped() {
        runExport()
    }

    @objc private func reloadSavedPosesTapped() {
        refreshSavedPoses()
    }

    private func runExport() {
        let poses = PoseStorageManager.shared.loadPoses()
        guard poses.count >= 2 else {
            showAlert(title: "Export", message: "Save at least 2 poses in Pose Mode before exporting.")
            return
        }

        let assignedKeyframes = timelineView.keyframes.enumerated().compactMap { index, frame -> SkillKeyframe? in
            guard let poseId = keyframePoseIds[index] else { return nil }
            return SkillKeyframe(
                poseId: poseId,
                frameIndex: frame,
                bodylineId: PoseStorageManager.shared.bodyline(for: poseId)
            )
        }
        guard assignedKeyframes.count >= 2 else {
            showAlert(title: "Export", message: "Assign at least 2 timeline keyframes to saved poses before exporting.")
            return
        }

        let animation = SkillAnimation(
            name: "manual_test",
            atomId: selectedAtomId,
            category: "tumbling",
            numFrames: 25,
            keyframes: assignedKeyframes
        )

        let poseResolver: (UUID) -> [String: SCNVector3]? = { poseId in
            guard let saved = poses.first(where: { $0.id == poseId }) else { return nil }
            var result: [String: SCNVector3] = [:]
            for (boneName, components) in saved.jointAngles where components.count == 3 {
                #if os(macOS)
                result[boneName] = SCNVector3(
                    CGFloat(components[0]), CGFloat(components[1]), CGFloat(components[2])
                )
                #else
                result[boneName] = SCNVector3(components[0], components[1], components[2])
                #endif
            }
            return result
        }

        let bodylineResolver: (UUID) -> String? = { poseId in
            PoseStorageManager.shared.bodyline(for: poseId)
        }

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
}

// MARK: - SkillTimelineViewDelegate

extension SkillAnimatorViewController: SkillTimelineViewDelegate {
    func timelineView(_ view: SkillTimelineView, didTapKeyframeAt index: Int) {
        selectedKeyframeIndex = index
        view.currentFrame = view.keyframes[index]
        previewSelectedKeyframePose()
        updateSelectedKeyframeLabels()
        rebuildSavedPoseButtons()
    }

    func timelineView(_ view: SkillTimelineView, didMoveKeyframeAt index: Int, toFrame frame: Int) {
        var kfs = view.keyframes
        kfs[index] = frame
        view.keyframes = kfs
        selectedKeyframeIndex = index
        view.currentFrame = frame
        updateSelectedKeyframeLabels()
        rebuildSavedPoseButtons()
    }

    func timelineView(_ view: SkillTimelineView, didScrubToFrame frame: Int) {
        view.currentFrame = frame
    }
}
