import Foundation
import UIKit

protocol PoseLibraryPanelDelegate: AnyObject {
    func didSelectPose(_ pose: PoseType)
    func didTapMirrorPose()
    func didTapSavePose()
    func didTapClosePoseLibrary()
}

class PoseLibraryPanel: UIVisualEffectView {

    weak var delegate: PoseLibraryPanelDelegate?

    private var categorySegmentedControl: UISegmentedControl!
    private var scrollView: UIScrollView!
    private var poseButtonContainer: UIView!
    private var currentCategory: PoseCategory = .fullBody

    private let panelHeight: CGFloat = 280
    private let buttonSize: CGFloat = 70
    private let buttonsPerRow: Int = 4
    private let buttonSpacing: CGFloat = 10

    init(width: CGFloat) {
        let blurEffect = UIBlurEffect(style: .dark)
        super.init(effect: blurEffect)
        setupUI(width: width)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI(width: CGFloat) {
        // Position above the Joint Control Panel (which is 180px tall)
        let jointPanelHeight: CGFloat = 180
        self.frame = CGRect(
            x: 0,
            y: UIScreen.main.bounds.height - panelHeight - jointPanelHeight,
            width: width,
            height: panelHeight
        )
        self.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]

        // Header with title and utility buttons
        let headerHeight: CGFloat = 40

        // Close button (X)
        let closeBtn = UIButton(frame: CGRect(x: 20, y: 10, width: 30, height: 30))
        closeBtn.setTitle("✕", for: .normal)
        closeBtn.setTitleColor(.white, for: .normal)
        closeBtn.titleLabel?.font = .boldSystemFont(ofSize: 24)
        closeBtn.backgroundColor = UIColor.systemRed.withAlphaComponent(0.8)
        closeBtn.layer.cornerRadius = 15
        closeBtn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        contentView.addSubview(closeBtn)

        let headerLabel = UILabel(frame: CGRect(x: 60, y: 10, width: 150, height: 30))
        headerLabel.text = "Pose Library"
        headerLabel.textColor = .white
        headerLabel.font = .boldSystemFont(ofSize: 18)
        contentView.addSubview(headerLabel)

        // Mirror button
        let mirrorBtn = createUtilityButton(
            title: "↔️ Mirror",
            x: width - 200,
            y: 10,
            width: 80,
            action: #selector(mirrorTapped)
        )
        contentView.addSubview(mirrorBtn)

        // Save button
        let saveBtn = createUtilityButton(
            title: "💾 Save",
            x: width - 110,
            y: 10,
            width: 90,
            action: #selector(saveTapped)
        )
        contentView.addSubview(saveBtn)

        // Category tabs
        let categoryY = headerHeight + 5
        let categories = ["Full Body", "Arms", "Legs"]
        categorySegmentedControl = UISegmentedControl(items: categories)
        categorySegmentedControl.frame = CGRect(
            x: 20,
            y: categoryY,
            width: width - 40,
            height: 32
        )
        categorySegmentedControl.selectedSegmentIndex = 0
        categorySegmentedControl.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        categorySegmentedControl.selectedSegmentTintColor = UIColor.systemTeal
        categorySegmentedControl.setTitleTextAttributes(
            [.foregroundColor: UIColor.white], for: .normal)
        categorySegmentedControl.setTitleTextAttributes(
            [.foregroundColor: UIColor.white], for: .selected)
        categorySegmentedControl.addTarget(
            self, action: #selector(categoryChanged), for: .valueChanged)
        contentView.addSubview(categorySegmentedControl)

        // Scroll view for pose buttons
        let scrollY = categoryY + 40
        scrollView = UIScrollView(
            frame: CGRect(
                x: 0,
                y: scrollY,
                width: width,
                height: panelHeight - scrollY
            ))
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = false
        contentView.addSubview(scrollView)

        // Container for pose buttons
        poseButtonContainer = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 400))
        scrollView.addSubview(poseButtonContainer)

