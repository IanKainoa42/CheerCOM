import UIKit

/// Parent container VC that hosts Pose Mode (existing SceneViewController) and
/// Skill Animator Mode (new) with a top segmented control to switch between them.
final class ModeContainerViewController: UIViewController {

    enum Mode: Int {
        case pose = 0
        case skillAnimator = 1
    }

    private let modeSelector = UISegmentedControl(items: ["Pose", "Skill Animator"])
    private var poseVC: SceneViewController!
    private var animatorVC: SkillAnimatorViewController!
    private var currentChild: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupChildren()
        setupModeSelector()
        let initialMode: Mode = ProcessInfo.processInfo.arguments.contains("--skill-animator") ? .skillAnimator : .pose
        modeSelector.selectedSegmentIndex = initialMode.rawValue
        switchTo(initialMode)
    }

    private func setupChildren() {
        poseVC = SceneViewController()
        animatorVC = SkillAnimatorViewController()
    }

    private func setupModeSelector() {
        modeSelector.translatesAutoresizingMaskIntoConstraints = false
        modeSelector.selectedSegmentIndex = 0
        modeSelector.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        view.addSubview(modeSelector)

        NSLayoutConstraint.activate([
            modeSelector.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            modeSelector.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            modeSelector.widthAnchor.constraint(equalToConstant: 280)
        ])
    }

    @objc private func modeChanged() {
        let newMode: Mode = modeSelector.selectedSegmentIndex == 0 ? .pose : .skillAnimator
        switchTo(newMode)
    }

    private func switchTo(_ mode: Mode) {
        if let current = currentChild {
            current.willMove(toParent: nil)
            current.view.removeFromSuperview()
            current.removeFromParent()
        }

        let child: UIViewController = (mode == .pose) ? poseVC : animatorVC
        addChild(child)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(child.view)
        NSLayoutConstraint.activate([
            child.view.topAnchor.constraint(equalTo: modeSelector.bottomAnchor, constant: 8),
            child.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            child.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        child.didMove(toParent: self)
        currentChild = child
    }
}
