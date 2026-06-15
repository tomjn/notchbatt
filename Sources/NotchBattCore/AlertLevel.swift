public enum AlertLevel: Equatable {
    case none
    case warn
    case urgent
    case critical
}

/// Maps current charge + power state to an alert level.
/// Plugged in (AC power) always clears the alert.
public func alertLevel(percentage: Int, isPluggedIn: Bool) -> AlertLevel {
    if isPluggedIn { return .none }
    switch percentage {
    case ...3:   return .critical
    case 4...5:  return .urgent
    case 6...10: return .warn
    default:     return .none
    }
}

import CoreGraphics

/// An RGB color (0...1 components), kept AppKit-free so the pure logic stays
/// platform-independent and testable. The view turns it into an NSColor.
public struct PulseColor: Equatable {
    public let red: CGFloat
    public let green: CGFloat
    public let blue: CGFloat
}

public struct PulseParams: Equatable {
    public let period: Double      // seconds for one breathe cycle
    public let lineWidth: CGFloat
    public let glowRadius: CGFloat // shadow blur radius
    public let minOpacity: Float
    public let maxOpacity: Float
    public let color: PulseColor
}

/// Returns the ring animation parameters for a level, or nil if the ring is hidden.
/// The hue shifts yellow -> orange -> red as the battery escalates.
public func pulseParameters(for level: AlertLevel) -> PulseParams? {
    switch level {
    case .none:
        return nil
    case .warn:
        return PulseParams(period: 1.8, lineWidth: 6, glowRadius: 18,
                           minOpacity: 0.35, maxOpacity: 0.9,
                           color: PulseColor(red: 1.0, green: 0.8, blue: 0.0))
    case .urgent:
        return PulseParams(period: 1.1, lineWidth: 8, glowRadius: 24,
                           minOpacity: 0.45, maxOpacity: 1.0,
                           color: PulseColor(red: 1.0, green: 0.5, blue: 0.0))
    case .critical:
        return PulseParams(period: 0.65, lineWidth: 10, glowRadius: 30,
                           minOpacity: 0.55, maxOpacity: 1.0,
                           color: PulseColor(red: 1.0, green: 0.15, blue: 0.1))
    }
}
