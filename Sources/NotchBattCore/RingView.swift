import AppKit

/// Draws a colored ring hugging the notch's lower edge and runs a breathing
/// pulse. The path traces down the left side, across the rounded bottom, and up
/// the right side; the top is left open because it sits at the screen edge.
///
/// The path is inset from the view bounds by `margin` on the left, right, and
/// bottom so it lands exactly on the notch boundary, while leaving `margin` of
/// transparent room on every side for the glow to render without being clipped
/// by the window. `margin` must match the padding the window is sized with.
public final class RingView: NSView {
    private let shape = CAShapeLayer()
    /// Extra glow passes drawn behind the crisp stroke; their shadows stack to
    /// intensify the bloom (Core Animation has no additive blend to lean on).
    private let glowLayers = [CAShapeLayer(), CAShapeLayer()]
    private var allLayers: [CAShapeLayer] { glowLayers + [shape] }

    /// Transparent room reserved around the notch outline for the glow.
    public var margin: CGFloat = 40
    private let cornerRadius: CGFloat = 10

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        for glow in allLayers {
            layer?.addSublayer(glow)
            glow.fillColor = nil
            glow.shadowOpacity = 1.0
            glow.shadowOffset = CGSize(width: 0, height: 4)  // nudge the glow upward
        }
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    public override func layout() {
        super.layout()
        rebuildPath()
    }

    private var currentLineWidth: CGFloat = 4
    private var currentGlow: CGFloat = 14

    private func rebuildPath() {
        let left = margin
        let right = bounds.width - margin
        let bottom = margin
        let top = bounds.height
        guard right > left else { return }
        let radius = min(cornerRadius, (right - left) / 2)
        let path = CGMutablePath()
        // Start top-left, go down, round the bottom-left, across, round the
        // bottom-right, up to top-right.
        path.move(to: CGPoint(x: left, y: top))
        path.addLine(to: CGPoint(x: left, y: bottom + radius))
        path.addQuadCurve(to: CGPoint(x: left + radius, y: bottom),
                          control: CGPoint(x: left, y: bottom))
        path.addLine(to: CGPoint(x: right - radius, y: bottom))
        path.addQuadCurve(to: CGPoint(x: right, y: bottom + radius),
                          control: CGPoint(x: right, y: bottom))
        path.addLine(to: CGPoint(x: right, y: top))
        for glow in allLayers {
            glow.path = path
            glow.lineWidth = currentLineWidth
            glow.shadowRadius = currentGlow
        }
    }

    /// Applies a pulse style and (re)starts the breathing animation.
    public func apply(_ params: PulseParams) {
        currentLineWidth = params.lineWidth
        currentGlow = params.glowRadius
        let color = NSColor(red: params.color.red, green: params.color.green,
                            blue: params.color.blue, alpha: 1.0).cgColor
        for glow in allLayers {
            glow.strokeColor = color
            glow.shadowColor = color
        }
        rebuildPath()

        let breathe = CABasicAnimation(keyPath: "opacity")
        breathe.fromValue = params.minOpacity
        breathe.toValue = params.maxOpacity
        breathe.duration = params.period / 2
        breathe.autoreverses = true
        breathe.repeatCount = .infinity
        breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        for glow in allLayers {
            glow.removeAnimation(forKey: "breathe")
            glow.add(breathe, forKey: "breathe")
        }
    }

    public func stop() {
        for glow in allLayers {
            glow.removeAnimation(forKey: "breathe")
        }
    }
}
