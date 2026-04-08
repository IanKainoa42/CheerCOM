import UIKit
import SceneKit
import ModelRigKit


protocol JointControlPanelDelegate: AnyObject {
    func didTapJointSelection(sourceView: UIView)
    func didChangeJointAngle(axis: JointAxis, value: Float)
    func didIncrementAngle(axis: JointAxis)
    func didDecrementAngle(axis: JointAxis)
    func didBeginIncrementingAngle(axis: JointAxis)
    func didEndIncrementingAngle(axis: JointAxis)
    func didBeginDecrementingAngle(axis: JointAxis)
    func didEndDecrementingAngle(axis: JointAxis)
    func didResetSelectedJoint()
    func didTapJointPresets(sourceView: UIView)
    func didTapSaveJointPreset()

    func didTapPoseLibrary()
    func didTapResetPose()

    func didTapFitView()
    func didTapToggleVisualizations()
}

class AxisControlBox: UIStackView {
    let jointAxis: JointAxis
    let slider = UISlider()
    let angleLabel = PaddingLabel()
    let decrementBtn = CheerButton(title: "-", style: .neutral, compact: true)
    let incrementBtn = CheerButton(title: "+", style: .neutral, compact: true)

    init(axis: JointAxis) {
        self.jointAxis = axis
        super.init(frame: .zero)
        self.axis = .vertical
        spacing = 6
        alignment = .fill

        let axisTitle = UILabel()
        axisTitle.text = self.jointAxis.shortLabel
        axisTitle.textColor = CheerPalette.textSecondary
        axisTitle.font = cheerMonospacedFont(size: 14, weight: .bold)

        angleLabel.text = "0.0°"
        angleLabel.textColor = CheerPalette.textPrimary
        angleLabel.font = cheerMonospacedFont(size: 11, weight: .bold)
        angleLabel.backgroundColor = CheerPalette.storm
        angleLabel.layer.cornerRadius = 8
        angleLabel.layer.borderWidth = 1
        angleLabel.layer.borderColor = CheerPalette.panelBorder.cgColor
        angleLabel.layer.masksToBounds = true
        angleLabel.textAlignment = .center
        angleLabel.widthAnchor.constraint(equalToConstant: 50).isActive = true

        decrementBtn.titleLabel?.font = cheerRoundedFont(.title3, weight: .bold)
        decrementBtn.widthAnchor.constraint(equalToConstant: 44).isActive = true
        decrementBtn.heightAnchor.constraint(equalToConstant: 34).isActive = true

        incrementBtn.titleLabel?.font = cheerRoundedFont(.title3, weight: .bold)
        incrementBtn.widthAnchor.constraint(equalToConstant: 44).isActive = true
        incrementBtn.heightAnchor.constraint(equalToConstant: 34).isActive = true

        slider.minimumValue = -180
        slider.maximumValue = 180
        slider.value = 0
        slider.tintColor = CheerPalette.accentBlue
        slider.minimumTrackTintColor = CheerPalette.accentBlue
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.12)
        slider.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let buttonStack = UIStackView(arrangedSubviews: [decrementBtn, incrementBtn])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 8
        buttonStack.alignment = .center

        let headerRow = UIStackView(arrangedSubviews: [axisTitle, UIView(), buttonStack, angleLabel])
        headerRow.axis = .horizontal
        headerRow.spacing = 8
        headerRow.alignment = .center

        addArrangedSubview(headerRow)
        addArrangedSubview(slider)
    }

    required init(coder: NSCoder) { fatalError() }
}

class JointControlPanel: UIView {

    weak var delegate: JointControlPanelDelegate?

    private let panel = CheerGlassPanel(padding: .init(top: 14, leading: 14, bottom: 14, trailing: 14))
    private let contentContainer = UIView()
    private let sectionLabel = UILabel()
    private var jointSelectionButton: CheerButton!
    
    private let xAxisRow = AxisControlBox(axis: .x)
    private let yAxisRow = AxisControlBox(axis: .y)
    private let zAxisRow = AxisControlBox(axis: .z)

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
            contentContainer.leadingAnchor.constraint(equalTo: panel.contentView.layoutMarginsGuide.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: panel.contentView.layoutMarginsGuide.trailingAnchor),
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

