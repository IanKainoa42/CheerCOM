import Foundation
import UIKit

protocol PoseLibraryPanelDelegate: AnyObject {
    func didSelectPose(_ pose: PoseType)
    func didSelectSavedPose(_ pose: SavedPose)
    func didDeleteSavedPose(_ pose: SavedPose)
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
        let categories = ["Full Body", "Arms", "Legs", "Saved"]
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
        case 3: loadPosesForCategory(.saved)
        default: break
        }
    }

    // Public method to refresh the list (e.g., after saving)
    func refreshPoses() {
        loadPosesForCategory(currentCategory)
    }

    private func loadPosesForCategory(_ category: PoseCategory) {
        currentCategory = category

        // Clear existing buttons
        for subview in poseButtonContainer.subviews {
            subview.removeFromSuperview()
        }

        // Calculate layout
        let totalWidth = scrollView.frame.width
        let totalButtonWidth = CGFloat(buttonsPerRow) * buttonSize
        let totalSpacing = CGFloat(buttonsPerRow - 1) * buttonSpacing
        let startX = (totalWidth - totalButtonWidth - totalSpacing) / 2

        var itemCount = 0

        if category == .saved {
            let savedPoses = PoseStorageManager.shared.loadPoses()
            itemCount = savedPoses.count

            if itemCount == 0 {
                let emptyLabel = UILabel(frame: CGRect(x: 0, y: 50, width: totalWidth, height: 30))
                emptyLabel.text = "No saved poses yet"
                emptyLabel.textColor = UIColor.white.withAlphaComponent(0.6)
                emptyLabel.textAlignment = .center
                poseButtonContainer.addSubview(emptyLabel)
            }

            for (index, pose) in savedPoses.enumerated() {
                let row = index / buttonsPerRow
                let col = index % buttonsPerRow

                let x = startX + CGFloat(col) * (buttonSize + buttonSpacing)
                let y = 10 + CGFloat(row) * (buttonSize + buttonSpacing + 20)

                let poseButton = createSavedPoseButton(pose: pose, x: x, y: y)
                poseButtonContainer.addSubview(poseButton)
            }
        } else {
            let poses = PosePresets.shared.getPoses(for: category)
            itemCount = poses.count

            for (index, pose) in poses.enumerated() {
                let row = index / buttonsPerRow
                let col = index % buttonsPerRow

                let x = startX + CGFloat(col) * (buttonSize + buttonSpacing)
                let y = 10 + CGFloat(row) * (buttonSize + buttonSpacing + 20)

                let poseButton = createPoseButton(pose: pose, x: x, y: y)
                poseButtonContainer.addSubview(poseButton)
            }
        }

        // Update scroll view content size
        let rows = (itemCount + buttonsPerRow - 1) / buttonsPerRow
        let contentHeight = 20 + CGFloat(rows) * (buttonSize + buttonSpacing + 20)
        poseButtonContainer.frame.size.height = max(contentHeight, 100)
        scrollView.contentSize = CGSize(width: scrollView.frame.width, height: poseButtonContainer.frame.size.height)
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

    private func createSavedPoseButton(pose: SavedPose, x: CGFloat, y: CGFloat) -> UIView {
        let container = UIView(
            frame: CGRect(x: x, y: y, width: buttonSize, height: buttonSize + 20))

        // Button
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: buttonSize, height: buttonSize))
        button.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.8) // Green for saved
        button.layer.cornerRadius = 12
        button.setTitle("💾", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 32)
        button.addTarget(self, action: #selector(savedPoseTapped(_:)), for: .touchUpInside)

        // Add long press to delete
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(savedPoseLongPressed(_:)))
        button.addGestureRecognizer(longPress)

        container.addSubview(button)

        // Label
        let label = UILabel(frame: CGRect(x: 0, y: buttonSize + 2, width: buttonSize, height: 18))
        label.text = pose.name
        label.textColor = .white
        label.font = .systemFont(ofSize: 10)
        label.textAlignment = .center
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        container.addSubview(label)

        // Store pose reference
        button.accessibilityIdentifier = "saved:\(pose.id.uuidString)"

        return container
    }

    @objc private func poseTapped(_ sender: UIButton) {
        // Find pose from accessibility identifier
        guard let poseString = sender.accessibilityIdentifier,
            let pose = poseFromString(poseString)
        else {
            return
        }

        animateButton(sender)
        delegate?.didSelectPose(pose)
        print("🎭 Selected pose: \(pose.displayName)")
    }

    @objc private func savedPoseTapped(_ sender: UIButton) {
        guard let idString = sender.accessibilityIdentifier?.replacingOccurrences(of: "saved:", with: ""),
              let uuid = UUID(uuidString: idString) else { return }

        let savedPoses = PoseStorageManager.shared.loadPoses()
        if let pose = savedPoses.first(where: { $0.id == uuid }) {
            animateButton(sender)
            delegate?.didSelectSavedPose(pose)
            print("💾 Selected saved pose: \(pose.name)")
        }
    }

    @objc private func savedPoseLongPressed(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began, let sender = gesture.view as? UIButton {
            guard let idString = sender.accessibilityIdentifier?.replacingOccurrences(of: "saved:", with: ""),
                  let uuid = UUID(uuidString: idString) else { return }

            let savedPoses = PoseStorageManager.shared.loadPoses()
            if let pose = savedPoses.first(where: { $0.id == uuid }) {
                 // Feedback
                 let generator = UINotificationFeedbackGenerator()
                 generator.notificationOccurred(.warning)

                delegate?.didDeleteSavedPose(pose)
            }
        }
    }

    private func animateButton(_ button: UIButton) {
        UIView.animate(
            withDuration: 0.1,
            animations: {
                button.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }
        ) { _ in
            UIView.animate(withDuration: 0.1) {
                button.transform = .identity
            }
        }
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
