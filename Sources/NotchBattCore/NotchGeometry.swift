import CoreGraphics
#if canImport(AppKit)
import AppKit
#endif

/// Computes the overlay window frame (global, origin bottom-left) that hugs the
/// notch: centered on the notch's measured center, flush with the top screen
/// edge, padded so the ring sits just outside the notch on the sides and below.
///
/// `notchCenterX` is the midpoint between the inner edges of the two menu-bar
/// areas — the standard way notch overlays locate the cutout (prior art anchors
/// to these edges, not `screenFrame.midX`). The origin is rounded to a whole
/// point so the ring's strokes land on the pixel grid and render crisply; on a
/// Retina display a half-point origin smears every 1pt line across two columns.
///
/// `rightExtend` widens the window on the right edge only (left edge stays put),
/// moving the right stroke outward. `bottomExtend` grows the window downward
/// (the top stays pinned to the screen edge), moving the bottom stroke down out
/// of the notch. The framebuffer is symmetric, so these exist purely to
/// compensate for the physical notch cutout occluding the visible ring on the
/// right and bottom edges — both are tuned by eye against the display.
public func notchWindowRect(screenFrame: CGRect,
                            notchCenterX: CGFloat,
                            notchWidth: CGFloat,
                            notchHeight: CGFloat,
                            padding: CGFloat,
                            rightExtend: CGFloat = 0,
                            bottomExtend: CGFloat = 0) -> CGRect {
    let baseWidth = notchWidth + padding * 2
    let height = notchHeight + padding + bottomExtend
    let x = (notchCenterX - baseWidth / 2).rounded()
    let y = screenFrame.maxY - height
    return CGRect(x: x, y: y, width: baseWidth + rightExtend, height: height)
}

#if canImport(AppKit)
/// The built-in display that has a notch, if any.
public func notchedScreen() -> NSScreen? {
    NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
}

/// Measured notch geometry for a screen, derived from the two menu-bar areas
/// flanking the notch: horizontal center, width, and height. Returns nil if the
/// screen has no notch.
public func notchSize(of screen: NSScreen) -> (centerX: CGFloat, width: CGFloat, height: CGFloat)? {
    guard screen.safeAreaInsets.top > 0,
          let left = screen.auxiliaryTopLeftArea,
          let right = screen.auxiliaryTopRightArea else { return nil }
    let width = right.minX - left.maxX
    let centerX = (left.maxX + right.minX) / 2
    let height = screen.safeAreaInsets.top
    guard width > 0 else { return nil }
    return (centerX, width, height)
}
#endif
