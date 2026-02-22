import XCTest
@testable import F1Dash

final class DateFormattingTests: XCTestCase {

    // MARK: - UTC Parsing

    func testParseUTCWithFractionalSeconds() {
        let date = DateFormatting.parseUTC("2026-03-02T15:00:00.123Z")
        XCTAssertNotNil(date)

        let calendar = Calendar(identifier: .gregorian)
        var comps = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: date!)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 3)
        XCTAssertEqual(comps.day, 2)
        XCTAssertEqual(comps.hour, 15)
        XCTAssertEqual(comps.minute, 0)
        XCTAssertEqual(comps.second, 0)
    }

    func testParseUTCWithoutFractionalSeconds() {
        let date = DateFormatting.parseUTC("2026-03-02T15:00:00Z")
        XCTAssertNotNil(date)
    }

    func testParseUTCInvalidString() {
        let date = DateFormatting.parseUTC("not-a-date")
        XCTAssertNil(date)
    }

    func testParseUTCEmpty() {
        let date = DateFormatting.parseUTC("")
        XCTAssertNil(date)
    }

    // MARK: - GMT Offset Parsing

    func testParseGmtOffsetPositive() {
        let seconds = DateFormatting.parseGmtOffset("03:00:00")
        XCTAssertEqual(seconds, 10800) // 3 hours
    }

    func testParseGmtOffsetNegative() {
        let seconds = DateFormatting.parseGmtOffset("-05:00:00")
        XCTAssertEqual(seconds, -18000) // -5 hours
    }

    func testParseGmtOffsetHalfHour() {
        let seconds = DateFormatting.parseGmtOffset("05:30:00")
        XCTAssertEqual(seconds, 19800) // 5.5 hours
    }

    func testParseGmtOffsetInvalid() {
        let seconds = DateFormatting.parseGmtOffset("invalid")
        XCTAssertNil(seconds)
    }

    // MARK: - Local Time Formatting

    func testLocalTimeStringFormat() {
        let date = DateFormatting.parseUTC("2026-03-02T12:34:56Z")!
        let str = DateFormatting.localTimeString(date)

        // Should be HH:mm:ss format
        let parts = str.split(separator: ":")
        XCTAssertEqual(parts.count, 3, "Should have 3 colon-separated parts")
        XCTAssertEqual(parts[1].count, 2, "Minutes should be 2 digits")
        XCTAssertEqual(parts[2].count, 2, "Seconds should be 2 digits")
    }

    // MARK: - Track Time

    func testTrackTimeWithOffset() {
        let utcDate = DateFormatting.parseUTC("2026-03-02T12:00:00Z")!
        let trackTime = DateFormatting.trackTimeString(utcDate, gmtOffset: "03:00:00")

        // Track time should be 15:00:00 (UTC + 3h)
        XCTAssertEqual(trackTime, "15:00:00")
    }

    func testTrackTimeWithNilOffset() {
        let utcDate = DateFormatting.parseUTC("2026-03-02T12:00:00Z")!
        let trackTime = DateFormatting.trackTimeString(utcDate, gmtOffset: nil)

        // Should fall back to local time
        let localTime = DateFormatting.localTimeString(utcDate)
        XCTAssertEqual(trackTime, localTime)
    }
}
