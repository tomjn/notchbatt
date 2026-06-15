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
