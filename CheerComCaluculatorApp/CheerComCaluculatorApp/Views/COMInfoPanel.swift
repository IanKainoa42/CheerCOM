import SceneKit
import UIKit

class COMInfoPanel: UIVisualEffectView {

    private var comLabel: UILabel!
    private var xLabel: UILabel!
    private var yLabel: UILabel!
    private var zLabel: UILabel!
    private var stabilityLabel: UILabel!
    private var marginLabel: UILabel!
    private var feedbackLabel: UILabel!

    init() {
        let blurEffect = UIBlurEffect(style: .dark)
        super.init(effect: blurEffect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        self.frame = CGRect(x: 20, y: 60, width: 220, height: 200)
        self.layer.cornerRadius = 15
        self.layer.masksToBounds = true

        // COM header label
        comLabel = UILabel(frame: CGRect(x: 10, y: 10, width: 200, height: 25))
        comLabel.text = "Center of Mass"
        comLabel.textColor = .white
        comLabel.font = .boldSystemFont(ofSize: 16)
        comLabel.textAlignment = .center
        contentView.addSubview(comLabel)

        // X coordinate label
        xLabel = UILabel(frame: CGRect(x: 10, y: 40, width: 200, height: 20))
        xLabel.text = "X: 0.00 cm"
        xLabel.textColor = .white
        xLabel.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        contentView.addSubview(xLabel)

        // Y coordinate label
        yLabel = UILabel(frame: CGRect(x: 10, y: 65, width: 200, height: 20))
        yLabel.text = "Y: 0.00 cm"
        yLabel.textColor = .white
        yLabel.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        contentView.addSubview(yLabel)

        // Z coordinate label
        zLabel = UILabel(frame: CGRect(x: 10, y: 90, width: 200, height: 20))
        zLabel.text = "Z: 0.00 cm"
        zLabel.textColor = .white
        zLabel.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        contentView.addSubview(zLabel)

        // Divider
        let divider = UIView(frame: CGRect(x: 10, y: 115, width: 200, height: 1))
        divider.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        contentView.addSubview(divider)

        // Stability Label
        stabilityLabel = UILabel(frame: CGRect(x: 10, y: 120, width: 200, height: 25))
        stabilityLabel.text = "Status: Unknown"
        stabilityLabel.textColor = .lightGray
        stabilityLabel.font = .boldSystemFont(ofSize: 14)
        stabilityLabel.textAlignment = .center
        contentView.addSubview(stabilityLabel)

        // Margin Label
        marginLabel = UILabel(frame: CGRect(x: 10, y: 145, width: 200, height: 20))
        marginLabel.text = "Margin: 0.0 cm"
        marginLabel.textColor = .white
        marginLabel.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        marginLabel.textAlignment = .center
        contentView.addSubview(marginLabel)

        // Feedback Label
        feedbackLabel = UILabel(frame: CGRect(x: 10, y: 170, width: 200, height: 20))
        feedbackLabel.text = "Adjust Position"
        feedbackLabel.textColor = .yellow
        feedbackLabel.font = .italicSystemFont(ofSize: 14)
        feedbackLabel.textAlignment = .center
        contentView.addSubview(feedbackLabel)
    }

    func update(com: SCNVector3, isStable: Bool, margin: Float) {
        xLabel.text = String(format: "X: %.2f cm", com.x)
        yLabel.text = String(format: "Y: %.2f cm", com.y)
        zLabel.text = String(format: "Z: %.2f cm", com.z)

        marginLabel.text = String(format: "Margin: %.1f cm", margin)

        if isStable {
            stabilityLabel.text = "Status: Stable"
            stabilityLabel.textColor = .green

            if margin < 10.0 {
                feedbackLabel.text = "Caution: Near Edge"
                feedbackLabel.textColor = .yellow
            } else {
                feedbackLabel.text = "Good Balance"
                feedbackLabel.textColor = .green
            }
        } else {
            stabilityLabel.text = "Status: Unstable"
            stabilityLabel.textColor = .red
            feedbackLabel.text = "Shift Weight Back"
            feedbackLabel.textColor = .red
        }
    }
}
