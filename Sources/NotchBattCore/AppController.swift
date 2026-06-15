import AppKit

/// Owns the battery monitor and the ring window, and translates battery state
/// into ring show/hide. Also supports a `--simulate <pct>` dev mode.
public final class AppController {
    private let monitor = BatteryMonitor()
    private let ring = RingWindow()
    private var lastLevel: AlertLevel = .none

    public init() {}

    /// Starts normal operation: listen to the battery and drive the ring.
    public func start() {
        monitor.onChange = { [weak self] state in
            self?.update(percentage: state.percentage, isPluggedIn: state.isPluggedIn)
        }
        monitor.start()
    }

    /// Dev mode: force a fixed state and render the ring once, no monitoring.
    public func simulate(percentage: Int, isPluggedIn: Bool) {
        update(percentage: percentage, isPluggedIn: isPluggedIn)
    }

    private func update(percentage: Int, isPluggedIn: Bool) {
        let level = alertLevel(percentage: percentage, isPluggedIn: isPluggedIn)
        lastLevel = level
        if let params = pulseParameters(for: level) {
            ring.show(params)
        } else {
            ring.hide()
        }
    }

    /// Parses `--simulate <pct>` and `--simulate-charging` from arguments.
    /// Returns nil if no simulate flag is present.
    public static func parseSimulate(_ args: [String]) -> (percentage: Int, isPluggedIn: Bool)? {
        guard let i = args.firstIndex(of: "--simulate"),
              i + 1 < args.count, let pct = Int(args[i + 1]) else { return nil }
        let charging = args.contains("--simulate-charging")
        return (pct, charging)
    }
}
