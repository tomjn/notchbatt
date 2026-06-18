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
    /// Opaque black fill of the ring interior, drawn behind everything. The
    /// notch outline can't be traced pixel-perfectly (its corner radius and
    /// edges don't match ours exactly), which leaves slivers of wallpaper
    /// peeking through at the inner radii. Filling the interior black merges
    /// those slivers into the notch, so robustness no longer depends on exact
    /// geometry. It does not breathe — only the colored ring/glow pulses.
    private let fillLayer = CAShapeLayer()
    private let shape = CAShapeLayer()
    /// Extra glow passes drawn behind the crisp stroke; their shadows stack to
    /// intensify the bloom (Core Animation has no additive blend to lean on).
    private let glowLayers = [CAShapeLayer(), CAShapeLayer()]
    private var allLayers: [CAShapeLayer] { glowLayers + [shape] }

    /// The battery percentage readout, sitting just off the notch's left edge so
    /// its placement makes the notch read like a battery (number at the terminal
    /// end). Shares the ring's color and breathing pulse; hidden when no ring.
    private let percentLayer = CATextLayer()
    private let labelWidth: CGFloat = 44
    private let labelHeight: CGFloat = 20
    private let labelGap: CGFloat = 6
    private let labelFontSize: CGFloat = 14

    /// Transparent room reserved around the notch outline for the glow.
    public var margin: CGFloat = 40
    private let cornerRadius: CGFloat = 10

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(fillLayer)  // backmost, under the glow and stroke
        fillLayer.fillColor = NSColor.black.cgColor
        fillLayer.strokeColor = nil
        for glow in allLayers {
            layer?.addSublayer(glow)
            glow.fillColor = nil
            glow.shadowOpacity = 1.0
            glow.shadowOffset = CGSize(width: 0, height: 4)  // nudge the glow upward
            // The path is open at the top; round the stroke ends so the glow
            // doesn't bloom into square corners where the verticals terminate.
            glow.lineCap = .round
        }
        // Frontmost, above the stroke. Right-aligned so the gap to the notch
        // stays fixed as the digit count changes; glows via its own shadow.
        layer?.addSublayer(percentLayer)
        percentLayer.alignmentMode = .right
        percentLayer.font = NSFont.systemFont(ofSize: 0, weight: .semibold)
        percentLayer.fontSize = labelFontSize
        percentLayer.shadowOpacity = 1.0
        percentLayer.shadowOffset = .zero
        percentLayer.isHidden = true
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    public override func layout() {
        super.layout()
        rebuildPath()
    }

    /// Manually-added sublayers default to `contentsScale = 1.0` and do not
    /// inherit the window's Retina scale, so a 1pt stroke would rasterize at 1x
    /// and be scaled up blurrily. Track the backing scale so the path renders at
    /// native resolution.
    public override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        let scale = window?.backingScaleFactor ?? 2
        for layer in allLayers + [fillLayer, percentLayer] {
            layer.contentsScale = scale
        }
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
        // The fill auto-closes across the open top edge, painting the notch
        // interior (and any inner-radius slivers) solid.
        fillLayer.path = path
        for glow in allLayers {
            glow.path = path
            glow.lineWidth = currentLineWidth
            glow.shadowRadius = currentGlow
        }
        percentLayer.frame = percentageLabelFrame(bounds: bounds, margin: margin,
                                                  width: labelWidth,
                                                  height: labelHeight,
                                                  gap: labelGap)
    }

    /// Applies a pulse style and (re)starts the breathing animation, and shows
    /// the battery percentage off the notch's left edge in the same color.
    public func apply(_ params: PulseParams, percentage: Int) {
        currentLineWidth = params.lineWidth
        currentGlow = params.glowRadius
        fillLayer.isHidden = false
        let color = NSColor(red: params.color.red, green: params.color.green,
                            blue: params.color.blue, alpha: 1.0).cgColor
        for glow in allLayers {
            glow.strokeColor = color
            glow.shadowColor = color
        }
        percentLayer.isHidden = false
        percentLayer.string = percentageLabelText(percentage)
        percentLayer.foregroundColor = color
        percentLayer.shadowColor = color
        percentLayer.shadowRadius = currentGlow * 0.4  // softer than the ring
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
        percentLayer.removeAnimation(forKey: "breathe")
        percentLayer.add(breathe, forKey: "breathe")
    }

    /// Dev/diagnostic render: a static, glow-less 1px outline so the ring's
    /// placement and size can be measured against the notch without breathing
    /// or glow bloom obscuring the bright core.
    public func calibrate() {
        currentLineWidth = 1
        currentGlow = 0
        fillLayer.isHidden = true
        percentLayer.removeAnimation(forKey: "breathe")
        percentLayer.isHidden = true
        for glow in glowLayers {
            glow.removeAnimation(forKey: "breathe")
            glow.isHidden = true
        }
        shape.removeAnimation(forKey: "breathe")
        shape.isHidden = false
        shape.opacity = 1
        shape.shadowOpacity = 0
        shape.strokeColor = NSColor.systemRed.cgColor
        rebuildPath()
    }

    public func stop() {
        for glow in allLayers {
            glow.removeAnimation(forKey: "breathe")
        }
        percentLayer.removeAnimation(forKey: "breathe")
    }
}
