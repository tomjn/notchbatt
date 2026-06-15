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

public struct PulseParams: Equatable {
    public let period: Double      // seconds for one breathe cycle
    public let lineWidth: CGFloat
    public let glowRadius: CGFloat // shadow blur radius
    public let minOpacity: Float
    public let maxOpacity: Float
}

/// Returns the ring animation parameters for a level, or nil if the ring is hidden.
public func pulseParameters(for level: AlertLevel) -> PulseParams? {
    switch level {
    case .none:
        return nil
    case .warn:
        return PulseParams(period: 1.8, lineWidth: 3, glowRadius: 10,
                           minOpacity: 0.35, maxOpacity: 0.9)
    case .urgent:
        return PulseParams(period: 1.1, lineWidth: 4, glowRadius: 16,
                           minOpacity: 0.45, maxOpacity: 1.0)
    case .critical:
        return PulseParams(period: 0.65, lineWidth: 5, glowRadius: 22,
                           minOpacity: 0.55, maxOpacity: 1.0)
    }
}
