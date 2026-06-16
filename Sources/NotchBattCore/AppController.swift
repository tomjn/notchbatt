import AppKit

/// Owns the battery monitor and the ring window, and translates battery state
/// into ring show/hide. Also supports a `--simulate <pct>` dev mode.
public final class AppController {
    private let monitor = BatteryMonitor()
    private let ring = RingWindow()
    private var lastLevel: AlertLevel = .none
    private var statusItem: StatusItemController?
    private var testTimer: Timer?

    public init() {}

    /// Starts normal operation: listen to the battery and drive the ring.
    public func start() {
        statusItem = StatusItemController(onTest: { [weak self] in self?.runTestCycle() })
        monitor.onChange = { [weak self] state in
            self?.update(percentage: state.percentage, isPluggedIn: state.isPluggedIn)
        }
        monitor.start()
    }

    /// Cycles the ring through warn → urgent → critical → off for visual testing.
    public func runTestCycle() {
        testTimer?.invalidate()
        let sequence: [AlertLevel] = [.warn, .urgent, .critical, .none]
        var index = 0
        func showNext() {
            let level = sequence[index]
            if let params = pulseParameters(for: level) { ring.show(params) }
            else { ring.hide() }
            index += 1
            if index < sequence.count {
                testTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in showNext() }
            }
        }
        showNext()
    }

    /// Dev mode: force a fixed state and render the ring once, no monitoring.
    public func simulate(percentage: Int, isPluggedIn: Bool) {
        update(percentage: percentage, isPluggedIn: isPluggedIn)
    }

    /// Dev mode: render the static, glow-less calibration outline for measuring
    /// the ring's placement against the notch. No monitoring. `RingWindow` prints
    /// the exact computed geometry.
    public func calibrate() {
        ring.showCalibration()
    }

    private func update(percentage: Int, isPluggedIn: Bool) {
        let level = alertLevel(percentage: percentage, isPluggedIn: isPluggedIn)
        lastLevel = level
        statusItem?.update(for: level)
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
