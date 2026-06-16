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
that tints to the current glow color as the battery escalates (yellow → orange
→ red; monochrome when healthy or charging). Its menu has **Open at Login**,
**Test ring**, and **Quit**.

## Thresholds

| Charge (on battery) | Ring                |
|---------------------|---------------------|
| > 10%               | hidden              |
| 6–10%               | slow pulse (warn)   |
| 4–5%                | faster (urgent)     |
| ≤ 3%                | fastest (critical)  |
| plugged in          | hidden              |

## Install as a menu-bar app

Build the `.app` bundle (ad-hoc signed, unsigned — no Developer account):

    mise run make-app          # or: scripts/make-app.sh

This produces `NotchBatt.app`. Move it to `/Applications`, open it, and enable
**Open at Login** from its menu. Login-at-startup uses `SMAppService`, which
needs the app to live in a stable location — `/Applications` is recommended.

Releases also ship a prebuilt `NotchBatt.zip` (see GitHub Releases). Because the
build is unsigned, clear Gatekeeper after downloading:

- Right-click the app → **Open**, then confirm, or
- `xattr -dr com.apple.quarantine /Applications/NotchBatt.app`

### Migrating from the old LaunchAgent install

Earlier versions installed a CLI binary to `~/.local/bin/notchbatt` launched by a
LaunchAgent. Remove it once, to avoid a double-launch with the new app:

    launchctl bootout gui/$(id -u)/com.tomjn.notchbatt
    rm ~/Library/LaunchAgents/com.tomjn.notchbatt.plist
    rm ~/.local/bin/notchbatt

Then move `NotchBatt.app` to `/Applications`, open it, and enable **Open at Login**.

## Tests

    swift test

## License

NotchBatt is released under the [MIT License](LICENSE).

The placeholder app icon is the "battery-warning" glyph from
[Lucide](https://lucide.dev), also under the MIT License.
