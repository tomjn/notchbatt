import AppKit

/// A borderless, transparent, click-through overlay that floats above all
/// apps and Spaces (including fullscreen) and hosts a `RingView`.
public final class RingWindow {
    private var window: NSWindow?
    private let ringView = RingView(frame: .zero)

    /// What the ring should be displaying right now, or nil when it should be
    /// hidden. Retained so a display change can re-apply it: the window frame is
    /// derived from the notched screen's geometry, so it goes stale whenever the
    /// arrangement changes.
    private var current: (params: PulseParams, percentage: Int)?
    private var screenObserver: NSObjectProtocol?

    /// Empirical edge extensions (points) compensating for the physical notch
    /// cutout hiding part of the ring on the right and bottom edges. The rendered
    /// pixels are symmetric; these are tuned by eye against the display.
    /// 0.5pt = 1px at 2x. Flip a sign to pull that edge inward instead.
    private let rightExtend: CGFloat = 0.5
    private let bottomExtend: CGFloat = 0  // fill covers the bottom gap; no nudge needed
    /// Transparent room reserved around the notch for the glow to fade out
    /// without clipping at the window edge. Must comfortably exceed the largest
    /// glow radius (30, critical) plus the line half-width and shadow offset.
    private let padding: CGFloat = 80

    public init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
            self?.reapply()
        }
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    /// Shows the ring for the given parameters, positioning it over the notch,
    /// with the battery percentage off the notch's left edge. With no notched
    /// screen the ring is hidden rather than left where it was: its frame is in
    /// global coordinates, so a ring outliving its display gets stranded
    /// mid-screen on whichever display remains.
    public func show(_ params: PulseParams, percentage: Int) {
        current = (params, percentage)
        guard let win = preparedWindow() else {
            window?.orderOut(nil)
            return
        }
        ringView.apply(params, percentage: percentage)
        win.orderFrontRegardless()
    }

    /// Re-applies the current ring after the displays change: connect, disconnect,
    /// lid open or close, resolution change.
    ///
    /// This also covers a race on undocking. Pulling one USB-C cable both restores
    /// battery power and reconfigures the displays, but the power-source
    /// notification lands within milliseconds while the built-in panel takes far
    /// longer to wake and republish its geometry. The `show` that follows finds no
    /// notched screen and gives up, and `BatteryMonitor` polls nothing, so without
    /// this the ring stays missing until the charge percentage next changes.
    private func reapply() {
        guard let current else { return }
        show(current.params, percentage: current.percentage)
    }

    /// Dev/diagnostic: shows the static, glow-less calibration outline and
    /// prints the exact computed geometry (including the empirical extension).
    public func showCalibration() {
        if let screen = notchedScreen(), let size = notchSize(of: screen) {
            let rect = notchWindowRect(screenFrame: screen.frame,
                                       notchCenterX: size.centerX,
                                       notchWidth: size.width,
                                       notchHeight: size.height,
                                       padding: padding, rightExtend: rightExtend,
                                   bottomExtend: bottomExtend)
            print("""
            calibrate geometry:
              notch centerX     = \(size.centerX)  width=\(size.width)
              notch edges       = [\(size.centerX - size.width / 2), \(size.centerX + size.width / 2)]
              window rect       = \(rect)
              left/right stroke = [\(rect.minX + padding), \(rect.maxX - padding)]
              bottom stroke y   = \(rect.minY + padding)  (notch bottom = \(screen.frame.maxY - size.height))
              extends           = right \(rightExtend), bottom \(bottomExtend)  scale = \(screen.backingScaleFactor)
            """)
        }
        guard let win = preparedWindow() else { return }
        ringView.calibrate()
        win.orderFrontRegardless()
    }

    /// Creates (or repositions) the overlay window over the notch and returns
    /// it. Returns nil if there is no notched screen.
    private func preparedWindow() -> NSWindow? {
        guard let screen = notchedScreen(),
              let size = notchSize(of: screen) else { return nil }

        let rect = notchWindowRect(screenFrame: screen.frame,
                                   notchCenterX: size.centerX,
                                   notchWidth: size.width,
                                   notchHeight: size.height,
                                   padding: padding, rightExtend: rightExtend,
                                   bottomExtend: bottomExtend)
        ringView.margin = padding

        let win: NSWindow
        if let existing = window {
            win = existing
            win.setFrame(rect, display: true)
        } else {
            win = NSWindow(contentRect: rect, styleMask: .borderless,
                           backing: .buffered, defer: false)
            win.isOpaque = false
            win.backgroundColor = .clear
            win.hasShadow = false
            win.ignoresMouseEvents = true
            win.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            ringView.frame = NSRect(origin: .zero, size: rect.size)
            ringView.autoresizingMask = [.width, .height]
            win.contentView = ringView
            window = win
        }
        ringView.frame = NSRect(origin: .zero, size: rect.size)
        return win
    }

    /// Hides the ring.
    public func hide() {
        current = nil
        ringView.stop()
        window?.orderOut(nil)
    }
}
