import UIKit

enum CheerPalette {
    static let midnight = UIColor(hex: 0x060606)
    static let nightfall = UIColor(hex: 0x0A0A0A)
    static let storm = UIColor(hex: 0x141414)
    static let frostedInk = UIColor(hex: 0x0C0C0C, alpha: 0.96)
    static let panelBorder = UIColor(hex: 0x2F2F2F)
    static let panelShadow = UIColor.black.withAlphaComponent(0.0)

    static let accentBlue = UIColor(hex: 0x00FF88)
    static let accentTeal = UIColor(hex: 0x00D978)
    static let accentAmber = UIColor(hex: 0xFF8800)
    static let accentRose = UIColor(hex: 0xFF5E5E)
    static let accentMint = UIColor(hex: 0x00FF88)

    static let textPrimary = UIColor.white
    static let textSecondary = UIColor(hex: 0x8A8A8A)
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
    UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: textStyle).pointSize, weight: weight)
}

func cheerMonospacedFont(size: CGFloat, weight: UIFont.Weight = .semibold) -> UIFont {
    UIFont.monospacedSystemFont(ofSize: size, weight: weight)
}

final class PaddingLabel: UILabel {
    var contentInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)

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
        configuration.cornerStyle = .fixed
        configuration.background.cornerRadius = compact ? 8 : 10
        configuration.image = symbolName.flatMap { UIImage(systemName: $0) }
        configuration.imagePadding = 8
        configuration.imagePlacement = .leading
        configuration.baseForegroundColor = CheerPalette.textPrimary
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: compact ? 8 : 10,
            leading: compact ? 10 : 12,
            bottom: compact ? 8 : 10,
            trailing: compact ? 10 : 12
        )
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = cheerMonospacedFont(size: self.compact ? 11 : 12, weight: .bold)
            outgoing.kern = 0.4
            return outgoing
        }

        switch style {
        case .accent:
            configuration.baseBackgroundColor = isHighlighted ? CheerPalette.accentBlue.withAlphaComponent(0.88) : CheerPalette.accentBlue
            configuration.baseForegroundColor = CheerPalette.midnight
            configuration.background.strokeColor = CheerPalette.accentBlue
            configuration.background.strokeWidth = 1
        case .neutral:
            configuration.baseBackgroundColor = isHighlighted ? CheerPalette.storm : CheerPalette.nightfall
            configuration.background.strokeColor = CheerPalette.panelBorder
            configuration.background.strokeWidth = 1
        case .secondary:
            configuration.baseBackgroundColor = isHighlighted ? UIColor.black : CheerPalette.storm
            configuration.background.strokeColor = CheerPalette.panelBorder
            configuration.background.strokeWidth = 1
        case .danger:
            configuration.baseBackgroundColor = CheerPalette.nightfall
            configuration.baseForegroundColor = CheerPalette.accentRose
            configuration.background.strokeColor = CheerPalette.accentRose.withAlphaComponent(0.45)
            configuration.background.strokeWidth = 1
        case .positive:
            configuration.baseBackgroundColor = isHighlighted ? CheerPalette.accentMint.withAlphaComponent(0.2) : CheerPalette.storm
            configuration.baseForegroundColor = CheerPalette.accentMint
            configuration.background.strokeColor = CheerPalette.accentMint.withAlphaComponent(0.55)
            configuration.background.strokeWidth = 1
        }

        self.configuration = configuration
        layer.shadowOpacity = 0
    }
}

class CheerGlassPanel: UIVisualEffectView {
    let contentStack = UIStackView()

    init(padding: NSDirectionalEdgeInsets = .init(top: 18, leading: 18, bottom: 18, trailing: 18)) {
        super.init(effect: nil)
        translatesAutoresizingMaskIntoConstraints = false

        contentView.clipsToBounds = true
        contentView.layer.cornerCurve = .continuous
        contentView.layer.cornerRadius = 14
        contentView.backgroundColor = CheerPalette.frostedInk
        contentView.layer.borderColor = CheerPalette.panelBorder.cgColor
        contentView.layer.borderWidth = 1
        contentView.layer.shadowOpacity = 0

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
            UIColor(hex: 0x101010).cgColor
        ]
        gradientLayer.locations = [0.0, 0.55, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.2, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.8, y: 1.0)
    }

    private func configureGlows() {
        let colors = [
            CheerPalette.accentBlue.withAlphaComponent(0.08),
            CheerPalette.accentTeal.withAlphaComponent(0.05),
            CheerPalette.accentAmber.withAlphaComponent(0.04)
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
            CGRect(x: bounds.width * 0.68, y: bounds.height * 0.12, width: 220, height: 220),
            CGRect(x: -60, y: bounds.height * 0.24, width: 180, height: 180),
            CGRect(x: bounds.width * 0.14, y: bounds.height * 0.76, width: 220, height: 220)
        ]

        for (index, glowView) in glowViews.enumerated() {
            glowView.frame = dimensions[index].intersection(bounds.insetBy(dx: -80, dy: -80))
            glowView.layer.cornerRadius = glowView.bounds.height / 2
            glowView.layer.shadowColor = glowView.backgroundColor?.cgColor
            glowView.layer.shadowOpacity = 0.35
            glowView.layer.shadowRadius = 48
            glowView.layer.shadowOffset = .zero
        }
    }
}

func makeCheerSegmentedControl(items: [String]) -> UISegmentedControl {
    let control = UISegmentedControl(items: items)
    control.translatesAutoresizingMaskIntoConstraints = false
    control.selectedSegmentIndex = 0
    control.backgroundColor = CheerPalette.nightfall
    control.selectedSegmentTintColor = CheerPalette.accentMint.withAlphaComponent(0.14)
    control.layer.cornerRadius = 10
    control.layer.borderWidth = 1
    control.layer.borderColor = CheerPalette.panelBorder.cgColor
    control.setTitleTextAttributes(
        [
            .foregroundColor: CheerPalette.textSecondary,
            .font: cheerMonospacedFont(size: 11, weight: .bold),
            .kern: 0.4
        ],
        for: .normal
    )
    control.setTitleTextAttributes(
        [
            .foregroundColor: CheerPalette.accentMint,
            .font: cheerMonospacedFont(size: 11, weight: .bold),
            .kern: 0.4
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
