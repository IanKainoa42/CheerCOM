import SceneKit
import UIKit

final class COMInfoPanel: CheerGlassPanel {
    private final class MetricTile: UIView {
        private let axisLabel = UILabel()
        private let valueLabel = UILabel()

        init(title: String) {
            super.init(frame: .zero)
            translatesAutoresizingMaskIntoConstraints = false
            backgroundColor = CheerPalette.storm
            layer.cornerCurve = .continuous
            layer.cornerRadius = 12
            layer.borderWidth = 1
            layer.borderColor = CheerPalette.panelBorder.cgColor

            axisLabel.translatesAutoresizingMaskIntoConstraints = false
            axisLabel.text = title
            axisLabel.textColor = CheerPalette.textSecondary
            axisLabel.font = cheerMonospacedFont(size: 10, weight: .bold)

            valueLabel.translatesAutoresizingMaskIntoConstraints = false
            valueLabel.text = "0.00 cm"
            valueLabel.textColor = CheerPalette.textPrimary
            valueLabel.font = cheerMonospacedFont(size: 16, weight: .bold)

            addSubview(axisLabel)
            addSubview(valueLabel)

            NSLayoutConstraint.activate([
                axisLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
                axisLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
                axisLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),

                valueLabel.topAnchor.constraint(equalTo: axisLabel.bottomAnchor, constant: 6),
                valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
                valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
                valueLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

                heightAnchor.constraint(equalToConstant: 74)
            ])
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func setValue(_ value: Float) {
            valueLabel.text = String(format: "%.2f cm", value)
        }
    }

    private let titleLabel = UILabel()
    private let eyebrowLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let statusBadge = PaddingLabel()
    private let coordinatesStack = UIStackView()
    private let xTile = MetricTile(title: "X")
    private let yTile = MetricTile(title: "Y")
    private let zTile = MetricTile(title: "Z")
    private let marginValueLabel = UILabel()
    private let marginCaptionLabel = UILabel()
    private let stabilityLabel = UILabel()
    private let feedbackLabel = UILabel()

    override init(padding: NSDirectionalEdgeInsets = .init(top: 18, leading: 18, bottom: 18, trailing: 18)) {
        super.init(padding: padding)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 214)
    }

    private func setupUI() {
        contentStack.spacing = 12

        eyebrowLabel.text = "[POSE INSPECTOR]"
        eyebrowLabel.textColor = CheerPalette.accentMint
        eyebrowLabel.font = cheerMonospacedFont(size: 10, weight: .bold)

        titleLabel.text = "LIVE TELEMETRY"
        titleLabel.textColor = CheerPalette.textPrimary
        titleLabel.font = cheerRoundedFont(.title3, weight: .bold)

        subtitleLabel.text = "Rig: mixamorig_v1 // Stability: live"
        subtitleLabel.textColor = CheerPalette.textSecondary
        subtitleLabel.font = cheerMonospacedFont(size: 10, weight: .regular)

        let titleStack = UIStackView(arrangedSubviews: [eyebrowLabel, titleLabel, subtitleLabel])
        titleStack.axis = .vertical
        titleStack.spacing = 4

        statusBadge.text = "ACTIVE"
        statusBadge.textColor = CheerPalette.midnight
        statusBadge.font = cheerMonospacedFont(size: 10, weight: .bold)
        statusBadge.backgroundColor = CheerPalette.accentMint

        let headerRow = UIStackView(arrangedSubviews: [titleStack, UIView(), statusBadge])
        headerRow.alignment = .top
        headerRow.spacing = 12
        contentStack.addArrangedSubview(headerRow)

        coordinatesStack.axis = .horizontal
        coordinatesStack.spacing = 10
        coordinatesStack.distribution = .fillEqually
        coordinatesStack.addArrangedSubview(xTile)
        coordinatesStack.addArrangedSubview(yTile)
        coordinatesStack.addArrangedSubview(zTile)
        contentStack.addArrangedSubview(coordinatesStack)

        let summaryCard = UIView()
        summaryCard.translatesAutoresizingMaskIntoConstraints = false
        summaryCard.backgroundColor = CheerPalette.storm
        summaryCard.layer.cornerCurve = .continuous
        summaryCard.layer.cornerRadius = 12
        summaryCard.layer.borderColor = CheerPalette.panelBorder.cgColor
        summaryCard.layer.borderWidth = 1

        let summaryStack = UIStackView()
        summaryStack.translatesAutoresizingMaskIntoConstraints = false
        summaryStack.axis = .vertical
        summaryStack.spacing = 4

        marginCaptionLabel.text = "SUPPORT MARGIN"
        marginCaptionLabel.textColor = CheerPalette.textSecondary
        marginCaptionLabel.font = cheerMonospacedFont(size: 10, weight: .bold)

        marginValueLabel.text = "0.0 cm"
        marginValueLabel.textColor = CheerPalette.textPrimary
        marginValueLabel.font = cheerMonospacedFont(size: 24, weight: .bold)

        stabilityLabel.text = "Unknown"
        stabilityLabel.textColor = CheerPalette.textSecondary
        stabilityLabel.font = cheerRoundedFont(.headline, weight: .semibold)

        feedbackLabel.text = "Adjust position to begin."
        feedbackLabel.textColor = CheerPalette.textSecondary
        feedbackLabel.font = cheerMonospacedFont(size: 10, weight: .medium)
        feedbackLabel.numberOfLines = 2

        summaryStack.addArrangedSubview(marginCaptionLabel)
        summaryStack.addArrangedSubview(marginValueLabel)
        summaryStack.addArrangedSubview(stabilityLabel)
        summaryStack.addArrangedSubview(feedbackLabel)

        summaryCard.addSubview(summaryStack)
        NSLayoutConstraint.activate([
            summaryStack.topAnchor.constraint(equalTo: summaryCard.topAnchor, constant: 16),
            summaryStack.leadingAnchor.constraint(equalTo: summaryCard.leadingAnchor, constant: 16),
            summaryStack.trailingAnchor.constraint(equalTo: summaryCard.trailingAnchor, constant: -16),
            summaryStack.bottomAnchor.constraint(equalTo: summaryCard.bottomAnchor, constant: -16)
        ])
        contentStack.addArrangedSubview(summaryCard)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        coordinatesStack.axis = bounds.width < 290 ? .vertical : .horizontal
    }

    func update(com: SCNVector3, isStable: Bool, margin: Float) {
        xTile.setValue(com.x)
        yTile.setValue(com.y)
        zTile.setValue(com.z)
        marginValueLabel.text = String(format: "%.1f cm", margin)

        if isStable {
            statusBadge.text = "STABLE"
            statusBadge.backgroundColor = CheerPalette.accentMint
            stabilityLabel.text = margin < 10 ? "Stable, but close" : "Stable posture"
            stabilityLabel.textColor = CheerPalette.accentMint
            feedbackLabel.text = margin < 10 ? "Keep micro-adjusting to stay centered." : "Balance window looks healthy."
            feedbackLabel.textColor = CheerPalette.textPrimary
        } else {
            statusBadge.text = "UNSTABLE"
            statusBadge.backgroundColor = CheerPalette.accentRose
            statusBadge.textColor = CheerPalette.textPrimary
            stabilityLabel.text = "Weight shift needed"
            stabilityLabel.textColor = CheerPalette.accentRose
            feedbackLabel.text = "Bring the torso back over the base of support."
            feedbackLabel.textColor = CheerPalette.accentRose
        }

        if isStable {
            statusBadge.textColor = CheerPalette.midnight
        }
    }
}
