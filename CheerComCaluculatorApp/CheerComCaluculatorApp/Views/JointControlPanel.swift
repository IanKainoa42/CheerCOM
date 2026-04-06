import UIKit


protocol JointControlPanelDelegate: AnyObject {
    func didTapJointSelection(sourceView: UIView)
    func didSelectAxis(_ axis: JointAxis)
    func didChangeJointAngle(value: Float)
    func didIncrementAngle()
    func didDecrementAngle()
    func didBeginIncrementingAngle()
    func didEndIncrementingAngle()
    func didBeginDecrementingAngle()
    func didEndDecrementingAngle()
    func didResetSelectedJoint()

    func didTapPoseLibrary()
    func didTapResetPose()

    func didTapFitView()
    func didTapToggleVisualizations()
}

class JointControlPanel: UIView {

    weak var delegate: JointControlPanelDelegate?

    private let panel = CheerGlassPanel(padding: .init(top: 14, leading: 14, bottom: 14, trailing: 14))
    private let contentContainer = UIView()
    private let sectionLabel = UILabel()
    private var jointSelectionButton: CheerButton!
    private var axisSegmentedControl: UISegmentedControl!
    private var jointAngleSlider: UISlider!
    private var jointAngleLabel: PaddingLabel!

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

        panel.contentView.addSubview(contentContainer)
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: panel.contentView.layoutMarginsGuide.topAnchor),
            contentContainer.leadingAnchor.constraint(greaterThanOrEqualTo: panel.contentView.layoutMarginsGuide.leadingAnchor),
            contentContainer.trailingAnchor.constraint(lessThanOrEqualTo: panel.contentView.layoutMarginsGuide.trailingAnchor),
            contentContainer.centerXAnchor.constraint(equalTo: panel.contentView.centerXAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: panel.contentView.layoutMarginsGuide.bottomAnchor),
            contentContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 1100)
        ])

        let rootStack = UIStackView()
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        rootStack.axis = .vertical
        rootStack.spacing = 10
        contentContainer.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            rootStack.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            rootStack.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])

        sectionLabel.text = "JOINT OVERRIDES"
        sectionLabel.textColor = CheerPalette.accentMint
        sectionLabel.font = cheerMonospacedFont(size: 10, weight: .bold)
        rootStack.addArrangedSubview(sectionLabel)

        let hintLabel = UILabel()
        hintLabel.text = "Select a joint, choose an axis, then adjust the live angle."
        hintLabel.textColor = CheerPalette.textSecondary
        hintLabel.font = cheerMonospacedFont(size: 10, weight: .regular)
        hintLabel.numberOfLines = 2
        rootStack.addArrangedSubview(hintLabel)

        jointSelectionButton = CheerButton(title: "Choose Joint", symbol: "slider.horizontal.3", style: .accent)
        jointSelectionButton.addTarget(self, action: #selector(jointSelectionTapped), for: .touchUpInside)

        let resetJointButton = CheerButton(title: "Reset Joint", symbol: "arrow.counterclockwise", style: .secondary, compact: true)
        resetJointButton.addTarget(self, action: #selector(resetJointTapped), for: .touchUpInside)

        let headerRow = UIStackView(arrangedSubviews: [jointSelectionButton, resetJointButton])
        headerRow.axis = .horizontal
        headerRow.spacing = 10
        headerRow.alignment = .fill
        jointSelectionButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        resetJointButton.setContentHuggingPriority(.required, for: .horizontal)
        rootStack.addArrangedSubview(headerRow)

        axisSegmentedControl = makeCheerSegmentedControl(items: ["X Axis", "Y Axis", "Z Axis"])
        axisSegmentedControl.addTarget(self, action: #selector(axisChanged), for: .valueChanged)
        rootStack.addArrangedSubview(axisSegmentedControl)

        let sliderHeader = UIStackView()
        sliderHeader.axis = .horizontal
        sliderHeader.alignment = .center
        sliderHeader.spacing = 8

        let sliderTitle = UILabel()
        sliderTitle.text = "ACTIVE AXIS"
        sliderTitle.textColor = CheerPalette.textSecondary
        sliderTitle.font = cheerMonospacedFont(size: 10, weight: .bold)

        jointAngleLabel = PaddingLabel()
        jointAngleLabel.text = "0.0°"
        jointAngleLabel.textColor = CheerPalette.textPrimary
        jointAngleLabel.font = cheerMonospacedFont(size: 12, weight: .bold)
        jointAngleLabel.backgroundColor = CheerPalette.storm
        jointAngleLabel.layer.cornerRadius = 10
        jointAngleLabel.layer.borderWidth = 1
        jointAngleLabel.layer.borderColor = CheerPalette.panelBorder.cgColor
        jointAngleLabel.layer.masksToBounds = true

        sliderHeader.addArrangedSubview(sliderTitle)
        sliderHeader.addArrangedSubview(UIView())
        sliderHeader.addArrangedSubview(jointAngleLabel)
        rootStack.addArrangedSubview(sliderHeader)

        let decrementButton = CheerButton(title: "-", style: .neutral, compact: true)
        decrementButton.titleLabel?.font = cheerRoundedFont(.title3, weight: .bold)
        decrementButton.addTarget(self, action: #selector(decrementTapped), for: .touchUpInside)
        decrementButton.addTarget(self, action: #selector(decrementTouchDown), for: .touchDown)
        decrementButton.addTarget(self, action: #selector(decrementTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        decrementButton.widthAnchor.constraint(equalToConstant: 50).isActive = true

        let incrementButton = CheerButton(title: "+", style: .neutral, compact: true)
        incrementButton.titleLabel?.font = cheerRoundedFont(.title3, weight: .bold)
        incrementButton.addTarget(self, action: #selector(incrementTapped), for: .touchUpInside)
        incrementButton.addTarget(self, action: #selector(incrementTouchDown), for: .touchDown)
        incrementButton.addTarget(self, action: #selector(incrementTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        incrementButton.widthAnchor.constraint(equalToConstant: 50).isActive = true

        jointAngleSlider = UISlider()
        jointAngleSlider.translatesAutoresizingMaskIntoConstraints = false
        jointAngleSlider.minimumValue = -180
        jointAngleSlider.maximumValue = 180
        jointAngleSlider.value = 0
        jointAngleSlider.tintColor = CheerPalette.accentBlue
        jointAngleSlider.minimumTrackTintColor = CheerPalette.accentBlue
        jointAngleSlider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.12)
        jointAngleSlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)

        let sliderRow = UIStackView(arrangedSubviews: [decrementButton, jointAngleSlider, incrementButton])
        sliderRow.axis = .horizontal
        sliderRow.spacing = 10
        sliderRow.alignment = .center
        rootStack.addArrangedSubview(sliderRow)

        let firstActionRow = UIStackView(arrangedSubviews: [
            makeActionButton(title: "Library", symbol: "square.grid.2x2", style: .accent, action: #selector(poseLibraryTapped)),
            makeActionButton(title: "Reset Pose", symbol: "arrow.counterclockwise.circle", style: .danger, action: #selector(resetPoseTapped))
        ])
        firstActionRow.axis = .horizontal
        firstActionRow.spacing = 10
        firstActionRow.distribution = .fillEqually

        let secondActionRow = UIStackView(arrangedSubviews: [
            makeActionButton(title: "Fit View", symbol: "viewfinder", style: .secondary, action: #selector(fitViewTapped)),
            makeActionButton(title: "Visuals", symbol: "sparkles", style: .positive, action: #selector(toggleVisualsTapped))
        ])
        secondActionRow.axis = .horizontal
        secondActionRow.spacing = 10
        secondActionRow.distribution = .fillEqually

        let footerStack = UIStackView(arrangedSubviews: [firstActionRow, secondActionRow])
        footerStack.axis = .vertical
        footerStack.spacing = 8
        rootStack.addArrangedSubview(footerStack)
    }

    // MARK: - Public Methods

    func updateJointSelection(name: String, angle: Float) {
        jointSelectionButton.setTitle(name, for: .normal)
        updateAngleDisplay(angle: angle)
    }

    func updateAngleDisplay(angle: Float) {
        jointAngleSlider.value = angle
        jointAngleLabel.text = String(format: "%.1f°", angle)
    }

    func updateSelectedAxis(_ axis: JointAxis) {
        switch axis {
        case .x: axisSegmentedControl.selectedSegmentIndex = 0
        case .y: axisSegmentedControl.selectedSegmentIndex = 1
        case .z: axisSegmentedControl.selectedSegmentIndex = 2
        }
    }

    // MARK: - Actions

    @objc private func jointSelectionTapped() {
        delegate?.didTapJointSelection(sourceView: jointSelectionButton)
    }
    @objc private func resetJointTapped() { delegate?.didResetSelectedJoint() }

    @objc private func axisChanged() {
        let index = axisSegmentedControl.selectedSegmentIndex
        let axis: JointAxis = (index == 0) ? .x : (index == 1) ? .y : .z
        delegate?.didSelectAxis(axis)
    }

    @objc private func sliderChanged() {
        delegate?.didChangeJointAngle(value: jointAngleSlider.value)
        jointAngleLabel.text = String(format: "%.1f°", jointAngleSlider.value)
    }

    @objc private func decrementTapped() { delegate?.didDecrementAngle() }
    @objc private func incrementTapped() { delegate?.didIncrementAngle() }

    @objc private func decrementTouchDown() { delegate?.didBeginDecrementingAngle() }
    @objc private func decrementTouchUp() { delegate?.didEndDecrementingAngle() }
    @objc private func incrementTouchDown() { delegate?.didBeginIncrementingAngle() }
    @objc private func incrementTouchUp() { delegate?.didEndIncrementingAngle() }

    @objc private func poseLibraryTapped() { delegate?.didTapPoseLibrary() }
    @objc private func resetPoseTapped() { delegate?.didTapResetPose() }
    @objc private func fitViewTapped() { delegate?.didTapFitView() }
    @objc private func toggleVisualsTapped() { delegate?.didTapToggleVisualizations() }

    // MARK: - Helper

    private func makeActionButton(title: String, symbol: String, style: CheerButtonStyle, action: Selector) -> UIButton {
        let button = CheerButton(title: title, symbol: symbol, style: style, compact: true)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
}
