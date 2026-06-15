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
