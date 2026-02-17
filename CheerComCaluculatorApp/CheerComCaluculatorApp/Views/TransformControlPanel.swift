import UIKit

protocol TransformControlPanelDelegate: AnyObject {
    func didChangeTransformMode(_ mode: TransformMode)
    func didTapTransform(direction: TransformDirection)
    func didTapResetTransform()
    func didChangeTransformStep(_ step: Float)
}

class TransformControlPanel: UIView {

    weak var delegate: TransformControlPanelDelegate?

    private var transformModeLabel: UILabel!
    private var transformStepLabel: UILabel!
    private var transformStepStepper: UIStepper!
    private var panel: UIVisualEffectView!

    private var positionModeButton: UIButton!
    private var rotationModeButton: UIButton!
    private var scaleModeButton: UIButton!
    private var resetTransformButton: UIButton!

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
        panel.frame = CGRect(x: 0, y: 40, width: 220, height: 250)
        panel.layer.cornerRadius = 15
        panel.layer.masksToBounds = true
        addSubview(panel)

        self.frame = CGRect(x: width - 240, y: 110, width: 220, height: 290)
        self.autoresizingMask = [.flexibleLeftMargin]

        // Transform mode buttons
        positionModeButton = createButton(
            title: "Position", x: 10, y: 10, width: 65, height: 35,
            action: #selector(positionModeTapped))
        panel.contentView.addSubview(positionModeButton)

        rotationModeButton = createButton(
            title: "Rotate", x: 78, y: 10, width: 65, height: 35,
            action: #selector(rotationModeTapped)
        )
        panel.contentView.addSubview(rotationModeButton)

        scaleModeButton = createButton(
            title: "Scale", x: 145, y: 10, width: 65, height: 35, action: #selector(scaleModeTapped)
        )
        panel.contentView.addSubview(scaleModeButton)

        // Step size controls
        transformStepLabel = UILabel(frame: CGRect(x: 10, y: 50, width: 130, height: 24))
        transformStepLabel.textColor = .white
        transformStepLabel.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        transformStepLabel.textAlignment = .left
        transformStepLabel.text = "Step: 5.0"
        panel.contentView.addSubview(transformStepLabel)

        transformStepStepper = UIStepper(frame: CGRect(x: 145, y: 47, width: 65, height: 28))
        transformStepStepper.minimumValue = 0.1
        transformStepStepper.maximumValue = 20.0
        transformStepStepper.stepValue = 0.1
        transformStepStepper.value = 5.0
        transformStepStepper.addTarget(self, action: #selector(stepValueChanged), for: .valueChanged)
        panel.contentView.addSubview(transformStepStepper)

        // Arrow key-style controls
        let arrowSize: CGFloat = 45
        let centerX: CGFloat = 110
        let centerY: CGFloat = 135

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

        // Reset transform button
        resetTransformButton = createButton(
            title: "Reset Position", x: 10, y: 205, width: 200, height: 35,
            action: #selector(resetTapped))
        resetTransformButton.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.8)
        panel.contentView.addSubview(resetTransformButton)

        updateModeButtons(for: .position)
    }

    func updateModeDisplay(mode: TransformMode) {
        switch mode {
        case .position:
            transformModeLabel.text = "Transform: Position"
            resetTransformButton.setTitle("Reset Position", for: .normal)
        case .rotation:
            transformModeLabel.text = "Transform: Rotation"
            resetTransformButton.setTitle("Reset Rotation", for: .normal)
        case .scale:
            transformModeLabel.text = "Transform: Scale"
            resetTransformButton.setTitle("Reset Scale", for: .normal)
        }
        updateModeButtons(for: mode)
    }

    func updateStepDisplay(_ step: Float) {
        transformStepStepper.value = Double(step)
        transformStepLabel.text = String(format: "Step: %.1f", step)
    }

    private func updateModeButtons(for mode: TransformMode) {
        let selected = UIColor.systemPurple.withAlphaComponent(0.9)
        let unselected = UIColor.systemPurple.withAlphaComponent(0.6)

        positionModeButton.backgroundColor = (mode == .position) ? selected : unselected
        rotationModeButton.backgroundColor = (mode == .rotation) ? selected : unselected
        scaleModeButton.backgroundColor = (mode == .scale) ? selected : unselected
    }

    // MARK: - Actions

    @objc private func positionModeTapped() { delegate?.didChangeTransformMode(.position) }
    @objc private func rotationModeTapped() { delegate?.didChangeTransformMode(.rotation) }
    @objc private func scaleModeTapped() { delegate?.didChangeTransformMode(.scale) }

    @objc private func stepValueChanged() {
        let step = Float((transformStepStepper.value * 10).rounded() / 10)
        transformStepLabel.text = String(format: "Step: %.1f", step)
        delegate?.didChangeTransformStep(step)
    }

    @objc private func upTapped() { delegate?.didTapTransform(direction: .up) }
    @objc private func downTapped() { delegate?.didTapTransform(direction: .down) }
    @objc private func leftTapped() { delegate?.didTapTransform(direction: .left) }
    @objc private func rightTapped() { delegate?.didTapTransform(direction: .right) }

    @objc private func resetTapped() { delegate?.didTapResetTransform() }

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
}
