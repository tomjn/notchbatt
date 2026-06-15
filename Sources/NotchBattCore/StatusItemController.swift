import AppKit

/// Menu-bar item with Quit and a "Test ring" action. Auto-hides with the menu
/// bar in fullscreen Spaces; that is acceptable since it is only needed to
/// quit or test.
public final class StatusItemController {
    private let item: NSStatusItem
    private let onTest: () -> Void

    public init(onTest: @escaping () -> Void) {
        self.onTest = onTest
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "battery.25", accessibilityDescription: "NotchBatt")
        }
        let menu = NSMenu()
        let test = NSMenuItem(title: "Test ring", action: #selector(testAction), keyEquivalent: "")
        test.target = self
        menu.addItem(test)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit NotchBatt", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
    }

    @objc private func testAction() { onTest() }
}