        // Load initial category
        loadPosesForCategory(.fullBody)
    }

    private func createUtilityButton(
        title: String, x: CGFloat, y: CGFloat, width: CGFloat, action: Selector
    ) -> UIButton {
        let button = UIButton(frame: CGRect(x: x, y: y, width: width, height: 30))
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14)
        button.backgroundColor = UIColor.systemIndigo.withAlphaComponent(0.8)
        button.layer.cornerRadius = 6
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func categoryChanged() {
        let index = categorySegmentedControl.selectedSegmentIndex
        switch index {
        case 0: loadPosesForCategory(.fullBody)
        case 1: loadPosesForCategory(.armsOnly)
        case 2: loadPosesForCategory(.legsOnly)
        default: break
        }
    }

    private func loadPosesForCategory(_ category: PoseCategory) {
        currentCategory = category

        // Clear existing buttons
        for subview in poseButtonContainer.subviews {
            subview.removeFromSuperview()
        }

        // Get poses for category
        let poses = PosePresets.shared.getPoses(for: category)

        // Calculate layout
        let totalWidth = scrollView.frame.width
        let padding: CGFloat = 20
        let availableWidth = totalWidth - (padding * 2)
        let totalButtonWidth = CGFloat(buttonsPerRow) * buttonSize
        let totalSpacing = CGFloat(buttonsPerRow - 1) * buttonSpacing
        let startX = (totalWidth - totalButtonWidth - totalSpacing) / 2

        // Create buttons
        for (index, pose) in poses.enumerated() {
            let row = index / buttonsPerRow
            let col = index % buttonsPerRow

            let x = startX + CGFloat(col) * (buttonSize + buttonSpacing)
            let y = 10 + CGFloat(row) * (buttonSize + buttonSpacing + 20)

            let poseButton = createPoseButton(pose: pose, x: x, y: y)
            poseButtonContainer.addSubview(poseButton)
        }

        // Update scroll view content size
        let rows = (poses.count + buttonsPerRow - 1) / buttonsPerRow
        let contentHeight = 20 + CGFloat(rows) * (buttonSize + buttonSpacing + 20)
        poseButtonContainer.frame.size.height = contentHeight
        scrollView.contentSize = CGSize(width: scrollView.frame.width, height: contentHeight)
    }

    private func createPoseButton(pose: PoseType, x: CGFloat, y: CGFloat) -> UIView {
        let container = UIView(
            frame: CGRect(x: x, y: y, width: buttonSize, height: buttonSize + 20))

        // Button
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: buttonSize, height: buttonSize))
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
        button.layer.cornerRadius = 12
        button.setTitle(pose.emoji, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 32)
        button.tag = pose.hashValue
        button.addTarget(self, action: #selector(poseTapped(_:)), for: .touchUpInside)
        container.addSubview(button)

        // Label
        let label = UILabel(frame: CGRect(x: 0, y: buttonSize + 2, width: buttonSize, height: 18))
        label.text = pose.displayName.components(separatedBy: " ").prefix(2).joined(separator: " ")
        label.textColor = .white
        label.font = .systemFont(ofSize: 10)
        label.textAlignment = .center
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        container.addSubview(label)

        // Store pose reference
        button.accessibilityIdentifier = "\(pose)"

        return container
    }

    @objc private func poseTapped(_ sender: UIButton) {
        // Find pose from accessibility identifier
        guard let poseString = sender.accessibilityIdentifier,
            let pose = poseFromString(poseString)
        else {
            return
        }

        // Animate button
        UIView.animate(
            withDuration: 0.1,
            animations: {
                sender.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }
        ) { _ in
            UIView.animate(withDuration: 0.1) {
                sender.transform = .identity
            }
        }

        delegate?.didSelectPose(pose)
        print("🎭 Selected pose: \(pose.displayName)")
    }

    @objc private func mirrorTapped() {
        delegate?.didTapMirrorPose()
    }

    @objc private func saveTapped() {
        delegate?.didTapSavePose()
    }

    @objc private func closeTapped() {
        delegate?.didTapClosePoseLibrary()
    }

    // Helper to convert string back to PoseType
    private func poseFromString(_ string: String) -> PoseType? {
        let allPoses: [PoseType] = [
            .tPose, .highV, .lowV, .touchdown, .bowAndArrow, .liberty, .scale, .arabesque,
            .bridge, .backbend, .standingSplit, .prepPosition,
            .armsHighV, .armsLowV, .armsT, .armsTouchdown, .armsBowAndArrow,
            .armsDaggers, .armsBrokenT, .armsHalfHighVHalfT,
            .legsStanding, .legsLibertyRight, .legsLibertyLeft, .legsScaleRight, .legsScaleLeft,
            .legsArabesque, .legsStraddle, .legsPike, .legsSquat,
        ]

        return allPoses.first { "\($0)" == string }
    }
}
