import AppKit

/// A borderless, transparent, click-through overlay that floats above all
/// apps and Spaces (including fullscreen) and hosts a `RingView`.
public final class RingWindow {
    private var window: NSWindow?
    private let ringView = RingView(frame: .zero)

    public init() {}

    /// Shows the ring for the given parameters, positioning it over the notch.
    /// No-op if there is no notched screen.
    public func show(_ params: PulseParams) {
        guard let screen = notchedScreen(),
              let size = notchSize(of: screen) else { return }

        let rect = notchWindowRect(screenFrame: screen.frame,
                                   notchWidth: size.width,
                                   notchHeight: size.height,
                                   padding: 6)

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
        ringView.apply(params)
        win.orderFrontRegardless()
    }

    /// Hides the ring.
    public func hide() {
        ringView.stop()
        window?.orderOut(nil)
    }
}
