import Foundation
import UIKit
import ModelRigKit


protocol PoseLibraryPanelDelegate: AnyObject {
    func didSelectPose(_ pose: PoseType)
    func didSelectSavedPose(_ pose: SavedPose)
    func didDeleteSavedPose(_ pose: SavedPose)
    func didTapMirrorPose()
    func didTapSavePose()
    func didTapClosePoseLibrary()
    func didTapExportPoses()
    func didTapImportPoses()
}

class PoseLibraryPanel: UIView {

    weak var delegate: PoseLibraryPanelDelegate?

    private var categorySegmentedControl: UISegmentedControl!
    private var scrollView: UIScrollView!
    private var poseButtonContainer: UIView!
    private var currentCategory: PoseCategory = .fullBody
    private let panel = CheerGlassPanel(padding: .init(top: 20, leading: 20, bottom: 20, trailing: 20))
    private var lastLaidOutWidth: CGFloat = 0
    private let baseButtonSize: CGFloat = 92
    private let buttonSpacing: CGFloat = 12
    private let utilityGrid = UIStackView()
    private let mirrorButton = CheerButton(title: "Mirror", symbol: "arrow.left.and.right", style: .secondary, compact: true)
    private let saveButton = CheerButton(title: "Save", symbol: "square.and.arrow.down", style: .accent, compact: true)
    private let exportButton = CheerButton(title: "Export", symbol: "square.and.arrow.up", style: .neutral, compact: true)
    private let importButton = CheerButton(title: "Import", symbol: "tray.and.arrow.down", style: .positive, compact: true)
    private var poseContainerHeightConstraint: NSLayoutConstraint!

