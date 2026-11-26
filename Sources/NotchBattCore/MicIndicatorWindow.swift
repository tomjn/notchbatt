import AppKit

/// A small click-through overlay just off the notch's right edge that shows an
/// orange laptop with a mic on its screen while the built-in microphone is in
/// use. Lives on the same
/// level and Spaces as the battery ring, independent of it.
public final class MicIndicatorWindow {
    private var window: NSWindow?
    private let imageView = NSImageView(frame: .zero)
    private var isShown = false
    private var screenObserver: NSObjectProtocol?

    /// The window hugs the icon.
    private var size: CGSize { imageView.image?.size ?? .zero }
    /// Matches the battery percentage's gap off the notch's left edge.
    private let gap: CGFloat = 6

    public init() {
        imageView.image = Self.laptopMicImage()
        imageView.imageScaling = .scaleNone

        // The frame is derived from the notched screen, so it goes stale when the
        // display arrangement changes. Same handling as `RingWindow`.
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
            guard let self, self.isShown else { return }
            self.show()
        }
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    /// Shows the indicator beside the notch. With no notched screen it hides
    /// instead, so it is never stranded mid-screen on an external display.
    public func show() {
        isShown = true
        guard let win = preparedWindow() else {
            window?.orderOut(nil)
            return
        }
        win.orderFrontRegardless()
    }

    public func hide() {
        isShown = false
        window?.orderOut(nil)
    }

    /// An orange laptop with a black mic on its screen, so it reads as "the
    /// laptop's mic" rather than echoing the system's orange mic-in-use dot. No
    /// SF Symbol combines the two, so it is drawn from `laptopcomputer` and
    /// `mic.fill`. The mic sits at 58% of the height, the middle of the screen.
    private static func laptopMicImage() -> NSImage? {
        let laptopConfig = NSImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
            .applying(.init(paletteColors: [.systemOrange]))
        let micConfig = NSImage.SymbolConfiguration(pointSize: 7, weight: .semibold)
            .applying(.init(paletteColors: [.black]))
        guard let laptop = NSImage(systemSymbolName: "laptopcomputer", accessibilityDescription: nil)?
                .withSymbolConfiguration(laptopConfig),
              let mic = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(micConfig) else { return nil }
        let image = NSImage(size: laptop.size, flipped: false) { rect in
            laptop.draw(in: rect)
            mic.draw(in: NSRect(x: rect.midX - mic.size.width / 2,
                                y: rect.height * 0.58 - mic.size.height / 2,
                                width: mic.size.width, height: mic.size.height))
            return true
        }
        image.accessibilityDescription = "Built-in microphone in use"
        return image
    }

    private func preparedWindow() -> NSWindow? {
        guard let screen = notchedScreen(),
              let notch = notchSize(of: screen) else { return nil }
        let rect = micIndicatorFrame(screenTop: screen.frame.maxY,
                                     notchRightX: notch.centerX + notch.width / 2,
                                     notchHeight: notch.height,
                                     size: size, gap: gap)
        if let window {
            window.setFrame(rect, display: true)
            return window
        }
        let win = NSWindow(contentRect: rect, styleMask: .borderless,
                           backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.ignoresMouseEvents = true
        win.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        imageView.autoresizingMask = [.width, .height]
        win.contentView = imageView
        window = win
        return win
    }
}
