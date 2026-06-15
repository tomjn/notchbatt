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

    func testColorShiftsYellowToRed() {
        let warn = pulseParameters(for: .warn)!
        let urgent = pulseParameters(for: .urgent)!
        let critical = pulseParameters(for: .critical)!

        // All stay fully red in the red channel; the green channel drains away
        // as it escalates: yellow -> orange -> red.
        XCTAssertGreaterThan(warn.color.green, urgent.color.green)
        XCTAssertGreaterThan(urgent.color.green, critical.color.green)
    }
}
