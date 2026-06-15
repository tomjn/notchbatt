# NotchBatt Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A headless macOS background app that pulses an escalating red ring around the notch when on battery and low, clearing the moment the charger is connected.

**Architecture:** Swift Package Manager project with a pure-logic library target (`NotchBattCore`) that is fully unit-testable, plus a thin executable target (`notchbatt`) that hosts the AppKit run loop. Battery state comes from IOKit Power Sources (event-driven, no polling); the ring is a borderless, click-through, all-Spaces overlay `NSWindow` hugging the notch; a menu-bar `NSStatusItem` provides Quit and a manual ring test.

**Tech Stack:** Swift 5.9 tools / Swift toolchain 6.3, AppKit, CoreAnimation, CoreGraphics, IOKit.ps, XCTest.

**Reference spec:** `docs/superpowers/specs/2026-06-15-notchbatt-design.md`

---

## Key facts the executor needs

- **No Xcode project.** Build with `swift build`; test with `swift test`; run with `swift run notchbatt [args]`.
- **Why a library + executable split:** SwiftPM cannot `@testable import` an executable target. All logic lives in `NotchBattCore`; the executable is a 3-line entry point. Tests import `NotchBattCore`.
- **What is unit-testable vs manually verified:** The pure functions (`alertLevel`, `pulseParameters`, `notchWindowRect`) get real XCTest coverage. The IOKit reader, the overlay window, and the status item interact with hardware/the window server and are verified manually via `swift run notchbatt --simulate <pct>` and visual inspection — there is no way to unit-test "is a red ring drawn over the notch." Each such task says exactly what to look for.
- **`isPluggedIn` semantics:** IOKit reports power-source state as "AC Power" vs "Battery Power". We clear the ring whenever state is AC Power (charger connected), regardless of whether the battery is actively charging or held. The field is therefore named `isPluggedIn`, not `isCharging`.
- **Activation policy:** `.accessory` — windows allowed, no Dock icon, menu-bar item allowed.
- **No special permissions:** Reading IOPS and drawing overlay windows need no TCC/accessibility grant.

---

## File structure

```
NotchBatt/
  Package.swift
  .gitignore
  README.md
  Sources/
    NotchBattCore/
      AlertLevel.swift        # pure: alertLevel(), pulseParameters(), PulseParams
      NotchGeometry.swift      # pure: notchWindowRect() + thin NSScreen lookup
      BatteryMonitor.swift     # IOKit reader + event-driven notifications
      RingView.swift           # NSView subclass: draws + animates the ring
      RingWindow.swift         # borderless overlay NSWindow factory + show/hide
      StatusItemController.swift # NSStatusItem menu (Quit, Test ring)
      AppController.swift      # wires monitor -> level -> window; --simulate
    notchbatt/
      main.swift               # entry point: NSApplication + AppController
  Tests/
    NotchBattCoreTests/
      AlertLevelTests.swift
      NotchGeometryTests.swift
  docs/superpowers/...         # spec + this plan
```

The dotfiles repo (separate, at `~/dotfiles`) later gains:
```
Library/LaunchAgents/com.tomjn.notchbatt.plist
```

---

## Task 1: Project skeleton (Package.swift + .gitignore)

**Files:**
- Create: `Package.swift`
- Create: `.gitignore`

- [ ] **Step 1: Create `Package.swift`**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NotchBatt",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "NotchBattCore"),
        .executableTarget(
            name: "notchbatt",
            dependencies: ["NotchBattCore"]
        ),
        .testTarget(
            name: "NotchBattCoreTests",
            dependencies: ["NotchBattCore"]
        ),
    ]
)
```

- [ ] **Step 2: Create `.gitignore`**

```gitignore
.build/
.swiftpm/
*.xcodeproj
DerivedData/
.DS_Store
```

- [ ] **Step 3: Create placeholder sources so the package resolves**

Create `Sources/NotchBattCore/AlertLevel.swift` with a single line so the target is non-empty:

```swift
// NotchBattCore — implemented across the following tasks.
```

Create `Sources/notchbatt/main.swift`:

```swift
// Entry point — implemented in Task 8.
print("notchbatt: not yet implemented")
```

- [ ] **Step 4: Verify the package builds**

Run: `swift build`
Expected: `Build complete!` (no errors).

- [ ] **Step 5: Commit**

```bash
git add Package.swift .gitignore Sources/
git commit -m "Add SwiftPM skeleton for NotchBatt"
```

---

## Task 2: AlertLevel pure function (TDD)

**Files:**
- Modify: `Sources/NotchBattCore/AlertLevel.swift`
- Test: `Tests/NotchBattCoreTests/AlertLevelTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/NotchBattCoreTests/AlertLevelTests.swift`:

```swift
import XCTest
@testable import NotchBattCore

