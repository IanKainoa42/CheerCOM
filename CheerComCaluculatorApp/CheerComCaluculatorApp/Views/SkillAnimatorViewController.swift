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

    // Top controls
    private var skillPickerButton: UIButton!
    private var cameraAngleLabel: UILabel!
    private var vocabButton: UIButton!
    private var exportButton: UIButton!

    // Timeline
    private var timelineView: SkillTimelineView!

    // State
    private var currentAnimation: SkillAnimation?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupLayout()
        setupScene()
        setupControls()
    }

    private func setupLayout() {
        viewportContainer = UIView()
        viewportContainer.translatesAutoresizingMaskIntoConstraints = false
        viewportContainer.backgroundColor = .black
        view.addSubview(viewportContainer)

        timelineView = SkillTimelineView()
        timelineView.translatesAutoresizingMaskIntoConstraints = false
        timelineView.numFrames = 25
        timelineView.keyframes = [0, 6, 14, 22]
        timelineView.delegate = self
        view.addSubview(timelineView)

        NSLayoutConstraint.activate([
            viewportContainer.topAnchor.constraint(equalTo: view.topAnchor, constant: 60),
            viewportContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            viewportContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            viewportContainer.bottomAnchor.constraint(equalTo: timelineView.topAnchor, constant: -16),

            timelineView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            timelineView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            timelineView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            timelineView.heightAnchor.constraint(equalToConstant: 140)
        ])
    }

    private func setupScene() {
        sceneManager = CheerCOMSceneManager(view: viewportContainer)
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
        exportButton.setTitle("Export (96 angles)", for: .normal)
        exportButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        exportButton.backgroundColor = .systemBlue
        exportButton.setTitleColor(.white, for: .normal)
        exportButton.layer.cornerRadius = 10
        exportButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
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
                self?.currentAnimation?.atomId = atom.id
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

    private func runExport() {
        let poses = PoseStorageManager.shared.loadPoses()
        guard poses.count >= 2 else {
            showAlert(title: "Export", message: "Save at least 2 poses in Pose Mode before exporting.")
            return
        }

        let keyframeFrames = [0, 12, 24]
        let keyframes: [SkillKeyframe] = poses.prefix(3).enumerated().map { index, pose in
            SkillKeyframe(
                poseId: pose.id,
                frameIndex: keyframeFrames[index],
                bodylineId: PoseStorageManager.shared.bodyline(for: pose.id)
            )
        }

        let atomId = currentAnimation?.atomId ?? "back_handspring"
        let animation = SkillAnimation(
            name: "manual_test",
            atomId: atomId,
            category: "tumbling",
            numFrames: 25,
            keyframes: keyframes
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
        print("Tapped keyframe \(index)")
    }

    func timelineView(_ view: SkillTimelineView, didMoveKeyframeAt index: Int, toFrame frame: Int) {
        var kfs = view.keyframes
        kfs[index] = frame
        view.keyframes = kfs
    }

    func timelineView(_ view: SkillTimelineView, didScrubToFrame frame: Int) {
        view.currentFrame = frame
    }
}
