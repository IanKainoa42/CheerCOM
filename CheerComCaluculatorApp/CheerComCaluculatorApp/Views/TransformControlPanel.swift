import UIKit

protocol TransformControlPanelDelegate: AnyObject {
    func didChangeTransformMode(_ mode: TransformMode)
    func didTapTransform(direction: TransformDirection)
    func didBeginContinuousTransform(direction: TransformDirection)
    func didEndContinuousTransform()
    func didTapResetTransform()
    func didChangeTransformStepMultiplier(_ multiplier: Float)
    func didTapPoseLibraryFromTransformPanel()
    func didTapResetPoseFromTransformPanel()
    func didTapFitViewFromTransformPanel()
    func didTapToggleVisualizationsFromTransformPanel()
}

class TransformControlPanel: CheerGlassPanel {

    weak var delegate: TransformControlPanelDelegate?

    private var modeSummaryLabel: UILabel!
    private var stepSegmentedControl: UISegmentedControl!
    private var modeSegmentedControl: UISegmentedControl!
    private var centerBadge: PaddingLabel!
    private let stepMultipliers: [Float] = [0.5, 1.0, 2.0, 5.0]
    private var pressedDirection: TransformDirection?
    private var holdStartWorkItem: DispatchWorkItem?
    private var isContinuousTransformActive = false

