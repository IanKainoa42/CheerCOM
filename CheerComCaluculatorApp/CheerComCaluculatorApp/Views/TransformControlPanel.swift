import UIKit

protocol TransformControlPanelDelegate: AnyObject {
    func didChangeTransformMode(_ mode: TransformMode)
    func didTapTransform(direction: TransformDirection)
    func didTapResetTransform()
    func didChangeTransformStepMultiplier(_ multiplier: Float)
}

class TransformControlPanel: UIView {

    weak var delegate: TransformControlPanelDelegate?

    private var transformModeLabel: UILabel!
    private var panel: UIVisualEffectView!
    private var stepSegmentedControl: UISegmentedControl!
    private let stepMultipliers: [Float] = [0.5, 1.0, 2.0, 5.0]

    init(width: CGFloat) {
        super.init(frame: .zero)  // Frame will be set by parent or constraints
        setupUI(width: width)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI(width: CGFloat) {
        // Add transform mode label at top right
        transformModeLabel = UILabel(
            frame: CGRect(x: 0, y: 0, width: 220, height: 30))
        transformModeLabel.text = "Transform: Position"
        transformModeLabel.textColor = .white
        transformModeLabel.font = .boldSystemFont(ofSize: 16)
        transformModeLabel.textAlignment = .center
        transformModeLabel.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.7)
        transformModeLabel.layer.cornerRadius = 8
        transformModeLabel.layer.masksToBounds = true
        addSubview(transformModeLabel)

        // Add transform control panel
        panel = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        panel.frame = CGRect(x: 0, y: 40, width: 220, height: 240)
        panel.layer.cornerRadius = 15
        panel.layer.masksToBounds = true
        addSubview(panel)

        self.frame = CGRect(x: width - 240, y: 110, width: 220, height: 280)
        self.autoresizingMask = [.flexibleLeftMargin]

        // Transform mode buttons
        let posTransformBtn = createButton(
            title: "Position", x: 10, y: 10, width: 65, height: 35,
            action: #selector(positionModeTapped))
        posTransformBtn.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.9)
        panel.contentView.addSubview(posTransformBtn)

        let rotTransformBtn = createButton(
            title: "Rotate", x: 78, y: 10, width: 65, height: 35,
            action: #selector(rotationModeTapped)
        )
        rotTransformBtn.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.6)
        panel.contentView.addSubview(rotTransformBtn)

        let scaleTransformBtn = createButton(
            title: "Scale", x: 145, y: 10, width: 65, height: 35, action: #selector(scaleModeTapped)
        )
        scaleTransformBtn.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.6)
        panel.contentView.addSubview(scaleTransformBtn)

        // Arrow key-style controls
        let arrowSize: CGFloat = 45
        let centerX: CGFloat = 110
        let centerY: CGFloat = 100

        // Up arrow
        let upBtn = createButton(
            title: "↑", x: centerX - arrowSize / 2, y: centerY - arrowSize - 5, width: arrowSize,
            height: arrowSize, action: #selector(upTapped))
        upBtn.titleLabel?.font = .systemFont(ofSize: 24)
        panel.contentView.addSubview(upBtn)

        // Down arrow
        let downBtn = createButton(
            title: "↓", x: centerX - arrowSize / 2, y: centerY + 5, width: arrowSize,
            height: arrowSize, action: #selector(downTapped))
        downBtn.titleLabel?.font = .systemFont(ofSize: 24)
        panel.contentView.addSubview(downBtn)

        // Left arrow
        let leftBtn = createButton(
            title: "←", x: centerX - arrowSize - arrowSize / 2 - 5, y: centerY - arrowSize / 2,
            width: arrowSize, height: arrowSize, action: #selector(leftTapped))
        leftBtn.titleLabel?.font = .systemFont(ofSize: 24)
        panel.contentView.addSubview(leftBtn)

        // Right arrow
        let rightBtn = createButton(
            title: "→", x: centerX + arrowSize / 2 + 5, y: centerY - arrowSize / 2,
            width: arrowSize, height: arrowSize, action: #selector(rightTapped))
        rightBtn.titleLabel?.font = .systemFont(ofSize: 24)
        panel.contentView.addSubview(rightBtn)

        let stepLabel = UILabel(frame: CGRect(x: 10, y: 152, width: 200, height: 16))
        stepLabel.text = "Step Size"
        stepLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        stepLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        stepLabel.textAlignment = .center
        panel.contentView.addSubview(stepLabel)

        stepSegmentedControl = UISegmentedControl(items: ["0.5x", "1x", "2x", "5x"])
        stepSegmentedControl.frame = CGRect(x: 10, y: 170, width: 200, height: 28)
        stepSegmentedControl.selectedSegmentIndex = 1
        stepSegmentedControl.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        stepSegmentedControl.selectedSegmentTintColor = UIColor.systemTeal.withAlphaComponent(0.9)
        stepSegmentedControl.setTitleTextAttributes(
            [.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 11, weight: .bold)],
            for: .normal
        )
        stepSegmentedControl.setTitleTextAttributes(
            [.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 11, weight: .bold)],
            for: .selected
        )
        stepSegmentedControl.addTarget(self, action: #selector(stepSizeChanged), for: .valueChanged)
        panel.contentView.addSubview(stepSegmentedControl)

        // Reset transform button
        let resetTransformBtn = createButton(
            title: "Reset Position", x: 10, y: 205, width: 200, height: 30,
            action: #selector(resetTapped))
        resetTransformBtn.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.8)
        panel.contentView.addSubview(resetTransformBtn)
    }

    func updateModeDisplay(mode: TransformMode, step: Float) {
        switch mode {
        case .position:
            transformModeLabel.text = "Transform: Position (\(formattedStep(step)))"
        case .rotation:
            transformModeLabel.text = "Transform: Rotation (\(formattedStep(step)))"
        case .scale:
            transformModeLabel.text = "Transform: Scale (\(formattedStep(step)))"
        }
    }

    func updateStepMultiplierSelection(_ multiplier: Float) {
        if let index = stepMultipliers.firstIndex(where: { abs($0 - multiplier) < 0.001 }) {
            stepSegmentedControl.selectedSegmentIndex = index
        }
    }

    // MARK: - Actions

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

    private func createButton(
        title: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, action: Selector
    ) -> UIButton {
        let button = UIButton(frame: CGRect(x: x, y: y, width: width, height: height))
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 14)
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: action, for: .touchUpInside)

        // Add visual feedback on touch
        button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        button.addTarget(
            self, action: #selector(buttonTouchUp(_:)),
            for: [.touchUpInside, .touchUpOutside, .touchCancel])

        return button
    }

    @objc private func buttonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.05) {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            sender.alpha = 1.0
        }
    }

    @objc private func buttonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = .identity
        }
    }

    private func formattedStep(_ step: Float) -> String {
        if step >= 1 {
            return String(format: "%.1f", step)
        }
        return String(format: "%.2f", step)
    }
}
