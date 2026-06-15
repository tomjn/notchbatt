# NotchBatt — Design

**Date:** 2026-06-15
**Status:** Approved (brainstorming complete, ready for implementation plan)

## Problem

On battery power, the author repeatedly fails to notice the charge dropping until it's critically low (as low as 2%). macOS's built-in low-battery notifications and Low Power Mode are not attention-grabbing enough to break focus.

## Goal

A persistent, escalating, hard-to-ignore **visual** alarm: a red ring that pulses around the MacBook's notch when running low on battery, getting more urgent as the charge falls, and disappearing the moment the machine is plugged in.

### Success criteria

- When on battery and charge ≤ 10%, a red ring is visible hugging the notch, pulsing.
- Pulse speed / intensity escalates at 5% and again at ≤ 3%.
- Ring is visible regardless of the current Space, including over fullscreen apps and when the menu bar is auto-hidden.
- Ring disappears immediately when the charger is connected (charging state), at any level.
- The app runs at login with no Dock icon; a menu-bar icon provides Quit and a manual ring test.
- The core charge→alert-level mapping is covered by unit tests; the ring visual can be triggered on demand for manual verification without draining the battery.

## Non-goals (v1)

- Sound or system notifications (visual only).
- External-display / clamshell fallback. (Plugged into an external monitor almost always means charging, so the notch-less case effectively can't trigger.)
- User-configurable thresholds via a config file. Thresholds are compile-time constants in v1.
- App Store distribution, code signing, notarization (personal local build).

## User-facing behaviour

### Escalation

| Charge (on battery) | Level      | Ring behaviour                          |
|---------------------|------------|-----------------------------------------|
| > 10%               | none       | hidden                                  |
| ≤ 10% and > 5%      | warn       | slow, calm pulse                        |
| ≤ 5% and > 3%       | urgent     | faster, brighter pulse                  |
| ≤ 3%                | critical   | fastest, most urgent pulse              |
| any, charging       | none       | hidden (charger connected clears it)    |

Exact pulse periods, ring thickness, colour and glow are tuned live during implementation using the simulate affordance. Chosen visual style (from brainstorming): **pulsing ring** with a red glow that breathes between low and high intensity.

### Menu-bar icon

A small battery status item (`NSStatusItem`), separate from the ring. Auto-hides with the menu bar in fullscreen Spaces (acceptable — it's only needed to quit/configure). Menu contents:

- **Test ring** — cycles through warn → urgent → critical previews so the ring can be seen on demand.
- **Quit**

No Dock icon (`NSApplication.setActivationPolicy(.accessory)`).

## Architecture

Swift, built with Swift Package Manager (`swift build`) as a plain executable target. Native AppKit / CoreGraphics / IOKit only — **zero runtime dependencies**. No Xcode project and no `.app` bundle required; the Dock icon is suppressed at runtime via `.accessory` activation policy.

### Components (each independently testable)

1. **`BatteryMonitor`** — wraps the IOKit Power Sources API. Event-driven via `IOPSNotificationCreateRunLoopSource` (no polling loop); reads percentage and charging state with `IOPSCopyPowerSourcesInfo` / `IOPSCopyPowerSourcesList` / `IOPSGetPowerSourceDescription`. Emits `(percentage: Int, isCharging: Bool)` to a callback whenever the power source changes.

2. **`AlertLevel` mapping** — a **pure function** `level(percentage: Int, isCharging: Bool) -> Level` where `Level ∈ {none, warn, urgent, critical}`. Charging always maps to `none`. This is the unit-tested core; it has no dependency on AppKit or IOKit.

3. **`NotchRingWindow`** — a borderless, transparent, click-through `NSWindow` positioned over the built-in display's notch. Critical settings so it shows everywhere:
   - `styleMask = .borderless`, `isOpaque = false`, `backgroundColor = .clear`
   - `ignoresMouseEvents = true`
   - `level = .statusBar` (or higher, e.g. `CGShieldingWindowLevel`) so it floats above app content
   - `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]` so it appears over fullscreen apps and on every Space
   - Hosts a `CALayer` that draws the ring (a stroked path hugging the notch's lower edge and corners) and runs the pulse animation (`CABasicAnimation` on opacity / shadow). Pulse period and glow scale with `Level`.

4. **`NotchGeometry`** — finds the built-in display among `NSScreen.screens` and computes the notch rectangle from `NSScreen.safeAreaInsets` / `auxiliaryTopLeftArea` / `auxiliaryTopRightArea`, so the ring hugs the notch precisely. If no notch is present (no built-in notched display), the ring is simply not shown in v1.

5. **`AppDelegate`** — wires `BatteryMonitor` → `AlertLevel` → `NotchRingWindow`, owns the `NSStatusItem` menu, and handles the `--simulate` flag.

### Dev / test affordances

- `--simulate <pct>` and `--simulate-charging` CLI flags force a charge/charging state at launch so the ring can be seen and tuned without draining the battery.
- The **Test ring** menu item triggers the same preview cycle at runtime.
- Unit tests cover the `AlertLevel` pure function across the threshold boundaries (11/10/6/5/4/3, charging vs not).

## Testing strategy

- **Unit:** `AlertLevel` mapping at every boundary and the charging override.
- **Manual:** `swift run NotchBatt --simulate 4` to visually confirm ring appearance/position/pulse on the real notch; **Test ring** menu item for ongoing checks. Battery hardware integration is not unit-testable; correctness of the IOKit read is verified by observing the ring at real low-battery (or trusting `pmset -g batt` cross-checks during dev).

## Build, install & autostart

- **Source repo:** new GitHub repo, cloned at `~/dev/NotchBatt`.
- **Binary:** `swift build -c release` → installed to `~/.local/bin/notchbatt` (already on `PATH`).
- **Autostart:** a `LaunchAgent` plist (`com.tomjn.notchbatt.plist`, `RunAtLoad` + `KeepAlive`) pointing at the installed binary. This plist is the **only** piece that belongs in the **dotfiles** repo (stows to `~/Library/LaunchAgents/`); the app source stays in its own repo.

## Open items for implementation

- Confirm the exact notch-rect API path on the target macOS version (Darwin 25.x) during the first build.
- Tune pulse periods/colour/thickness live.
- Decide whether **Test ring** auto-clears after the cycle or toggles.
