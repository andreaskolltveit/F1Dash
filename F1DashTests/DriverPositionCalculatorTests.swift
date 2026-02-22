import XCTest
@testable import F1Dash

final class DriverPositionCalculatorTests: XCTestCase {

    // MARK: - Position Ratio

    func testPositionRatioAllActive() {
        let sectors: [[SegmentStatus]] = [
            [.green, .green, .green, .green],
            [.amber, .amber, .amber, .amber],
            [.purple, .purple, .none, .none]
        ]
        let ratio = DriverPositionCalculator.positionRatio(sectors: sectors)
        XCTAssertNotNil(ratio)
        // Last active is index 9 (sector 2, seg 1), total 12
        XCTAssertEqual(ratio!, 10.0 / 12.0, accuracy: 0.01)
    }

    func testPositionRatioNoneActive() {
        let sectors: [[SegmentStatus]] = [
            [.none, .none],
            [.none, .none]
        ]
        let ratio = DriverPositionCalculator.positionRatio(sectors: sectors)
        XCTAssertNil(ratio, "No active segments should return nil")
    }

    func testPositionRatioEmpty() {
        let ratio = DriverPositionCalculator.positionRatio(sectors: [])
        XCTAssertNil(ratio)
    }

    func testPositionRatioFullLap() {
        let sectors: [[SegmentStatus]] = [
            [.green, .green, .green],
            [.amber, .amber, .amber],
            [.purple, .purple, .purple]
        ]
        let ratio = DriverPositionCalculator.positionRatio(sectors: sectors)
        XCTAssertEqual(ratio!, 1.0, accuracy: 0.01, "Full lap should be ratio 1.0")
    }

    // MARK: - Point on Track

    func testPointOnTrackStart() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0), CGPoint(x: 100, y: 100)]
        let point = DriverPositionCalculator.pointOnTrack(ratio: 0.0, trackPoints: points)
        XCTAssertEqual(point, CGPoint(x: 0, y: 0))
    }

    func testPointOnTrackEnd() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0), CGPoint(x: 100, y: 100)]
        let point = DriverPositionCalculator.pointOnTrack(ratio: 1.0, trackPoints: points)
        XCTAssertEqual(point, CGPoint(x: 100, y: 100))
    }

    func testPointOnTrackMiddle() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 50), CGPoint(x: 100, y: 100)]
        let point = DriverPositionCalculator.pointOnTrack(ratio: 0.5, trackPoints: points)
        XCTAssertEqual(point, CGPoint(x: 50, y: 50))
    }

    func testPointOnTrackEmpty() {
        let point = DriverPositionCalculator.pointOnTrack(ratio: 0.5, trackPoints: [])
        XCTAssertNil(point)
    }

    // MARK: - Nearest Track Point

    func testNearestTrackPoint() {
        let trackPoints = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 100, y: 100),
            CGPoint(x: 0, y: 100)
        ]
        let nearest = DriverPositionCalculator.nearestTrackPoint(
            driverX: 95, driverY: 5, trackPoints: trackPoints
        )
        XCTAssertEqual(nearest, CGPoint(x: 100, y: 0), "Should find closest track point")
    }

    func testNearestTrackPointEmpty() {
        let nearest = DriverPositionCalculator.nearestTrackPoint(
            driverX: 50, driverY: 50, trackPoints: []
        )
        XCTAssertNil(nearest)
    }

    // MARK: - Clamped

    func testClampedInRange() {
        XCTAssertEqual(5.clamped(to: 0...10), 5)
    }

    func testClampedBelowRange() {
        XCTAssertEqual((-5).clamped(to: 0...10), 0)
    }

    func testClampedAboveRange() {
        XCTAssertEqual(15.clamped(to: 0...10), 10)
    }
}
