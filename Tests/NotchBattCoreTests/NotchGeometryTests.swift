import XCTest
import CoreGraphics
@testable import NotchBattCore

final class NotchGeometryTests: XCTestCase {
    func testWindowRectHugsNotchCenteredAtTop() {
        // Screen origin bottom-left; 1512x982 with a 200pt-wide, 32pt-tall notch
        // centered on the screen.
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let rect = notchWindowRect(screenFrame: screen,
                                    notchCenterX: screen.midX,
                                    notchWidth: 200,
                                    notchHeight: 32,
                                    padding: 6)

        // Width = notch + padding on both sides.
        XCTAssertEqual(rect.width, 200 + 12, accuracy: 0.001)
        // Height = notch height + padding (extra below; top is the screen edge).
        XCTAssertEqual(rect.height, 32 + 6, accuracy: 0.001)
        // Horizontally centered on the notch.
        XCTAssertEqual(rect.midX, screen.midX, accuracy: 0.001)
        // Top of the window aligns with the top of the screen.
        XCTAssertEqual(rect.maxY, screen.maxY, accuracy: 0.001)
    }

    func testWindowOriginSnapsToWholePoint() {
        // Real measured case: notch center 755.5, width 185 → an unrounded origin
        // would land on a half-point (623.5) and smear strokes across pixels.
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let rect = notchWindowRect(screenFrame: screen,
                                    notchCenterX: 755.5,
                                    notchWidth: 185,
                                    notchHeight: 32,
                                    padding: 40)

        // Origin is a whole point (here 623.0), so strokes sit on the pixel grid.
        XCTAssertEqual(rect.minX, rect.minX.rounded(), accuracy: 0.001)
        XCTAssertEqual(rect.minX, 623, accuracy: 0.001)
    }
}
