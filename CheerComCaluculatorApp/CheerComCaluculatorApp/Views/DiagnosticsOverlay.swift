import UIKit

class DiagnosticsOverlay: UIView {

    private let textView: UITextView = {
        let tv = UITextView()
        tv.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        tv.textColor = .green
        tv.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        tv.isEditable = false
        tv.isSelectable = true
        tv.layer.cornerRadius = 10
        tv.layer.borderWidth = 1
        tv.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        tv.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        return tv
    }()

    private let closeButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Close", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = .red
        btn.layer.cornerRadius = 8
        return btn
    }()

    var onClose: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = UIColor.black.withAlphaComponent(0.5)

        addSubview(textView)
        addSubview(closeButton)

        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let padding: CGFloat = 20
        let buttonHeight: CGFloat = 44

        textView.frame = CGRect(
            x: padding,
            y: padding + safeAreaInsets.top,
            width: bounds.width - (padding * 2),
            height: bounds.height - (padding * 3) - safeAreaInsets.top - buttonHeight
        )

        closeButton.frame = CGRect(
            x: bounds.width - padding - 100,
            y: textView.frame.maxY + 10,
            width: 100,
            height: buttonHeight
        )
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
