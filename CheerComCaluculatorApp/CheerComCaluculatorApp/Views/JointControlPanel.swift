import UIKit

protocol JointControlPanelDelegate: AnyObject {
    func didTapJointSelection(sourceView: UIView)
    func didSelectAxis(_ axis: JointAxis)
    func didChangeJointAngle(value: Float)
    func didIncrementAngle()
    func didDecrementAngle()
    func didResetSelectedJoint()

    func didTapPoseLibrary()
    func didTapResetPose()

    func didTapFitView()
    func didTapToggleVisualizations()
}

class JointControlPanel: UIVisualEffectView {

    weak var delegate: JointControlPanelDelegate?

    // UI Elements
    private var jointSelectionButton: UIButton!
    private var axisSegmentedControl: UISegmentedControl!
    private var jointAngleSlider: UISlider!
    private var jointAngleLabel: UILabel!

    init(width: CGFloat) {
        let blurEffect = UIBlurEffect(style: .dark)
        super.init(effect: blurEffect)
        self.frame = CGRect(x: 0, y: 0, width: width, height: 1)
        setupUI(width: width)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI(width: CGFloat) {
        let controlHeight: CGFloat = 180  // Reduced height with fewer buttons
        self.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]

        let padding: CGFloat = 20
        let contentWidth = width - (padding * 2)

        // 1. Header Row: Joint Selection & Reset
        let row1Y: CGFloat = 15

        jointSelectionButton = UIButton(type: .system)
        jointSelectionButton.frame = CGRect(
            x: padding, y: row1Y, width: contentWidth * 0.6, height: 35)
        jointSelectionButton.setTitle("Select Joint...", for: .normal)
        jointSelectionButton.setTitleColor(.white, for: .normal)
        jointSelectionButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        jointSelectionButton.backgroundColor = UIColor.systemTeal.withAlphaComponent(0.8)
        jointSelectionButton.layer.cornerRadius = 8
        jointSelectionButton.addTarget(
            self, action: #selector(jointSelectionTapped), for: .touchUpInside)
        contentView.addSubview(jointSelectionButton)

        let resetJointBtn = createButton(
            title: "Reset Joint",
            x: width - padding - (contentWidth * 0.35),
            y: row1Y,
            width: contentWidth * 0.35,
            height: 35,
            action: #selector(resetJointTapped)
        )
        resetJointBtn.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.8)
        contentView.addSubview(resetJointBtn)

        // 2. Axis Selection Row
        let row2Y = row1Y + 45
        let items = ["X-Axis", "Y-Axis", "Z-Axis"]
        axisSegmentedControl = UISegmentedControl(items: items)
        axisSegmentedControl.frame = CGRect(x: padding, y: row2Y, width: contentWidth, height: 32)
        axisSegmentedControl.selectedSegmentIndex = 0
        axisSegmentedControl.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        axisSegmentedControl.selectedSegmentTintColor = UIColor.systemBlue
        axisSegmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        axisSegmentedControl.setTitleTextAttributes(
            [.foregroundColor: UIColor.white], for: .selected)
        axisSegmentedControl.addTarget(self, action: #selector(axisChanged), for: .valueChanged)
        contentView.addSubview(axisSegmentedControl)

        // 3. Slider Row
        let row3Y = row2Y + 45

        // Decrement Button
        let decBtn = createButton(
            title: "-", x: padding, y: row3Y, width: 40, height: 40,
            action: #selector(decrementTapped))
        decBtn.titleLabel?.font = .boldSystemFont(ofSize: 24)
        contentView.addSubview(decBtn)

        // Increment Button
        let incBtn = createButton(
            title: "+", x: width - padding - 40, y: row3Y, width: 40, height: 40,
            action: #selector(incrementTapped))
        incBtn.titleLabel?.font = .boldSystemFont(ofSize: 24)
        contentView.addSubview(incBtn)

        // Slider
        let sliderX = padding + 50
        let sliderWidth = width - (padding * 2) - 100
        jointAngleSlider = UISlider(
            frame: CGRect(x: sliderX, y: row3Y + 5, width: sliderWidth, height: 30))
        jointAngleSlider.minimumValue = -180
        jointAngleSlider.maximumValue = 180
        jointAngleSlider.value = 0
        jointAngleSlider.tintColor = .systemBlue
        jointAngleSlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        contentView.addSubview(jointAngleSlider)

        // Angle Label (Centered below slider)
        jointAngleLabel = UILabel(frame: CGRect(x: 0, y: row3Y - 15, width: width, height: 20))
        jointAngleLabel.text = "0.0°"
        jointAngleLabel.textColor = .white
        jointAngleLabel.font = .monospacedSystemFont(ofSize: 12, weight: .bold)
        jointAngleLabel.textAlignment = .center
        contentView.addSubview(jointAngleLabel)

        // 4. Bottom Control Row (Pose Library, Reset, Utilities)
        let row4Y = row3Y + 50

        let bottomBtnWidth = (contentWidth - 30) / 4

        let poseLibraryBtn = createButton(
            title: "🎭 Pose Library", x: padding, y: row4Y, width: bottomBtnWidth * 1.5, height: 35,
            action: #selector(poseLibraryTapped))
        poseLibraryBtn.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.8)
        contentView.addSubview(poseLibraryBtn)

        let resetPoseBtn = createButton(
            title: "Reset Pose", x: padding + bottomBtnWidth * 1.5 + 10, y: row4Y,
            width: bottomBtnWidth,
            height: 35, action: #selector(resetPoseTapped))
        resetPoseBtn.backgroundColor = UIColor.systemRed.withAlphaComponent(0.8)
        contentView.addSubview(resetPoseBtn)

        let fitViewBtn = createButton(
            title: "Fit View", x: padding + bottomBtnWidth * 2.5 + 20, y: row4Y,
            width: bottomBtnWidth * 0.9,
            height: 35, action: #selector(fitViewTapped))
        fitViewBtn.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.8)
        contentView.addSubview(fitViewBtn)

        let visualsBtn = createButton(
            title: "Visuals", x: padding + bottomBtnWidth * 3.4 + 30, y: row4Y,
            width: bottomBtnWidth * 0.7, height: 35, action: #selector(toggleVisualsTapped))
        visualsBtn.backgroundColor = UIColor.systemIndigo.withAlphaComponent(0.8)
        contentView.addSubview(visualsBtn)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Determine control height to match setupUI
        let controlHeight: CGFloat = 180

        // Determine available width from current bounds or superview
        let availableWidth: CGFloat
        if let superview = self.superview {
            availableWidth = superview.bounds.width
        } else {
            availableWidth = self.bounds.width
        }

        // Determine screen height from context when possible
        var screenHeight: CGFloat?
        if let window = self.window, let screen = window.windowScene?.screen {
            screenHeight = screen.bounds.height
        }

        // Fallback to our current superview height if screen isn't available yet
        let containerHeight = screenHeight ?? self.superview?.bounds.height ?? self.bounds.height

        // Pin the panel to the bottom using context-derived sizes
        self.frame = CGRect(
            x: 0,
            y: max(0, containerHeight - controlHeight),
            width: availableWidth,
            height: controlHeight
        )
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

    @objc private func poseLibraryTapped() { delegate?.didTapPoseLibrary() }
    @objc private func resetPoseTapped() { delegate?.didTapResetPose() }
    @objc private func fitViewTapped() { delegate?.didTapFitView() }
    @objc private func toggleVisualsTapped() { delegate?.didTapToggleVisualizations() }

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
        return button
    }
}