    init(width: CGFloat) {
        super.init(padding: .init(top: 14, leading: 14, bottom: 14, trailing: 14))
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentStack.spacing = 12

        let eyebrowLabel = UILabel()
        eyebrowLabel.text = "POSE CONTROL"
        eyebrowLabel.textColor = CheerPalette.accentMint
        eyebrowLabel.font = cheerMonospacedFont(size: 10, weight: .bold)

        let titleLabel = UILabel()
        titleLabel.text = "MODEL TRANSFORM"
        titleLabel.textColor = CheerPalette.textPrimary
        titleLabel.font = cheerRoundedFont(.headline, weight: .bold)

        modeSummaryLabel = UILabel()
        modeSummaryLabel.text = "POSITION // STEP 5.0"
        modeSummaryLabel.textColor = CheerPalette.textSecondary
        modeSummaryLabel.font = cheerMonospacedFont(size: 10, weight: .bold)

        let titleStack = UIStackView(arrangedSubviews: [eyebrowLabel, titleLabel, modeSummaryLabel])
        titleStack.axis = .vertical
        titleStack.spacing = 4
        contentStack.addArrangedSubview(titleStack)

        let helperLabel = UILabel()
        helperLabel.text = "Use the pad to move the rig around the pose. ↗ and ↙ adjust depth on the Z axis."
        helperLabel.textColor = CheerPalette.textSecondary
        helperLabel.font = cheerMonospacedFont(size: 10, weight: .regular)
        helperLabel.numberOfLines = 0
        contentStack.addArrangedSubview(helperLabel)

        modeSegmentedControl = makeCheerSegmentedControl(items: ["Move", "Rotate", "Scale"])
        modeSegmentedControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        contentStack.addArrangedSubview(modeSegmentedControl)

        let dPadStack = UIStackView()
        dPadStack.axis = .vertical
        dPadStack.spacing = 8

        centerBadge = PaddingLabel()
        centerBadge.text = "Step 5.0"
        centerBadge.textAlignment = .center
        centerBadge.textColor = CheerPalette.textPrimary
        centerBadge.font = cheerMonospacedFont(size: 12, weight: .bold)
        centerBadge.backgroundColor = CheerPalette.storm
        centerBadge.layer.cornerRadius = 10
        centerBadge.layer.borderWidth = 1
        centerBadge.layer.borderColor = CheerPalette.panelBorder.cgColor
        centerBadge.layer.masksToBounds = true

        let upButton = directionButton(title: "↑", direction: .up)
        let leftButton = directionButton(title: "←", direction: .left)
        let rightButton = directionButton(title: "→", direction: .right)
        let downButton = directionButton(title: "↓", direction: .down)
        let forwardButton = directionButton(title: "↗", direction: .forward)
        let backwardButton = directionButton(title: "↙", direction: .backward)

        let topRow = dPadRow(left: UIView(), center: upButton, right: forwardButton)
        let middleRow = dPadRow(left: leftButton, center: centerBadge, right: rightButton)
        let bottomRow = dPadRow(left: backwardButton, center: downButton, right: UIView())

        dPadStack.addArrangedSubview(topRow)
        dPadStack.addArrangedSubview(middleRow)
        dPadStack.addArrangedSubview(bottomRow)
        contentStack.addArrangedSubview(dPadStack)

        let stepLabel = UILabel()
        stepLabel.text = "STEP MULTIPLIER"
        stepLabel.textColor = CheerPalette.textSecondary
        stepLabel.font = cheerMonospacedFont(size: 10, weight: .bold)
        contentStack.addArrangedSubview(stepLabel)

        stepSegmentedControl = makeCheerSegmentedControl(items: ["0.5x", "1x", "2x", "5x"])
        stepSegmentedControl.selectedSegmentIndex = 1
        stepSegmentedControl.addTarget(self, action: #selector(stepSizeChanged), for: .valueChanged)
        contentStack.addArrangedSubview(stepSegmentedControl)

        let resetButton = CheerButton(title: "Reset Transform", symbol: "arrow.counterclockwise.circle", style: .secondary)
        resetButton.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(resetButton)

        let topActionRow = UIStackView(arrangedSubviews: [
            makeActionButton(title: "Pose Library", symbol: "square.grid.2x2", style: .accent, action: #selector(poseLibraryTapped)),
            makeActionButton(title: "Reset Pose", symbol: "figure.stand.line.dotted.figure.stand", style: .danger, action: #selector(resetPoseTapped))
        ])
        topActionRow.axis = .horizontal
        topActionRow.spacing = 8
        topActionRow.distribution = .fillEqually
        contentStack.addArrangedSubview(topActionRow)

        let bottomActionRow = UIStackView(arrangedSubviews: [
            makeActionButton(title: "Fit View", symbol: "viewfinder", style: .neutral, action: #selector(fitViewTapped)),
            makeActionButton(title: "Visuals", symbol: "sparkles", style: .positive, action: #selector(toggleVisualsTapped))
        ])
        bottomActionRow.axis = .horizontal
        bottomActionRow.spacing = 8
        bottomActionRow.distribution = .fillEqually
        contentStack.addArrangedSubview(bottomActionRow)
    }

    func updateModeDisplay(mode: TransformMode, step: Float) {
        switch mode {
        case .position:
            modeSegmentedControl.selectedSegmentIndex = 0
            modeSummaryLabel.text = "POSITION // STEP \(formattedStep(step))"
        case .rotation:
            modeSegmentedControl.selectedSegmentIndex = 1
            modeSummaryLabel.text = "ROTATION // STEP \(formattedStep(step))"
        case .scale:
            modeSegmentedControl.selectedSegmentIndex = 2
            modeSummaryLabel.text = "SCALE // STEP \(formattedStep(step))"
        }
        centerBadge.text = "Step \(formattedStep(step))"
    }

    func updateStepMultiplierSelection(_ multiplier: Float) {
        if let index = stepMultipliers.firstIndex(where: { abs($0 - multiplier) < 0.001 }) {
            stepSegmentedControl.selectedSegmentIndex = index
        }
    }

    // MARK: - Actions

    @objc private func modeChanged() {
        switch modeSegmentedControl.selectedSegmentIndex {
        case 0: delegate?.didChangeTransformMode(.position)
        case 1: delegate?.didChangeTransformMode(.rotation)
        default: delegate?.didChangeTransformMode(.scale)
        }
    }

    @objc private func positionModeTapped() { delegate?.didChangeTransformMode(.position) }
    @objc private func rotationModeTapped() { delegate?.didChangeTransformMode(.rotation) }
    @objc private func scaleModeTapped() { delegate?.didChangeTransformMode(.scale) }

    @objc private func resetTapped() { delegate?.didTapResetTransform() }
    @objc private func stepSizeChanged() {
        let multiplier = stepMultipliers[stepSegmentedControl.selectedSegmentIndex]
        delegate?.didChangeTransformStepMultiplier(multiplier)
    }
    @objc private func poseLibraryTapped() { delegate?.didTapPoseLibraryFromTransformPanel() }
    @objc private func resetPoseTapped() { delegate?.didTapResetPoseFromTransformPanel() }
    @objc private func fitViewTapped() { delegate?.didTapFitViewFromTransformPanel() }
    @objc private func toggleVisualsTapped() { delegate?.didTapToggleVisualizationsFromTransformPanel() }

    // MARK: - Helper

    private func dPadRow(left: UIView, center: UIView, right: UIView) -> UIStackView {
        let row = UIStackView(arrangedSubviews: [left, center, right])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        row.distribution = .fillEqually
        return row
    }

    private func makeActionButton(title: String, symbol: String, style: CheerButtonStyle, action: Selector) -> UIButton {
        let button = CheerButton(title: title, symbol: symbol, style: style, compact: true)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func directionButton(title: String, direction: TransformDirection) -> UIButton {
        let button = CheerButton(title: title, style: .neutral)
        button.accessibilityIdentifier = direction.rawValue
        button.addTarget(self, action: #selector(directionPressed(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(directionReleasedInside(_:)), for: .touchUpInside)
        button.addTarget(self, action: #selector(directionReleasedOutside(_:)), for: [.touchUpOutside, .touchCancel])
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return button
    }

    private func direction(for button: UIButton) -> TransformDirection? {
        guard let rawValue = button.accessibilityIdentifier else { return nil }
        return TransformDirection(rawValue: rawValue)
    }

    @objc private func directionPressed(_ sender: UIButton) {
        guard let direction = direction(for: sender) else { return }
        pressedDirection = direction
        isContinuousTransformActive = false

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.pressedDirection == direction else { return }
            self.isContinuousTransformActive = true
            self.delegate?.didBeginContinuousTransform(direction: direction)
        }
        holdStartWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    @objc private func directionReleasedInside(_ sender: UIButton) {
        guard let direction = direction(for: sender) else { return }
        finishDirectionInteraction(direction: direction, treatAsTap: !isContinuousTransformActive)
    }

    @objc private func directionReleasedOutside(_ sender: UIButton) {
        guard let direction = direction(for: sender) else { return }
        finishDirectionInteraction(direction: direction, treatAsTap: false)
    }

    private func finishDirectionInteraction(direction: TransformDirection, treatAsTap: Bool) {
        holdStartWorkItem?.cancel()
        holdStartWorkItem = nil

        let wasContinuous = isContinuousTransformActive && pressedDirection == direction
        pressedDirection = nil
        isContinuousTransformActive = false

        if wasContinuous {
            delegate?.didEndContinuousTransform()
        } else if treatAsTap {
            delegate?.didTapTransform(direction: direction)
        }
    }

    private func formattedStep(_ step: Float) -> String {
        if step >= 1 {
            return String(format: "%.1f", step)
        }
        return String(format: "%.2f", step)
    }
}
