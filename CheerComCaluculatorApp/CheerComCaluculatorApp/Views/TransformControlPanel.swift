import UIKit

protocol TransformControlPanelDelegate: AnyObject {
    func didChangeTransformMode(_ mode: TransformMode)
    func didTapTransform(direction: TransformDirection)
    func didTapResetTransform()
    func didChangeTransformStepMultiplier(_ multiplier: Float)
}

class TransformControlPanel: CheerGlassPanel {

    weak var delegate: TransformControlPanelDelegate?

    private var modeSummaryLabel: UILabel!
    private var stepSegmentedControl: UISegmentedControl!
    private var modeSegmentedControl: UISegmentedControl!
    private var centerBadge: PaddingLabel!
    private let stepMultipliers: [Float] = [0.5, 1.0, 2.0, 5.0]

    init(width: CGFloat) {
        super.init(padding: .init(top: 18, leading: 18, bottom: 18, trailing: 18))
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentStack.spacing = 14

        let titleLabel = UILabel()
        titleLabel.text = "Transform"
        titleLabel.textColor = CheerPalette.textPrimary
        titleLabel.font = cheerRoundedFont(.headline, weight: .bold)

        modeSummaryLabel = UILabel()
        modeSummaryLabel.text = "Position • 5.0"
        modeSummaryLabel.textColor = CheerPalette.textSecondary
        modeSummaryLabel.font = cheerRoundedFont(.subheadline, weight: .semibold)

        let titleStack = UIStackView(arrangedSubviews: [titleLabel, modeSummaryLabel])
        titleStack.axis = .vertical
        titleStack.spacing = 2
        contentStack.addArrangedSubview(titleStack)

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
        centerBadge.font = cheerMonospacedFont(size: 13, weight: .bold)
        centerBadge.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        centerBadge.layer.cornerRadius = 16
        centerBadge.layer.masksToBounds = true

        let upButton = directionButton(title: "↑", action: #selector(upTapped))
        let leftButton = directionButton(title: "←", action: #selector(leftTapped))
        let rightButton = directionButton(title: "→", action: #selector(rightTapped))
        let downButton = directionButton(title: "↓", action: #selector(downTapped))

        let topRow = dPadRow(left: UIView(), center: upButton, right: UIView())
        let middleRow = dPadRow(left: leftButton, center: centerBadge, right: rightButton)
        let bottomRow = dPadRow(left: UIView(), center: downButton, right: UIView())

        dPadStack.addArrangedSubview(topRow)
        dPadStack.addArrangedSubview(middleRow)
        dPadStack.addArrangedSubview(bottomRow)
        contentStack.addArrangedSubview(dPadStack)

        let stepLabel = UILabel()
        stepLabel.text = "Step Multiplier"
        stepLabel.textColor = CheerPalette.textSecondary
        stepLabel.font = cheerRoundedFont(.subheadline, weight: .semibold)
        contentStack.addArrangedSubview(stepLabel)

        stepSegmentedControl = makeCheerSegmentedControl(items: ["0.5x", "1x", "2x", "5x"])
        stepSegmentedControl.selectedSegmentIndex = 1
        stepSegmentedControl.addTarget(self, action: #selector(stepSizeChanged), for: .valueChanged)
        contentStack.addArrangedSubview(stepSegmentedControl)

        let resetButton = CheerButton(title: "Reset Transform", symbol: "arrow.counterclockwise.circle", style: .secondary)
        resetButton.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(resetButton)
    }

    func updateModeDisplay(mode: TransformMode, step: Float) {
        switch mode {
        case .position:
            modeSegmentedControl.selectedSegmentIndex = 0
            modeSummaryLabel.text = "Position • \(formattedStep(step))"
        case .rotation:
            modeSegmentedControl.selectedSegmentIndex = 1
            modeSummaryLabel.text = "Rotation • \(formattedStep(step))"
        case .scale:
            modeSegmentedControl.selectedSegmentIndex = 2
            modeSummaryLabel.text = "Scale • \(formattedStep(step))"
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

    @objc private func upTapped() { delegate?.didTapTransform(direction: .up) }
    @objc private func downTapped() { delegate?.didTapTransform(direction: .down) }
    @objc private func leftTapped() { delegate?.didTapTransform(direction: .left) }
    @objc private func rightTapped() { delegate?.didTapTransform(direction: .right) }

    @objc private func resetTapped() { delegate?.didTapResetTransform() }
    @objc private func stepSizeChanged() {
        let multiplier = stepMultipliers[stepSegmentedControl.selectedSegmentIndex]
        delegate?.didChangeTransformStepMultiplier(multiplier)
    }

    // MARK: - Helper

    private func dPadRow(left: UIView, center: UIView, right: UIView) -> UIStackView {
        let row = UIStackView(arrangedSubviews: [left, center, right])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        row.distribution = .fillEqually
        return row
    }

    private func directionButton(title: String, action: Selector) -> UIButton {
        let button = CheerButton(title: title, style: .neutral)
        button.titleLabel?.font = cheerRoundedFont(.title2, weight: .bold)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return button
    }

    private func formattedStep(_ step: Float) -> String {
        if step >= 1 {
            return String(format: "%.1f", step)
        }
        return String(format: "%.2f", step)
    }
}
