import CoreGraphics
#if canImport(AppKit)
import AppKit
#endif

/// Computes the overlay window frame (global, origin bottom-left) that hugs the
/// notch: centered horizontally, flush with the top screen edge, padded so the
/// ring sits just outside the notch on the sides and below.
public func notchWindowRect(screenFrame: CGRect,
                            notchWidth: CGFloat,
                            notchHeight: CGFloat,
                            padding: CGFloat) -> CGRect {
    let width = notchWidth + padding * 2
    let height = notchHeight + padding
    let x = screenFrame.midX - width / 2
    let y = screenFrame.maxY - height
    return CGRect(x: x, y: y, width: width, height: height)
}

#if canImport(AppKit)
/// The built-in display that has a notch, if any.
public func notchedScreen() -> NSScreen? {
    NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
}

/// Measured notch (width, height) for a screen, derived from the two menu-bar
/// areas flanking the notch. Returns nil if the screen has no notch.
public func notchSize(of screen: NSScreen) -> (width: CGFloat, height: CGFloat)? {
    guard screen.safeAreaInsets.top > 0,
          let left = screen.auxiliaryTopLeftArea,
          let right = screen.auxiliaryTopRightArea else { return nil }
    let width = right.minX - left.maxX
    let height = screen.safeAreaInsets.top
    guard width > 0 else { return nil }
    return (width, height)
}
#endif
