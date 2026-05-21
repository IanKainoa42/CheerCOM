import SceneKit
import UIKit

class DiagnosticsOverlay: UIView {
    private let panel = CheerGlassPanel(padding: .init(top: 20, leading: 20, bottom: 20, trailing: 20))
    private let textView = UITextView()
    private let closeButton = CheerButton(title: "Close", symbol: "xmark", style: .danger)

    var onClose: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = CheerPalette.midnight.withAlphaComponent(0.42)
        addSubview(panel)
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)

        let titleLabel = UILabel()
        titleLabel.text = "Diagnostics"
        titleLabel.textColor = CheerPalette.textPrimary
        titleLabel.font = cheerRoundedFont(.title3, weight: .bold)

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Validation logs stream here in real time."
        subtitleLabel.textColor = CheerPalette.textSecondary
        subtitleLabel.font = cheerRoundedFont(.subheadline, weight: .regular)

        let titleStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        titleStack.axis = .vertical
        titleStack.spacing = 2

        let headerRow = UIStackView(arrangedSubviews: [titleStack, UIView(), closeButton])
        headerRow.axis = .horizontal
        headerRow.alignment = .center
        headerRow.spacing = 12

        textView.backgroundColor = UIColor.black.withAlphaComponent(0.32)
        textView.textColor = CheerPalette.accentMint
        textView.font = cheerMonospacedFont(size: 12, weight: .regular)
        textView.isEditable = false
        textView.isSelectable = true
        textView.layer.cornerRadius = 18
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        panel.contentStack.addArrangedSubview(headerRow)
        panel.contentStack.addArrangedSubview(textView)
        textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true

        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 20),
            panel.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -20),
            panel.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 20),
            panel.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    @objc private func didTapClose() {
        removeFromSuperview()
        onClose?()
    }

    func log(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let newText = (self.textView.text ?? "") + message + "\n"
            self.textView.text = newText

            // Auto scroll to bottom
            if newText.count > 0 {
                let range = NSRange(location: newText.count - 1, length: 1)
                self.textView.scrollRangeToVisible(range)
            }
        }
    }

    func clear() {
        DispatchQueue.main.async { [weak self] in
            self?.textView.text = ""
        }
    }
}

final class ValidationOverlayPanel: CheerGlassPanel {
    private let metricsLabel = UILabel()

    init() {
        super.init(padding: .init(top: 14, leading: 14, bottom: 14, trailing: 14))
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentStack.spacing = 6

        let titleLabel = UILabel()
        titleLabel.text = "Validation Metrics"
        titleLabel.textColor = CheerPalette.textPrimary
        titleLabel.font = cheerRoundedFont(.headline, weight: .bold)
        contentStack.addArrangedSubview(titleLabel)

        metricsLabel.textColor = CheerPalette.textSecondary
        metricsLabel.font = cheerMonospacedFont(size: 11, weight: .regular)
        metricsLabel.numberOfLines = 0
        metricsLabel.text = "Waiting for diagnostics..."

        let scrollView = UIScrollView()
        scrollView.heightAnchor.constraint(equalToConstant: 120).isActive = true
        scrollView.addSubview(metricsLabel)
        metricsLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            metricsLabel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            metricsLabel.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            metricsLabel.topAnchor.constraint(equalTo: scrollView.topAnchor),
            metricsLabel.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            metricsLabel.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        contentStack.addArrangedSubview(scrollView)
    }

    /// Updates the overlay with detailed validation metrics, satisfying the PR requirement
    /// for a debug tool that outputs segment masses, individual COM points, and the final CoM.
    func updateMetrics(result: CalculationResult) {
        let com = result.totalCOM
        var metricsText = "=== REAL-TIME VALIDATION METRICS ===\n"
        metricsText += String(format: "TOTAL CoM: [X: %.3f, Y: %.3f, Z: %.3f]\n", com.x, com.y, com.z)
        metricsText += String(format: "TOTAL MASS: %.2f kg\n", result.segmentCOMs.map { $0.mass }.reduce(0, +))
        metricsText += "------------------------------------\n"
        metricsText += "INDIVIDUAL SEGMENT DATA:\n"

        // Format segments nicely into columns for the debug overlay
        for segment in result.segmentCOMs {
            let paddedName = segment.name.padding(toLength: 15, withPad: " ", startingAt: 0)
            metricsText += String(
                format: "• %@ | Mass: %5.2fkg | CoM: (%.1f, %.1f, %.1f)\n",
                paddedName, segment.mass, segment.position.x, segment.position.y, segment.position.z
            )
        }

        metricsText += "====================================\n"
        metricsLabel.text = metricsText
    }
}
