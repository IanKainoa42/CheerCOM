import UIKit

protocol SkillTimelineViewDelegate: AnyObject {
    func timelineView(_ view: SkillTimelineView, didTapKeyframeAt index: Int)
    func timelineView(_ view: SkillTimelineView, didMoveKeyframeAt index: Int, toFrame frame: Int)
    func timelineView(_ view: SkillTimelineView, didScrubToFrame frame: Int)
}

final class SkillTimelineView: UIView {

    weak var delegate: SkillTimelineViewDelegate?

    var numFrames: Int = 25 { didSet { setNeedsLayout() } }
    var keyframes: [Int] = [] { didSet { setNeedsLayout() } }
    var currentFrame: Int = 0 { didSet { updatePlayhead() } }

    private let trackView = UIView()
    private let playheadView = UIView()
    private var keyframeMarkers: [UIView] = []
    private var draggingIndex: Int? = nil

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        layer.cornerRadius = 12

        trackView.backgroundColor = UIColor(white: 0.25, alpha: 1.0)
        trackView.layer.cornerRadius = 4
        addSubview(trackView)

        playheadView.backgroundColor = .systemRed
        playheadView.layer.cornerRadius = 2
        addSubview(playheadView)

        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
        addGestureRecognizer(pan)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let pad: CGFloat = 16
        let trackHeight: CGFloat = 6
        let trackY = bounds.midY - trackHeight / 2
        trackView.frame = CGRect(x: pad, y: trackY, width: bounds.width - 2 * pad, height: trackHeight)

        layoutKeyframeMarkers()
        updatePlayhead()
    }

    private func layoutKeyframeMarkers() {
        while keyframeMarkers.count < keyframes.count {
            let marker = DiamondView()
            addSubview(marker)
            keyframeMarkers.append(marker)
        }
        while keyframeMarkers.count > keyframes.count {
            keyframeMarkers.removeLast().removeFromSuperview()
        }

        for (i, frame) in keyframes.enumerated() {
            let x = xForFrame(frame)
            let marker = keyframeMarkers[i]
            marker.frame = CGRect(x: x - 10, y: bounds.midY - 10, width: 20, height: 20)
            marker.setNeedsDisplay()
        }
    }

    private func updatePlayhead() {
        let x = xForFrame(currentFrame)
        playheadView.frame = CGRect(x: x - 1, y: 12, width: 2, height: bounds.height - 24)
    }

    private func xForFrame(_ frame: Int) -> CGFloat {
        let pad: CGFloat = 16
        let usableWidth = bounds.width - 2 * pad
        let ratio = numFrames > 0 ? CGFloat(frame) / CGFloat(max(1, numFrames - 1)) : 0
        return pad + usableWidth * ratio
    }

    private func frameForX(_ x: CGFloat) -> Int {
        let pad: CGFloat = 16
        let usableWidth = bounds.width - 2 * pad
        let clamped = max(pad, min(bounds.width - pad, x))
        let ratio = (clamped - pad) / usableWidth
        return Int((ratio * CGFloat(max(1, numFrames - 1))).rounded())
    }

    // MARK: - Gestures

    @objc private func tapped(_ gr: UITapGestureRecognizer) {
        let location = gr.location(in: self)
        if let index = keyframeMarkers.firstIndex(where: { $0.frame.insetBy(dx: -8, dy: -8).contains(location) }) {
            delegate?.timelineView(self, didTapKeyframeAt: index)
        } else {
            let frame = frameForX(location.x)
            delegate?.timelineView(self, didScrubToFrame: frame)
        }
    }

    @objc private func panned(_ gr: UIPanGestureRecognizer) {
        let location = gr.location(in: self)
        switch gr.state {
        case .began:
            if let index = keyframeMarkers.firstIndex(where: { $0.frame.insetBy(dx: -8, dy: -8).contains(location) }) {
                draggingIndex = index
            }
        case .changed:
            guard let index = draggingIndex else { return }
            let frame = frameForX(location.x)
            delegate?.timelineView(self, didMoveKeyframeAt: index, toFrame: frame)
        case .ended, .cancelled:
            draggingIndex = nil
        default:
            break
        }
    }
}

/// Small diamond-shaped keyframe marker rendered with a path layer.
private final class DiamondView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.setFillColor(UIColor.systemYellow.cgColor)
        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(1.5)

        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.close()

        ctx.addPath(path.cgPath)
        ctx.drawPath(using: .fillStroke)
    }
}
