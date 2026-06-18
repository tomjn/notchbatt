# NotchBatt — battery-percentage readout

## Idea

When the low-battery glow ring is showing, also display the live battery
percentage as text (e.g. `8%`) just off the **left** edge of the notch. The
number's placement makes the notch read like a battery, with the percentage at
the "nub" (terminal) end — without drawing any actual nub shape.

## Behavior

- The percentage appears **only when the ring is shown** — i.e. on battery at
  warn (≤10%), urgent (≤5%), or critical (≤3%). When the ring hides (plugged in
  or above 10%), the text hides too.
- Text uses the **same alert color** and the **same breathing animation** as the
  ring, so the two pulse in lockstep and share a hue at every level.
- Calibration mode (the glow-less diagnostic outline) shows **no text**.

## Rendering

A `CATextLayer` inside `RingView`, alongside the existing fill / glow / stroke
layers. Chosen over an `NSTextField` subview (heavier, separate animation
plumbing) or `drawRect` text (fights the layer-backed design).

- Inherits the alert color via `foregroundColor`, glows via
  `shadowColor` + `shadowRadius`, and breathes by sharing the existing `breathe`
  opacity animation.
- Stays click-through; lives in the same overlay window as the ring.

## Positioning

Computed from values `RingView` already has — `bounds` + `margin`:

- **Right-aligned**, with the text's right edge a few points left of the notch's
  left stroke (`x = margin`), so the gap to the notch stays constant for `9%`
  vs `10%`.
- **Vertically centered** on the notch band: `y = (bounds.height + margin) / 2`.
- Lands inside the existing window's left padding (80pt) — **no window resize**.

## Data flow

The percentage is threaded through the existing show path:

- `AppController.update` already has the percentage → `RingWindow.show(params,
  percentage:)` → `RingView.apply(params, percentage:)`.
- `runTestCycle` supplies a representative percentage per level (warn 8,
  urgent 5, critical 2) so the test cycle exercises the text.
- `calibrate()` hides the text layer.

## Testing

A small pure helper (in the style of `NotchGeometry`) computes the label frame
from `bounds` + `margin`, plus the `"\(pct)%"` formatting. Unit-tested. The
visual breathing/glow is verified by eye via `--simulate`.