final class AlertLevelTests: XCTestCase {
    func testPluggedInIsAlwaysNone() {
        XCTAssertEqual(alertLevel(percentage: 2, isPluggedIn: true), .none)
        XCTAssertEqual(alertLevel(percentage: 50, isPluggedIn: true), .none)
    }

    func testThresholdsOnBattery() {
        XCTAssertEqual(alertLevel(percentage: 100, isPluggedIn: false), .none)
        XCTAssertEqual(alertLevel(percentage: 11, isPluggedIn: false), .none)
        XCTAssertEqual(alertLevel(percentage: 10, isPluggedIn: false), .warn)
        XCTAssertEqual(alertLevel(percentage: 6, isPluggedIn: false), .warn)
        XCTAssertEqual(alertLevel(percentage: 5, isPluggedIn: false), .urgent)
        XCTAssertEqual(alertLevel(percentage: 4, isPluggedIn: false), .urgent)
        XCTAssertEqual(alertLevel(percentage: 3, isPluggedIn: false), .critical)
        XCTAssertEqual(alertLevel(percentage: 0, isPluggedIn: false), .critical)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AlertLevelTests`
Expected: FAIL — `alertLevel` / `AlertLevel` not defined (compile error).

- [ ] **Step 3: Write minimal implementation**

Replace the contents of `Sources/NotchBattCore/AlertLevel.swift`:

```swift
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter AlertLevelTests`
Expected: PASS (all assertions).

- [ ] **Step 5: Commit**

```bash
git add Sources/NotchBattCore/AlertLevel.swift Tests/NotchBattCoreTests/AlertLevelTests.swift
git commit -m "Add alertLevel threshold mapping with tests"
```

---

## Task 3: Pulse parameters per level (TDD)

Defines how each level looks/moves: pulse period (seconds), line width, and glow radius. Tuning these visually happens in Task 6; this task just locks the data shape and the none-case.

**Files:**
- Modify: `Sources/NotchBattCore/AlertLevel.swift`
- Modify: `Tests/NotchBattCoreTests/AlertLevelTests.swift`

- [ ] **Step 1: Write the failing test**

Append to `Tests/NotchBattCoreTests/AlertLevelTests.swift` (inside the class):

```swift
    func testPulseParametersEscalate() {
        XCTAssertNil(pulseParameters(for: .none))

        let warn = pulseParameters(for: .warn)!
        let urgent = pulseParameters(for: .urgent)!
        let critical = pulseParameters(for: .critical)!

        // Faster (shorter period) as it escalates.
        XCTAssertGreaterThan(warn.period, urgent.period)
        XCTAssertGreaterThan(urgent.period, critical.period)

        // Thicker / brighter as it escalates.
        XCTAssertLessThanOrEqual(warn.lineWidth, critical.lineWidth)
        XCTAssertLessThanOrEqual(warn.glowRadius, critical.glowRadius)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AlertLevelTests`
Expected: FAIL — `pulseParameters` / `PulseParams` not defined.

- [ ] **Step 3: Write minimal implementation**

Append to `Sources/NotchBattCore/AlertLevel.swift`:

```swift
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter AlertLevelTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/NotchBattCore/AlertLevel.swift Tests/NotchBattCoreTests/AlertLevelTests.swift
git commit -m "Add per-level pulse parameters with tests"
```

---

## Task 4: Notch window geometry (TDD for the math)

The pure function computes the overlay window's frame from a screen frame, the notch width/height, and a padding. The NSScreen lookup that feeds it is a thin wrapper verified later.

**Files:**
- Create: `Sources/NotchBattCore/NotchGeometry.swift`
- Test: `Tests/NotchBattCoreTests/NotchGeometryTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/NotchBattCoreTests/NotchGeometryTests.swift`:

```swift
import XCTest
import CoreGraphics
@testable import NotchBattCore

final class NotchGeometryTests: XCTestCase {
    func testWindowRectHugsNotchCenteredAtTop() {
        // Screen origin bottom-left; 1512x982 with a 200pt-wide, 32pt-tall notch.
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let rect = notchWindowRect(screenFrame: screen,
                                    notchWidth: 200,
                                    notchHeight: 32,
                                    padding: 6)

        // Width = notch + padding on both sides.
        XCTAssertEqual(rect.width, 200 + 12, accuracy: 0.001)
        // Height = notch height + padding (extra below; top is the screen edge).
        XCTAssertEqual(rect.height, 32 + 6, accuracy: 0.001)
        // Horizontally centered on the screen.
        XCTAssertEqual(rect.midX, screen.midX, accuracy: 0.001)
        // Top of the window aligns with the top of the screen.
        XCTAssertEqual(rect.maxY, screen.maxY, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter NotchGeometryTests`
Expected: FAIL — `notchWindowRect` not defined.

- [ ] **Step 3: Write minimal implementation**

Create `Sources/NotchBattCore/NotchGeometry.swift`:

```swift
import CoreGraphics
#if canImport(AppKit)
import AppKit
#endif

/// Computes the overlay window frame (global, origin bottom-left) that hugs the
/// notch: centered horizontally, flush with the top screen edge, padded so the
/// ring sits just outside the notch on the sides and below.
public func notchWindowRect(screenFrame: CGRect,
                            notchWidth: CGFloat,
                            notchHeight: CGFloat,
                            padding: CGFloat) -> CGRect {
    let width = notchWidth + padding * 2
    let height = notchHeight + padding
    let x = screenFrame.midX - width / 2
    let y = screenFrame.maxY - height
    return CGRect(x: x, y: y, width: width, height: height)
}

#if canImport(AppKit)
/// The built-in display that has a notch, if any.
public func notchedScreen() -> NSScreen? {
    NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
}

/// Measured notch (width, height) for a screen, derived from the two menu-bar
/// areas flanking the notch. Returns nil if the screen has no notch.
public func notchSize(of screen: NSScreen) -> (width: CGFloat, height: CGFloat)? {
    guard screen.safeAreaInsets.top > 0,
          let left = screen.auxiliaryTopLeftArea,
          let right = screen.auxiliaryTopRightArea else { return nil }
    let width = right.minX - left.maxX
    let height = screen.safeAreaInsets.top
    guard width > 0 else { return nil }
    return (width, height)
}
#endif
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter NotchGeometryTests`
Expected: PASS.

- [ ] **Step 5: Run the full suite**

Run: `swift test`
Expected: PASS (AlertLevel + NotchGeometry).

- [ ] **Step 6: Commit**

```bash
git add Sources/NotchBattCore/NotchGeometry.swift Tests/NotchBattCoreTests/NotchGeometryTests.swift
git commit -m "Add notch window geometry with tests"
```

---

## Task 5: BatteryMonitor (IOKit; manual verification)

Reads charge + power state from IOKit and fires a callback on every power-source change. Not unit-testable (hardware); verified by a temporary debug print.

**Files:**
- Create: `Sources/NotchBattCore/BatteryMonitor.swift`

- [ ] **Step 1: Implement the monitor**

Create `Sources/NotchBattCore/BatteryMonitor.swift`:

```swift
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
```

- [ ] **Step 2: Build to confirm it compiles**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Manual verification via a throwaway snippet**

Temporarily replace `Sources/notchbatt/main.swift` with:

```swift
import NotchBattCore

let monitor = BatteryMonitor()
if let state = monitor.read() {
    print("battery: \(state.percentage)% pluggedIn=\(state.isPluggedIn)")
} else {
    print("no internal battery found")
}
```

Run: `swift run notchbatt`
Then cross-check against the real value:
Run: `pmset -g batt`
Expected: the printed percentage matches `pmset` within ~1%, and `pluggedIn` is `true` when the charger is connected, `false` on battery. Revert `main.swift` to the placeholder afterward (Task 8 rewrites it).

- [ ] **Step 4: Commit**

```bash
git add Sources/NotchBattCore/BatteryMonitor.swift
git commit -m "Add IOKit battery monitor"
```

---

## Task 6: RingView + RingWindow (overlay; visual verification)

The view draws the ring path and runs the breathing animation; the window is the borderless, click-through, all-Spaces overlay. Verified visually with `--simulate` once the AppController exists (Task 7) — for now build-only.

**Files:**
- Create: `Sources/NotchBattCore/RingView.swift`
- Create: `Sources/NotchBattCore/RingWindow.swift`

- [ ] **Step 1: Implement `RingView`**

Create `Sources/NotchBattCore/RingView.swift`:

```swift
import AppKit

/// Draws a red ring hugging the notch's lower edge and runs a breathing pulse.
/// The path traces down the left side, across the rounded bottom, and up the
/// right side; the top is left open because it sits at the screen edge.
public final class RingView: NSView {
    private let shape = CAShapeLayer()

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(shape)
        shape.fillColor = nil
        shape.strokeColor = NSColor.systemRed.cgColor
        shape.shadowColor = NSColor.systemRed.cgColor
        shape.shadowOpacity = 1.0
        shape.shadowOffset = .zero
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    public override func layout() {
        super.layout()
        rebuildPath()
    }

    private var currentLineWidth: CGFloat = 4
    private var currentGlow: CGFloat = 14

    private func rebuildPath() {
        let inset = currentLineWidth / 2
        let r = bounds.insetBy(dx: inset, dy: inset)
        let radius = min(18, r.width / 2)
        let path = CGMutablePath()
        // Start top-left, go down, round the bottom-left, across, round the
        // bottom-right, up to top-right.
        path.move(to: CGPoint(x: r.minX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.minY + radius))
        path.addQuadCurve(to: CGPoint(x: r.minX + radius, y: r.minY),
                          control: CGPoint(x: r.minX, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX - radius, y: r.minY))
        path.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + radius),
                          control: CGPoint(x: r.maxX, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        shape.path = path
        shape.lineWidth = currentLineWidth
        shape.shadowRadius = currentGlow
    }

    /// Applies a pulse style and (re)starts the breathing animation.
    public func apply(_ params: PulseParams) {
        currentLineWidth = params.lineWidth
        currentGlow = params.glowRadius
        rebuildPath()

        shape.removeAnimation(forKey: "breathe")
        let breathe = CABasicAnimation(keyPath: "opacity")
        breathe.fromValue = params.minOpacity
        breathe.toValue = params.maxOpacity
        breathe.duration = params.period / 2
        breathe.autoreverses = true
        breathe.repeatCount = .infinity
        breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        shape.add(breathe, forKey: "breathe")
    }

    public func stop() {
        shape.removeAnimation(forKey: "breathe")
    }
}
```

- [ ] **Step 2: Implement `RingWindow`**

Create `Sources/NotchBattCore/RingWindow.swift`:

```swift
import AppKit

/// A borderless, transparent, click-through overlay that floats above all
/// apps and Spaces (including fullscreen) and hosts a `RingView`.
public final class RingWindow {
    private var window: NSWindow?
    private let ringView = RingView(frame: .zero)

    public init() {}

    /// Shows the ring for the given parameters, positioning it over the notch.
    /// No-op if there is no notched screen.
    public func show(_ params: PulseParams) {
        guard let screen = notchedScreen(),
              let size = notchSize(of: screen) else { return }

        let rect = notchWindowRect(screenFrame: screen.frame,
                                   notchWidth: size.width,
                                   notchHeight: size.height,
                                   padding: 6)

        let win: NSWindow
        if let existing = window {
            win = existing
            win.setFrame(rect, display: true)
        } else {
            win = NSWindow(contentRect: rect, styleMask: .borderless,
                           backing: .buffered, defer: false)
            win.isOpaque = false
            win.backgroundColor = .clear
            win.hasShadow = false
            win.ignoresMouseEvents = true
            win.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            ringView.frame = NSRect(origin: .zero, size: rect.size)
            ringView.autoresizingMask = [.width, .height]
            win.contentView = ringView
            window = win
        }
        ringView.frame = NSRect(origin: .zero, size: rect.size)
        ringView.apply(params)
        win.orderFrontRegardless()
    }

    /// Hides the ring.
    public func hide() {
        ringView.stop()
        window?.orderOut(nil)
    }
}
```

- [ ] **Step 3: Build to confirm it compiles**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 4: Commit**

```bash
git add Sources/NotchBattCore/RingView.swift Sources/NotchBattCore/RingWindow.swift
git commit -m "Add overlay ring view and window"
```

---

## Task 7: AppController + entry point (wire-up, simulate flag, visual verification)

Wires monitor → level → window, parses `--simulate`, and provides the entry point. First point at which the ring is visible.

**Files:**
- Create: `Sources/NotchBattCore/AppController.swift`
- Modify: `Sources/notchbatt/main.swift`

- [ ] **Step 1: Implement `AppController`**

Create `Sources/NotchBattCore/AppController.swift`:

```swift
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
```

- [ ] **Step 2: Implement the entry point**

Replace `Sources/notchbatt/main.swift`:

```swift
import AppKit
import NotchBattCore

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let controller = AppController()

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let sim = AppController.parseSimulate(CommandLine.arguments) {
            controller.simulate(percentage: sim.percentage, isPluggedIn: sim.isPluggedIn)
        } else {
            controller.start()
        }
    }
}

let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

- [ ] **Step 3: Build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 4: Visual verification — the core deliverable**

Run: `swift run notchbatt --simulate 4`
Expected: a red ring appears hugging the notch on the built-in display and pulses (urgent speed). It stays up because simulate doesn't monitor. Confirm:
- The ring traces the notch's lower edge/corners (not a full rectangle across the top).
- It is visible over a fullscreen app and on other Spaces (switch Spaces / enter fullscreen to check the all-Spaces behavior).
- The cursor clicks through it (you can click whatever is behind it).
Then `Ctrl-C` to quit. Try `--simulate 9` (slow warn pulse) and `--simulate 2` (fast critical pulse) to confirm escalation differs visibly. Try `--simulate 4 --simulate-charging` and confirm **no** ring appears.

If geometry is off (ring not hugging the notch), adjust `padding` in `RingWindow.show` and/or the `radius` in `RingView.rebuildPath`, rebuild, and re-check. This is the expected live-tuning step.

- [ ] **Step 5: Commit**

```bash
git add Sources/NotchBattCore/AppController.swift Sources/notchbatt/main.swift
git commit -m "Wire battery monitor to ring window with simulate mode"
```

---

## Task 8: Status-bar menu (Quit + Test ring; visual verification)

Adds the menu-bar icon with Quit and a Test ring action that cycles warn → urgent → critical → off.

**Files:**
- Create: `Sources/NotchBattCore/StatusItemController.swift`
- Modify: `Sources/NotchBattCore/AppController.swift`
- Modify: `Sources/notchbatt/main.swift`

- [ ] **Step 1: Implement `StatusItemController`**

Create `Sources/NotchBattCore/StatusItemController.swift`:

```swift
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
```

- [ ] **Step 2: Add the test-cycle and status item to `AppController`**

In `Sources/NotchBattCore/AppController.swift`, add a stored property and a method, and create the status item in `start()`.

Add properties near the top of the class (after `private var lastLevel`):

```swift
    private var statusItem: StatusItemController?
    private var testTimer: Timer?
```

Add this method inside the class:

```swift
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
```

Replace the body of `start()` to also install the status item:

```swift
    public func start() {
        statusItem = StatusItemController(onTest: { [weak self] in self?.runTestCycle() })
        monitor.onChange = { [weak self] state in
            self?.update(percentage: state.percentage, isPluggedIn: state.isPluggedIn)
        }
        monitor.start()
    }
```

- [ ] **Step 3: Build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 4: Visual verification**

Run: `swift run notchbatt`
Expected: with the machine plugged in (so no real low-battery ring), a battery icon appears in the menu bar. Click it → menu shows **Test ring** and **Quit NotchBatt**. Click **Test ring** → the ring cycles warn (slow) → urgent → critical (fast) → off, ~2s each. Click **Quit** → the app exits and the menu-bar icon disappears.

- [ ] **Step 5: Commit**

```bash
git add Sources/NotchBattCore/StatusItemController.swift Sources/NotchBattCore/AppController.swift
git commit -m "Add menu-bar item with Quit and Test ring"
```

---

## Task 9: README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write `README.md`**

```markdown
# NotchBatt

A tiny headless macOS app that pulses a red ring around the MacBook notch when
the battery is low on battery power, escalating as it drains and clearing the
moment you plug in.

## Build

    swift build -c release

The binary is produced at `.build/release/notchbatt`.

## Run / test the ring without draining the battery

    swift run notchbatt --simulate 4          # urgent ring
    swift run notchbatt --simulate 9          # warn (slow) ring
    swift run notchbatt --simulate 2          # critical (fast) ring
    swift run notchbatt --simulate 4 --simulate-charging   # no ring (plugged in)

When run with no arguments it monitors the battery and adds a menu-bar icon
(Test ring / Quit).

## Thresholds

| Charge (on battery) | Ring                |
|---------------------|---------------------|
| > 10%               | hidden              |
| 6–10%               | slow pulse (warn)   |
| 4–5%                | faster (urgent)     |
| ≤ 3%                | fastest (critical)  |
| plugged in          | hidden              |

## Install & autostart

See `docs/superpowers/specs/2026-06-15-notchbatt-design.md`. The release binary
is installed to `~/.local/bin/notchbatt` and launched at login by a LaunchAgent
(`com.tomjn.notchbatt.plist`) tracked in the dotfiles repo.

## Tests

    swift test
```

- [ ] **Step 2: Run the full test suite once more**

Run: `swift test`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "Add README"
```

---

## Task 10: Release build, install, and LaunchAgent

Builds the release binary, installs it, and adds the autostart LaunchAgent to the **dotfiles** repo (not this repo). The plist needs an absolute path (no `~`).

**Files:**
- Create (in dotfiles repo): `~/dotfiles/Library/LaunchAgents/com.tomjn.notchbatt.plist`

- [ ] **Step 1: Build and install the release binary**

```bash
swift build -c release
cp .build/release/notchbatt ~/.local/bin/notchbatt
```

Verify: `~/.local/bin/notchbatt --simulate 4` shows the ring (then Ctrl-C).

- [ ] **Step 2: Create the LaunchAgent plist in the dotfiles repo**

Create `~/dotfiles/Library/LaunchAgents/com.tomjn.notchbatt.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.tomjn.notchbatt</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/tomjn/.local/bin/notchbatt</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
```

- [ ] **Step 3: Stow and load it**

```bash
cd ~/dotfiles
stow .
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.tomjn.notchbatt.plist
```

Verify it is running:
```bash
launchctl list | grep notchbatt
```
Expected: a line containing `com.tomjn.notchbatt`. The menu-bar icon should appear.

(To reload after a rebuild: `launchctl bootout gui/$(id -u)/com.tomjn.notchbatt` then bootstrap again, or just `kill` the process — `KeepAlive` relaunches it.)

- [ ] **Step 4: Commit the dotfiles change (in the dotfiles repo)**

```bash
git -C ~/dotfiles add Library/LaunchAgents/com.tomjn.notchbatt.plist
git -C ~/dotfiles commit -m "Add NotchBatt LaunchAgent"
```

---

## Task 11: Publish to GitHub

**CHECKPOINT — confirm with the user before running:** repository **name** (default `NotchBatt`) and **visibility** (`--private` vs `--public`). Do not push until confirmed.

- [ ] **Step 1: Create the repo and push (after confirmation)**

```bash
cd ~/dev/NotchBatt
gh repo create NotchBatt --private --source=. --remote=origin --push
```

- [ ] **Step 2: Verify**

Run: `gh repo view --web`
Expected: the repository opens with the spec, plan, sources, and README present.

---

## Self-review (completed by plan author)

- **Spec coverage:** escalating thresholds → Tasks 2–3; event-driven battery read + plugged-in clears → Task 5; all-Spaces/fullscreen click-through overlay hugging the notch → Tasks 4, 6; built-in-notch-only, no-notch = no ring → Task 4 (`notchedScreen`/`notchSize` return nil); headless `.accessory`, menu-bar Quit + Test ring → Tasks 7–8; `--simulate` + unit tests → Tasks 2–4, 7; install to `~/.local/bin` + LaunchAgent in dotfiles → Task 10; new GitHub repo → Task 11. No uncovered spec requirements.
- **Placeholder scan:** none — every code step contains complete code; no "TODO"/"add error handling"/"similar to Task N".
- **Type consistency:** `AlertLevel`, `PulseParams`, `pulseParameters(for:)`, `alertLevel(percentage:isPluggedIn:)`, `BatteryState(percentage:isPluggedIn:)`, `notchWindowRect(screenFrame:notchWidth:notchHeight:padding:)`, `notchedScreen()`, `notchSize(of:)`, `RingView.apply(_:)/stop()`, `RingWindow.show(_:)/hide()`, `AppController.start()/simulate(percentage:isPluggedIn:)/runTestCycle()/parseSimulate(_:)`, `StatusItemController(onTest:)` — names/signatures are consistent across all tasks that reference them.