    init(width: CGFloat) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(panel)
        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: topAnchor),
            panel.leadingAnchor.constraint(equalTo: leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: trailingAnchor),
            panel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let contentView = panel.contentView

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Pose Library"
        titleLabel.textColor = CheerPalette.textPrimary
        titleLabel.font = cheerRoundedFont(.title3, weight: .bold)

        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Presets and saved routines"
        subtitleLabel.textColor = CheerPalette.textSecondary
        subtitleLabel.font = cheerRoundedFont(.subheadline, weight: .regular)

        let titleStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        titleStack.axis = .vertical
        titleStack.spacing = 2

        let closeButton = CheerButton(title: "Close", symbol: "xmark", style: .danger, compact: true)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let headerRow = UIStackView(arrangedSubviews: [titleStack, UIView(), closeButton])
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        headerRow.alignment = .center
        headerRow.spacing = 12
        contentView.addSubview(headerRow)

        utilityGrid.translatesAutoresizingMaskIntoConstraints = false
        utilityGrid.axis = .vertical
        utilityGrid.spacing = 10
        contentView.addSubview(utilityGrid)

        let utilityRowOne = UIStackView(arrangedSubviews: [mirrorButton, saveButton])
        utilityRowOne.axis = .horizontal
        utilityRowOne.spacing = 10
        utilityRowOne.distribution = .fillEqually

        let utilityRowTwo = UIStackView(arrangedSubviews: [exportButton, importButton])
        utilityRowTwo.axis = .horizontal
        utilityRowTwo.spacing = 10
        utilityRowTwo.distribution = .fillEqually

        utilityGrid.addArrangedSubview(utilityRowOne)
        utilityGrid.addArrangedSubview(utilityRowTwo)

        mirrorButton.addTarget(self, action: #selector(mirrorTapped), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        exportButton.addTarget(self, action: #selector(exportTapped), for: .touchUpInside)
        importButton.addTarget(self, action: #selector(importTapped), for: .touchUpInside)

        categorySegmentedControl = makeCheerSegmentedControl(items: ["Full Body", "Arms", "Legs", "Saved"])
        categorySegmentedControl.addTarget(self, action: #selector(categoryChanged), for: .valueChanged)
        contentView.addSubview(categorySegmentedControl)

        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        contentView.addSubview(scrollView)

        poseButtonContainer = UIView()
        poseButtonContainer.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(poseButtonContainer)

        poseContainerHeightConstraint = poseButtonContainer.heightAnchor.constraint(equalToConstant: 120)

        NSLayoutConstraint.activate([
            headerRow.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            headerRow.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            headerRow.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),

            utilityGrid.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 14),
            utilityGrid.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            utilityGrid.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),

            categorySegmentedControl.topAnchor.constraint(equalTo: utilityGrid.bottomAnchor, constant: 14),
            categorySegmentedControl.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            categorySegmentedControl.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: categorySegmentedControl.bottomAnchor, constant: 14),
            scrollView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),

            poseButtonContainer.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            poseButtonContainer.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            poseButtonContainer.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            poseButtonContainer.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            poseButtonContainer.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            poseContainerHeightConstraint
        ])

        loadPosesForCategory(.fullBody)
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

        let availableWidth = max(scrollView.bounds.width - 8, 220)
        let buttonSize = availableWidth < 420 ? 84 : baseButtonSize
        let buttonsPerRow = max(2, Int((availableWidth + buttonSpacing) / (buttonSize + buttonSpacing)))
        let totalButtonWidth = CGFloat(buttonsPerRow) * buttonSize
        let totalSpacing = CGFloat(max(0, buttonsPerRow - 1)) * buttonSpacing
        let startX = max(0, (availableWidth - totalButtonWidth - totalSpacing) / 2)

        var itemCount = 0

        if category == .saved {
            let savedPoses = PoseStorageManager.shared.loadPoses()
            itemCount = savedPoses.count

            if itemCount == 0 {
                let emptyLabel = UILabel(frame: CGRect(x: 0, y: 50, width: availableWidth, height: 30))
                emptyLabel.text = "No saved poses yet"
                emptyLabel.textColor = CheerPalette.textSecondary
                emptyLabel.textAlignment = .center
                emptyLabel.font = cheerRoundedFont(.headline, weight: .semibold)
                poseButtonContainer.addSubview(emptyLabel)
            }

            for (index, pose) in savedPoses.enumerated() {
                let row = index / buttonsPerRow
                let col = index % buttonsPerRow

                let x = startX + CGFloat(col) * (buttonSize + buttonSpacing)
                let y = 10 + CGFloat(row) * (buttonSize + buttonSpacing + 20)

                let poseButton = createSavedPoseButton(pose: pose, x: x, y: y, buttonSize: buttonSize)
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

                let poseButton = createPoseButton(pose: pose, x: x, y: y, buttonSize: buttonSize)
                poseButtonContainer.addSubview(poseButton)
            }
        }

        // Update scroll view content size
        let rows = (itemCount + buttonsPerRow - 1) / buttonsPerRow
        let contentHeight = 20 + CGFloat(rows) * (buttonSize + buttonSpacing + 20)
        poseContainerHeightConstraint.constant = max(contentHeight, 120)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if abs(bounds.width - lastLaidOutWidth) > 1 {
            lastLaidOutWidth = bounds.width
            loadPosesForCategory(currentCategory)
        }
    }

    private func createPoseButton(pose: PoseType, x: CGFloat, y: CGFloat, buttonSize: CGFloat) -> UIView {
        let container = UIView(
            frame: CGRect(x: x, y: y, width: buttonSize, height: buttonSize + 20))

        // Button
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: buttonSize, height: buttonSize))
        button.backgroundColor = CheerPalette.accentBlue.withAlphaComponent(0.22)
        button.layer.cornerCurve = .continuous
        button.layer.cornerRadius = 20
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        button.setTitle(pose.emoji, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: buttonSize < 90 ? 32 : 36)
        button.tag = pose.hashValue
        button.addTarget(self, action: #selector(poseTapped(_:)), for: .touchUpInside)
        container.addSubview(button)

        // Label
        let label = UILabel(frame: CGRect(x: 0, y: buttonSize + 2, width: buttonSize, height: 18))
        label.text = pose.displayName.components(separatedBy: " ").prefix(2).joined(separator: " ")
        label.textColor = CheerPalette.textPrimary
        label.font = cheerRoundedFont(.caption2, weight: .semibold)
        label.textAlignment = .center
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        container.addSubview(label)

        // Store pose reference
        button.accessibilityIdentifier = "\(pose)"

        return container
    }

    private func createSavedPoseButton(pose: SavedPose, x: CGFloat, y: CGFloat, buttonSize: CGFloat) -> UIView {
        let container = UIView(
            frame: CGRect(x: x, y: y, width: buttonSize, height: buttonSize + 20))

        // Button
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: buttonSize, height: buttonSize))
        button.backgroundColor = CheerPalette.accentMint.withAlphaComponent(0.24)
        button.layer.cornerCurve = .continuous
        button.layer.cornerRadius = 20
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        button.setTitle("💾", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: buttonSize < 90 ? 32 : 36)
        button.addTarget(self, action: #selector(savedPoseTapped(_:)), for: .touchUpInside)

        // Add long press to delete
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(savedPoseLongPressed(_:)))
        button.addGestureRecognizer(longPress)

        container.addSubview(button)

        // Label
        let label = UILabel(frame: CGRect(x: 0, y: buttonSize + 2, width: buttonSize, height: 18))
        label.text = pose.name
        label.textColor = CheerPalette.textPrimary
        label.font = cheerRoundedFont(.caption2, weight: .semibold)
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

    @objc private func exportTapped() {
        delegate?.didTapExportPoses()
    }

    @objc private func importTapped() {
        delegate?.didTapImportPoses()
    }

    @objc private func closeTapped() {
        delegate?.didTapClosePoseLibrary()
    }

    // Helper to convert string back to PoseType
    private func poseFromString(_ string: String) -> PoseType? {
        let allPoses: [PoseType] = [
            .tPose, .highV, .lowV, .touchdown, .bowAndArrow, .liberty, .scale, .arabesque,
            .bridge, .backbend, .standingSplit, .prepPosition, .squat, .pike, .layout, .sideLean, .lungePose,
            .armsHighV, .armsLowV, .armsT, .armsTouchdown, .armsBowAndArrow,
            .armsDaggers, .armsBrokenT, .armsHalfHighVHalfT,
            .legsStanding, .legsLibertyRight, .legsLibertyLeft, .legsScaleRight, .legsScaleLeft,
            .legsArabesque, .legsStraddle, .legsPike, .legsSquat,
        ]

        return allPoses.first { "\($0)" == string }
    }
}
