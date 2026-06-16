# NotchBatt — Menu-Bar App & Release CI

**Date:** 2026-06-16
**Status:** Approved design, pending implementation plan

## Goal

Convert NotchBatt from a bare CLI executable + hand-installed LaunchAgent into a
proper menu-bar `.app` bundle that is:

- **Spotlight-launchable** and double-clickable (a real app, not a daemon).
- **Self-managing its login item** via an "Open at Login" menu toggle.
- Showing a **menu-bar icon tinted to the current glow color** (yellow → orange
  → red as the battery escalates; neutral when healthy or charging).

Plus a **GitHub Actions workflow** that builds and attaches an unsigned `.app`
archive to each tagged release.

## Constraints

- **No Apple Developer account, no code signing / notarization.** Builds are
  unsigned (ad-hoc signed only). The app is primarily for the author; others may
  use it but must clear Gatekeeper manually.
- Keep the existing Swift package, tests, and the pure/AppKit-free split in
  `NotchBattCore`.
- macOS 13+ (already the package floor).

## Design

### 1. Packaging: SwiftPM + bundle-assembly script

The Swift package is unchanged (`NotchBattCore`, `notchbatt` executable, tests).
We do **not** convert to an Xcode project.

Add:

- `Resources/Info.plist` — bundle template.
- `scripts/make-app.sh` — assembles the bundle:
  1. `swift build -c release`
  2. Create `NotchBatt.app/Contents/` with:
     - `MacOS/notchbatt` (the built release binary)
     - `Info.plist`
     - `Resources/` (app icon, if added)
  3. Ad-hoc sign: `codesign -s - --force --deep NotchBatt.app` so it launches
     locally without a "damaged / cannot be opened" Gatekeeper error.

`Info.plist` keys:

| Key | Value |
| --- | --- |
| `CFBundleIdentifier` | `com.tomjn.notchbatt` |
| `CFBundleName` | `NotchBatt` |
| `CFBundleExecutable` | `notchbatt` |
| `CFBundleShortVersionString` | injected from the git tag (e.g. `1.2.0`) |
| `CFBundleVersion` | injected from the git tag |
| `LSUIElement` | `true` (menu-bar accessory, no Dock icon) |
| `LSMinimumSystemVersion` | `13.0` |
| `NSHumanReadableCopyright` | author/year |

`LSUIElement=true` is the canonical way to make this an accessory app and
supersedes the runtime `NSApp.setActivationPolicy(.accessory)` call (the runtime
call may remain harmlessly).

### 2. Launch-at-login via `SMAppService`

New thin wrapper type (in `NotchBattCore`):

```
final class LoginItem {
    var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    func setEnabled(_ on: Bool) throws  // register() / unregister()
}
```

- The menu gains an **"Open at Login"** item with a checkmark bound to
  `isEnabled`. Toggling calls `setEnabled`, catching and surfacing errors
  (e.g. a brief alert or logged message) rather than crashing.
- Works for an unsigned app for local use. Requires the app to run from a stable
  location — documented as `/Applications`.

### 3. Color-reactive menu-bar icon

- Factor the level → color mapping out of `pulseParameters(for:)` into a small
  shared function (e.g. `alertColor(for: AlertLevel) -> PulseColor?`) so the ring
  **and** the icon use one source of truth.
- `StatusItemController` gains `update(for level: AlertLevel)`:
  - `.none` → monochrome **template** SF Symbol (adapts to light/dark menu bar).
  - `.warn / .urgent / .critical` → battery SF Symbol rendered **non-template**,
    tinted to `alertColor(for:)` via `NSImage.SymbolConfiguration`.
  - Static tint — the menu-bar icon does **not** pulse (kept calm and legible).
- `AppController.update(percentage:isPluggedIn:)` already computes the level; it
  calls `statusItem.update(for: level)` alongside `ring.show/hide`.
- Menu contents: **Open at Login** (toggle) · **Test ring** (kept) · separator ·
  **Quit NotchBatt**.

### 4. Lifecycle & dev modes

- Default launch (double-click / Spotlight / login) → `controller.start()`:
  battery monitoring + persistent menu-bar icon.
- `--simulate <pct>` and `--calibrate` continue to work on the inner binary
  (`NotchBatt.app/Contents/MacOS/notchbatt --calibrate`) for development.
- `mise` tasks: `build`, `test`, `simulate`, `calibrate` stay. The
  `install`/`start`/`stop`/`restart`/`reinstall` launchctl tasks are replaced by
  a `make-app` task (build the bundle) and opening the app.

### 5. Release CI — `.github/workflows/release.yml`

- **Trigger:** push tag matching `v*`.
- **Runner:** `macos-14`.
- **Steps:**
  1. `actions/checkout`
  2. `swift test`
  3. `scripts/make-app.sh` with version from `${GITHUB_REF_NAME}`
  4. `ditto -c -k --keepParent NotchBatt.app NotchBatt.zip`
  5. Attach `NotchBatt.zip` to the GitHub Release (e.g. `softprops/action-gh-release`).
- **No secrets** — unsigned/ad-hoc build.
- Release notes include the Gatekeeper-bypass instructions (right-click → Open, or
  `xattr -dr com.apple.quarantine /Applications/NotchBatt.app`).

### 6. Migration off the old LaunchAgent

Documented one-time cleanup (README + first release notes), to avoid a
double-launch with the legacy install:

```sh
launchctl bootout gui/$(id -u)/com.tomjn.notchbatt
rm ~/Library/LaunchAgents/com.tomjn.notchbatt.plist
rm ~/.local/bin/notchbatt
# then: move NotchBatt.app to /Applications, open it, enable "Open at Login"
```

*Optional / deferred:* on first run the app detects the stale LaunchAgent plist
and offers to remove it. Not in the initial scope.

### 7. Testing

- Existing pure-logic tests (`AlertLevel`, `NotchGeometry`) stay.
- `alertColor(for:)` becomes a small pure function with a unit test asserting each
  level maps to the expected color, shared by ring and icon.
- `LoginItem` (SMAppService) and the NSImage tinting are thin side-effecting
  wrappers — kept minimal, not unit-tested.

## Risks & Notes

- Unsigned `SMAppService` login items appear in **System Settings → Login Items**
  (expected) and can be flaky when the app runs from outside `/Applications`
  (documented).
- The README's install section and the auto-memory note (`notchbatt-install.md`)
  must be updated to the new `.app` model once this lands.
- App icon (Finder/Spotlight) is optional for v1; the menu-bar glyph is the
  primary surface.

## Out of Scope

- Code signing, notarization, Sparkle auto-update.
- Homebrew cask / public distribution channel.
- Battery percentage shown in the menu-bar icon.
