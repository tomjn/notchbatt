import AppKit
import NotchBattCore

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let controller = AppController()

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--calibrate") {
            controller.calibrate()
        } else if let sim = AppController.parseSimulate(CommandLine.arguments) {
            controller.simulate(percentage: sim.percentage, isPluggedIn: sim.isPluggedIn)
            if CommandLine.arguments.contains("--simulate-mic") { controller.simulateMic() }
        } else if CommandLine.arguments.contains("--simulate-mic") {
            controller.simulateMic()
        } else {
            controller.start()
        }
    }
}

let delegate = AppDelegate()
app.delegate = delegate
app.run()
