import ServiceManagement

/// Thin wrapper over `SMAppService.mainApp` so the menu can offer an
/// "Open at Login" toggle. Registering adds the app as a login item; the system
/// surfaces it in System Settings -> Login Items. Requires the app to run from a
/// stable location (documented: `/Applications`).
public final class LoginItem {
    public init() {}

    public var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Registers or unregisters the app as a login item. Throws on failure
    /// (e.g. unstable location); callers surface the error rather than crash.
    public func setEnabled(_ on: Bool) throws {
        if on {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
