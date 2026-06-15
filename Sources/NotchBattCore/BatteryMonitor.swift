import Foundation
import IOKit.ps

public struct BatteryState: Equatable {
    public let percentage: Int
    public let isPluggedIn: Bool
}

/// Event-driven battery reader. Reads the internal battery via IOKit Power
/// Sources and invokes `onChange` whenever the power source changes. No polling.
public final class BatteryMonitor {
    private var runLoopSource: CFRunLoopSource?
    public var onChange: ((BatteryState) -> Void)?

    public init() {}

    /// Reads the current internal-battery state, or nil if none is found.
    public func read() -> BatteryState? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue()
                as? [CFTypeRef] else { return nil }

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?
                .takeUnretainedValue() as? [String: Any] else { continue }
            guard desc[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }

            let current = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maxCap = desc[kIOPSMaxCapacityKey] as? Int ?? 100
            let pct = maxCap > 0 ? Int((Double(current) / Double(maxCap) * 100).rounded()) : current
            let isPluggedIn = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            return BatteryState(percentage: pct, isPluggedIn: isPluggedIn)
        }
        return nil
    }

    /// Starts listening for power-source changes on the main run loop and fires
    /// an initial reading immediately.
    public func start() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx = ctx else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(ctx).takeUnretainedValue()
            if let state = monitor.read() { monitor.onChange?(state) }
        }, context).takeRetainedValue()

        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)

        if let state = read() { onChange?(state) }
    }

    public func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = nil
        }
    }
}
