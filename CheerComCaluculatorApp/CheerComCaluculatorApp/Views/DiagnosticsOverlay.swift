import UIKit

class DiagnosticsOverlay: UIView {
    private let textView = UITextView()
    private let closeButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        backgroundColor = UIColor.black.withAlphaComponent(0.8)
        layer.cornerRadius = 12
        clipsToBounds = true

        // Text View
        textView.backgroundColor = .clear
        textView.textColor = .green
        textView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isEditable = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textView)

        // Close Button
        closeButton.setTitle("Close", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        closeButton.layer.cornerRadius = 6
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            closeButton.widthAnchor.constraint(equalToConstant: 60),
            closeButton.heightAnchor.constraint(equalToConstant: 30),

            textView.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 8),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }

    @objc private func didTapClose() {
        self.isHidden = true
    }

    func show() {
        self.isHidden = false
        self.alpha = 1.0
        // Bring to front
        if let superview = self.superview {
            superview.bringSubviewToFront(self)
        }
    }

    func clear() {
        textView.text = ""
    }

    func log(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.textView.text.append(text + "\n")
            // Scroll to bottom
            let range = NSMakeRange(self.textView.text.count - 1, 1)
            self.textView.scrollRangeToVisible(range)
        }
    }
}
