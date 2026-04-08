import UIKit

/// Root container for the CheerCOM authoring UI.
///
/// Skill Animator is the primary authoring surface. The legacy Pose Mode
/// (saved pose library editor) is reached via a small button inside the
/// Skill Animator's top bar — it's kept around for maintaining the saved
/// pose library, but it's out of the way.
final class ModeContainerViewController: UIViewController {

    private var animatorVC: SkillAnimatorViewController!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        animatorVC = SkillAnimatorViewController()
        addChild(animatorVC)
        animatorVC.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animatorVC.view)
        NSLayoutConstraint.activate([
            animatorVC.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            animatorVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            animatorVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            animatorVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        animatorVC.didMove(toParent: self)
    }
}
