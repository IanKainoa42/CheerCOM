import UIKit

enum CheerPalette {
    static let midnight = UIColor(hex: 0x07111F)
    static let nightfall = UIColor(hex: 0x10233D)
    static let storm = UIColor(hex: 0x17314A)
    static let frostedInk = UIColor(hex: 0x0C1827, alpha: 0.72)
    static let panelBorder = UIColor.white.withAlphaComponent(0.14)
    static let panelShadow = UIColor.black.withAlphaComponent(0.28)

    static let accentBlue = UIColor(hex: 0x56C2FF)
    static let accentTeal = UIColor(hex: 0x4FE0C2)
    static let accentAmber = UIColor(hex: 0xFFC85C)
    static let accentRose = UIColor(hex: 0xFF7E79)
    static let accentMint = UIColor(hex: 0x7EF3AF)

    static let textPrimary = UIColor(hex: 0xF6FAFF)
    static let textSecondary = UIColor(hex: 0xA9BCD0)
}

extension UIColor {
    convenience init(hex: Int, alpha: CGFloat = 1.0) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255.0
        let green = CGFloat((hex >> 8) & 0xFF) / 255.0
        let blue = CGFloat(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

func cheerRoundedFont(_ textStyle: UIFont.TextStyle, weight: UIFont.Weight = .semibold) -> UIFont {
    let baseFont = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: textStyle).pointSize, weight: weight)
    guard let descriptor = baseFont.fontDescriptor.withDesign(.rounded) else {
        return baseFont
    }
    return UIFont(descriptor: descriptor, size: 0)
}

func cheerMonospacedFont(size: CGFloat, weight: UIFont.Weight = .semibold) -> UIFont {
    UIFont.monospacedSystemFont(ofSize: size, weight: weight)
}

final class PaddingLabel: UILabel {
    var contentInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInsets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + contentInsets.left + contentInsets.right,
            height: size.height + contentInsets.top + contentInsets.bottom
        )
    }
}

enum CheerButtonStyle {
    case accent
    case neutral
    case secondary
    case danger
    case positive
}

final class CheerButton: UIButton {
    private let style: CheerButtonStyle
    private let compact: Bool
    private let symbolName: String?

    init(title: String, symbol: String? = nil, style: CheerButtonStyle = .neutral, compact: Bool = false) {
        self.style = style
        self.compact = compact
        self.symbolName = symbol
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setTitle(title, for: .normal)
        applyStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setTitle(_ title: String?, for state: UIControl.State) {
        super.setTitle(title, for: state)
        if configuration != nil {
            applyStyle()
        }
    }

    override var isHighlighted: Bool {
        didSet {
            applyStyle()
            transform = isHighlighted ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
        }
    }

    private func applyStyle() {
        var configuration = UIButton.Configuration.filled()
        configuration.cornerStyle = .capsule
        configuration.image = symbolName.flatMap { UIImage(systemName: $0) }
        configuration.imagePadding = 8
        configuration.imagePlacement = .leading
        configuration.baseForegroundColor = CheerPalette.textPrimary
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: compact ? 9 : 12,
            leading: compact ? 12 : 15,
            bottom: compact ? 9 : 12,
            trailing: compact ? 12 : 15
        )
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = cheerRoundedFont(self.compact ? .callout : .headline, weight: .semibold)
            return outgoing
        }

        switch style {
        case .accent:
            configuration.baseBackgroundColor = isHighlighted
                ? CheerPalette.accentBlue.withAlphaComponent(0.72)
                : CheerPalette.accentBlue.withAlphaComponent(0.88)
        case .neutral:
            configuration.baseBackgroundColor = isHighlighted
                ? UIColor.white.withAlphaComponent(0.14)
                : UIColor.white.withAlphaComponent(0.18)
        case .secondary:
            configuration.baseBackgroundColor = isHighlighted
                ? CheerPalette.storm.withAlphaComponent(0.78)
                : CheerPalette.storm.withAlphaComponent(0.9)
        case .danger:
            configuration.baseBackgroundColor = isHighlighted
                ? CheerPalette.accentRose.withAlphaComponent(0.68)
                : CheerPalette.accentRose.withAlphaComponent(0.82)
        case .positive:
            configuration.baseBackgroundColor = isHighlighted
                ? CheerPalette.accentMint.withAlphaComponent(0.62)
                : CheerPalette.accentMint.withAlphaComponent(0.76)
            configuration.baseForegroundColor = CheerPalette.midnight
        }