        jointSelectionButton = CheerButton(title: "Select Joint", style: .accent)
        jointSelectionButton.titleLabel?.adjustsFontSizeToFitWidth = true
        jointSelectionButton.titleLabel?.minimumScaleFactor = 0.82
        jointSelectionButton.addTarget(self, action: #selector(jointSelectionTapped), for: .touchUpInside)

        let resetJointButton = CheerButton(title: "Reset", symbol: "arrow.counterclockwise", style: .secondary, compact: true)
        resetJointButton.addTarget(self, action: #selector(resetJointTapped), for: .touchUpInside)

        let headerRow = UIStackView(arrangedSubviews: [jointSelectionButton, resetJointButton])
        headerRow.axis = .horizontal
        headerRow.spacing = 10
        headerRow.alignment = .fill
        jointSelectionButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        resetJointButton.setContentHuggingPriority(.required, for: .horizontal)
        rootStack.addArrangedSubview(headerRow)

        let slidersContainer = UIStackView(arrangedSubviews: [xAxisRow, yAxisRow, zAxisRow])
        slidersContainer.axis = .vertical
        slidersContainer.spacing = 8
        rootStack.addArrangedSubview(slidersContainer)
        
        setupAxisRow(xAxisRow)
        setupAxisRow(yAxisRow)
        setupAxisRow(zAxisRow)

        let presetRow = UIStackView(arrangedSubviews: [
            makeActionButton(title: "Joint Presets", symbol: "slider.horizontal.3", style: .secondary, action: #selector(jointPresetsTapped)),
            makeActionButton(title: "Save Joint", symbol: "bookmark.fill", style: .accent, action: #selector(saveJointPresetTapped))
        ])
        presetRow.axis = .horizontal
        presetRow.spacing = 10
        presetRow.distribution = .fillEqually
        rootStack.addArrangedSubview(presetRow)

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

    private func setupAxisRow(_ row: AxisControlBox) {
        row.slider.addTarget(self, action: #selector(sliderChanged(_:)), for: .valueChanged)
        
        row.decrementBtn.addTarget(self, action: #selector(decrementTapped(_:)), for: .touchUpInside)
        row.decrementBtn.addTarget(self, action: #selector(decrementTouchDown(_:)), for: .touchDown)
        row.decrementBtn.addTarget(self, action: #selector(decrementTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        row.incrementBtn.addTarget(self, action: #selector(incrementTapped(_:)), for: .touchUpInside)
        row.incrementBtn.addTarget(self, action: #selector(incrementTouchDown(_:)), for: .touchDown)
        row.incrementBtn.addTarget(self, action: #selector(incrementTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    // MARK: - Public Methods

    func updateJointSelection(name: String, angles: SCNVector3) {
        jointSelectionButton.setTitle(name, for: .normal)
        updateAngleDisplays(angles: angles)
    }

    func updateAngleDisplays(angles: SCNVector3) {
        let x = angles.x * 180 / .pi
        let y = angles.y * 180 / .pi
        let z = angles.z * 180 / .pi
        
        xAxisRow.slider.value = x
        xAxisRow.angleLabel.text = String(format: "%.0f°", x)
        
        yAxisRow.slider.value = y
        yAxisRow.angleLabel.text = String(format: "%.0f°", y)
        
        zAxisRow.slider.value = z
        zAxisRow.angleLabel.text = String(format: "%.0f°", z)
    }

    // MARK: - Actions

    private func axisFor(view: UIView) -> JointAxis? {
        var current: UIView? = view
        while let view = current {
            if let row = view as? AxisControlBox { return row.jointAxis }
            current = view.superview
        }
        return nil
    }

    @objc private func jointSelectionTapped() { delegate?.didTapJointSelection(sourceView: jointSelectionButton) }
    @objc private func resetJointTapped() { delegate?.didResetSelectedJoint() }

    @objc private func sliderChanged(_ sender: UISlider) {
        guard let axis = axisFor(view: sender) else { return }
        delegate?.didChangeJointAngle(axis: axis, value: sender.value)
        updateAngleLabel(for: sender, value: sender.value)
    }

    @objc private func decrementTapped(_ btn: UIButton) { if let ax = axisFor(view: btn) { delegate?.didDecrementAngle(axis: ax) } }
    @objc private func incrementTapped(_ btn: UIButton) { if let ax = axisFor(view: btn) { delegate?.didIncrementAngle(axis: ax) } }

    @objc private func decrementTouchDown(_ btn: UIButton) { if let ax = axisFor(view: btn) { delegate?.didBeginDecrementingAngle(axis: ax) } }
    @objc private func decrementTouchUp(_ btn: UIButton) { if let ax = axisFor(view: btn) { delegate?.didEndDecrementingAngle(axis: ax) } }
    @objc private func incrementTouchDown(_ btn: UIButton) { if let ax = axisFor(view: btn) { delegate?.didBeginIncrementingAngle(axis: ax) } }
    @objc private func incrementTouchUp(_ btn: UIButton) { if let ax = axisFor(view: btn) { delegate?.didEndIncrementingAngle(axis: ax) } }

    @objc private func jointPresetsTapped(_ sender: UIButton) { delegate?.didTapJointPresets(sourceView: sender) }
    @objc private func saveJointPresetTapped() { delegate?.didTapSaveJointPreset() }
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

    private func updateAngleLabel(for view: UIView, value: Float) {
        var current: UIView? = view
        while let view = current {
            if let row = view as? AxisControlBox {
                row.angleLabel.text = String(format: "%.0f°", value)
                return
            }
            current = view.superview
        }
    }
}

private extension JointAxis {
    var shortLabel: String {
        switch self {
        case .x: return "X"
        case .y: return "Y"
        case .z: return "Z"
        }
    }
}
