import AppKit

/// Draws a red ring hugging the notch's lower edge and runs a breathing pulse.
/// The path traces down the left side, across the rounded bottom, and up the
/// right side; the top is left open because it sits at the screen edge.
public final class RingView: NSView {
    private let shape = CAShapeLayer()

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(shape)
        shape.fillColor = nil
        shape.strokeColor = NSColor.systemRed.cgColor
        shape.shadowColor = NSColor.systemRed.cgColor
        shape.shadowOpacity = 1.0
        shape.shadowOffset = .zero
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    public override func layout() {
        super.layout()
        rebuildPath()
    }

    private var currentLineWidth: CGFloat = 4
    private var currentGlow: CGFloat = 14

    private func rebuildPath() {
        let inset = currentLineWidth / 2
        let r = bounds.insetBy(dx: inset, dy: inset)
        let radius = min(18, r.width / 2)
        let path = CGMutablePath()
        // Start top-left, go down, round the bottom-left, across, round the
        // bottom-right, up to top-right.
        path.move(to: CGPoint(x: r.minX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.minY + radius))
        path.addQuadCurve(to: CGPoint(x: r.minX + radius, y: r.minY),
                          control: CGPoint(x: r.minX, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX - radius, y: r.minY))
        path.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + radius),
                          control: CGPoint(x: r.maxX, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        shape.path = path
        shape.lineWidth = currentLineWidth
        shape.shadowRadius = currentGlow
    }

    /// Applies a pulse style and (re)starts the breathing animation.
    public func apply(_ params: PulseParams) {
        currentLineWidth = params.lineWidth
        currentGlow = params.glowRadius
        rebuildPath()

        shape.removeAnimation(forKey: "breathe")
        let breathe = CABasicAnimation(keyPath: "opacity")
        breathe.fromValue = params.minOpacity
        breathe.toValue = params.maxOpacity
        breathe.duration = params.period / 2
        breathe.autoreverses = true
        breathe.repeatCount = .infinity
        breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        shape.add(breathe, forKey: "breathe")
    }

    public func stop() {
        shape.removeAnimation(forKey: "breathe")
    }
}