        self.configuration = configuration
        layer.shadowColor = CheerPalette.panelShadow.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 8)
    }
}

class CheerGlassPanel: UIVisualEffectView {
    let contentStack = UIStackView()

    init(padding: NSDirectionalEdgeInsets = .init(top: 18, leading: 18, bottom: 18, trailing: 18)) {
        super.init(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        translatesAutoresizingMaskIntoConstraints = false

        contentView.clipsToBounds = true
        contentView.layer.cornerCurve = .continuous
        contentView.layer.cornerRadius = 28
        contentView.backgroundColor = CheerPalette.frostedInk
        contentView.layer.borderColor = CheerPalette.panelBorder.cgColor
        contentView.layer.borderWidth = 1

        layer.shadowColor = CheerPalette.panelShadow.cgColor
        layer.shadowOpacity = 0.32
        layer.shadowRadius = 30
        layer.shadowOffset = CGSize(width: 0, height: 18)

        contentView.directionalLayoutMargins = padding
        contentView.preservesSuperviewLayoutMargins = false

        contentStack.axis = .vertical
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class CheerGradientBackdropView: UIView {
    private let glowViews = [UIView(), UIView(), UIView()]

    override class var layerClass: AnyClass {
        CAGradientLayer.self
    }

    private var gradientLayer: CAGradientLayer {
        layer as! CAGradientLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false
        configureGradient()
        configureGlows()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureGradient() {
        gradientLayer.colors = [
            CheerPalette.midnight.cgColor,
            CheerPalette.nightfall.cgColor,
            CheerPalette.storm.cgColor
        ]
        gradientLayer.locations = [0.0, 0.5, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.15, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.85, y: 1.0)
    }

    private func configureGlows() {
        let colors = [
            CheerPalette.accentBlue.withAlphaComponent(0.34),
            CheerPalette.accentTeal.withAlphaComponent(0.22),
            CheerPalette.accentRose.withAlphaComponent(0.18)
        ]

        for (index, glowView) in glowViews.enumerated() {
            glowView.backgroundColor = colors[index]
            glowView.layer.cornerCurve = .continuous
            glowView.layer.cornerRadius = 120
            glowView.alpha = 1
            glowView.isUserInteractionEnabled = false
            addSubview(glowView)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let dimensions = [
            CGRect(x: bounds.width * 0.62, y: bounds.height * 0.08, width: 240, height: 240),
            CGRect(x: -40, y: bounds.height * 0.18, width: 220, height: 220),
            CGRect(x: bounds.width * 0.2, y: bounds.height * 0.72, width: 280, height: 280)
        ]

        for (index, glowView) in glowViews.enumerated() {
            glowView.frame = dimensions[index].intersection(bounds.insetBy(dx: -80, dy: -80))
            glowView.layer.cornerRadius = glowView.bounds.height / 2
            glowView.layer.shadowColor = glowView.backgroundColor?.cgColor
            glowView.layer.shadowOpacity = 0.95
            glowView.layer.shadowRadius = 70
            glowView.layer.shadowOffset = .zero
        }
    }
}

func makeCheerSegmentedControl(items: [String]) -> UISegmentedControl {
    let control = UISegmentedControl(items: items)
    control.translatesAutoresizingMaskIntoConstraints = false
    control.selectedSegmentIndex = 0
    control.backgroundColor = UIColor.white.withAlphaComponent(0.08)
    control.selectedSegmentTintColor = CheerPalette.accentBlue.withAlphaComponent(0.36)
    control.layer.cornerRadius = 14
    control.layer.borderWidth = 1
    control.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
    control.setTitleTextAttributes(
        [
            .foregroundColor: CheerPalette.textSecondary,
            .font: cheerRoundedFont(.subheadline, weight: .semibold)
        ],
        for: .normal
    )
    control.setTitleTextAttributes(
        [
            .foregroundColor: CheerPalette.textPrimary,
            .font: cheerRoundedFont(.subheadline, weight: .bold)
        ],
        for: .selected
    )
    return control
}

func makeCheerDivider() -> UIView {
    let divider = UIView()
    divider.translatesAutoresizingMaskIntoConstraints = false
    divider.backgroundColor = UIColor.white.withAlphaComponent(0.08)
    divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
    return divider
}
