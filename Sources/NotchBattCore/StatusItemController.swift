import AppKit

/// Menu-bar item. The glyph tints to the current glow color as the battery
/// escalates (static — it does not pulse, to stay calm and legible). The menu
/// offers an "Open at Login" toggle, a "Test ring" action, and Quit.
///
/// Auto-hides with the menu bar in fullscreen Spaces; acceptable since it is
/// only needed to quit, test, or manage the login item.
public final class StatusItemController: NSObject, NSMenuDelegate {
    private let item: NSStatusItem
    private let onTest: () -> Void
    private let loginItem = LoginItem()
    private let loginMenuItem = NSMenuItem(title: "Open at Login",
                                           action: #selector(toggleLogin),
                                           keyEquivalent: "")

    public init(onTest: @escaping () -> Void) {
        self.onTest = onTest
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        update(for: .none)

        loginMenuItem.target = self

        let test = NSMenuItem(title: "Test ring", action: #selector(testAction), keyEquivalent: "")
        test.target = self

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(loginMenuItem)
        menu.addItem(test)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit NotchBatt",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        item.menu = menu
    }

    /// Sets the menu-bar glyph for a level. Healthy/charging shows a monochrome
    /// template battery that adapts to the menu bar; an active alert shows a
    /// battery tinted to `alertColor(for:)`, rendered non-template so the system
    /// keeps the color instead of re-tinting it.
    public func update(for level: AlertLevel) {
        guard let button = item.button else { return }
        if let color = alertColor(for: level) {
            let tint = NSColor(red: color.red, green: color.green, blue: color.blue, alpha: 1.0)
            let config = NSImage.SymbolConfiguration(paletteColors: [tint])
            let image = NSImage(systemSymbolName: "battery.25", accessibilityDescription: "NotchBatt")?
                .withSymbolConfiguration(config)
            image?.isTemplate = false
            button.image = image
        } else {
            let image = NSImage(systemSymbolName: "battery.100", accessibilityDescription: "NotchBatt")
            image?.isTemplate = true
            button.image = image
        }
    }

    @objc private func testAction() { onTest() }

    @objc private func toggleLogin() {
        do {
            try loginItem.setEnabled(!loginItem.isEnabled)
        } catch {
            NSLog("NotchBatt: failed to toggle login item: \(error.localizedDescription)")
        }
        loginMenuItem.state = loginItem.isEnabled ? .on : .off
    }

    // Refresh the checkmark on open: the login-item state can change out of band
    // (e.g. the user removes it in System Settings).
    public func menuWillOpen(_ menu: NSMenu) {
        loginMenuItem.state = loginItem.isEnabled ? .on : .off
    }
}
