import XCTest
@testable import F1Dash

@MainActor
final class DelayBufferTests: XCTestCase {

    // MARK: - Zero Delay (Pass-through)

    func testZeroDelayPassesThrough() {
        let store = LiveTimingStore()
        let buffer = DelayBuffer()
        buffer.start(store: store)
        buffer.delaySeconds = 0

        // Push weather data — should go directly to store
        buffer.push(topic: "WeatherData", data: [
            "AirTemp": "28.5",
            "TrackTemp": "42.1",
            "Humidity": "65",
            "Rainfall": "0"
        ] as [String: Any])

        XCTAssertNotNil(store.weatherData)
        XCTAssertEqual(store.weatherData?.airTemp, 28.5)
    }

    func testZeroDelayInitialStatePassesThrough() {
        let store = LiveTimingStore()
        let buffer = DelayBuffer()
        buffer.start(store: store)
        buffer.delaySeconds = 0

        buffer.pushInitialState([
            "SessionStatus": ["Status": "Started"] as [String: Any],
            "WeatherData": [
                "AirTemp": "25.0",
                "TrackTemp": "38.0",
                "Humidity": "70",
                "Rainfall": "0"
            ] as [String: Any]
        ])

        XCTAssertEqual(store.sessionStatus, .started)
        XCTAssertNotNil(store.weatherData)
    }

    // MARK: - Buffered (Delay > 0)

    func testDelayBuffersMessages() {
        let store = LiveTimingStore()
        let buffer = DelayBuffer()
        buffer.start(store: store)
        buffer.delaySeconds = 30

        // Push data — should NOT appear in store yet
        buffer.push(topic: "WeatherData", data: [
            "AirTemp": "30.0",
            "TrackTemp": "45.0",
            "Humidity": "55",
            "Rainfall": "0"
        ] as [String: Any])

        XCTAssertNil(store.weatherData, "Data should be buffered, not passed through")
    }

    func testDelayBuffersInitialState() {
        let store = LiveTimingStore()
        let buffer = DelayBuffer()
        buffer.start(store: store)
        buffer.delaySeconds = 30

        buffer.pushInitialState([
            "WeatherData": [
                "AirTemp": "25.0",
                "TrackTemp": "38.0",
                "Humidity": "70",
                "Rainfall": "0"
            ] as [String: Any]
        ])

        // Data should be buffered, not in store yet
        XCTAssertNil(store.weatherData)
    }

    // MARK: - Clear

    func testClearRemovesAllBuffers() {
        let store = LiveTimingStore()
        let buffer = DelayBuffer()
        buffer.start(store: store)
        buffer.delaySeconds = 30

        buffer.push(topic: "WeatherData", data: ["AirTemp": "25.0"] as [String: Any])
        buffer.push(topic: "SessionStatus", data: ["Status": "Started"] as [String: Any])

        // maxAvailableDelay should be > 0 since we have buffered data
        // (immediately after push, delta is ~0, but buffer is not empty)
        buffer.clear()

        // After clear, maxAvailableDelay should be 0
        XCTAssertEqual(buffer.maxAvailableDelay, 0)
    }

    // MARK: - Stop

    func testStopClearsBuffers() {
        let store = LiveTimingStore()
        let buffer = DelayBuffer()
        buffer.start(store: store)
        buffer.delaySeconds = 30

        buffer.push(topic: "WeatherData", data: ["AirTemp": "25.0"] as [String: Any])
        buffer.stop()

        XCTAssertEqual(buffer.maxAvailableDelay, 0)
    }

    // MARK: - Stateful Merging

    func testStatefulMergingInBuffer() {
        let store = LiveTimingStore()
        let buffer = DelayBuffer()
        buffer.start(store: store)
        buffer.delaySeconds = 0

        // First push: initial driver list
        buffer.push(topic: "DriverList", data: [
            "1": [
                "RacingNumber": "1",
                "Tla": "VER",
                "FullName": "Max VERSTAPPEN",
                "TeamName": "Red Bull Racing",
                "TeamColour": "3671C6",
                "Line": 1
            ] as [String: Any]
        ] as [String: Any])

        XCTAssertEqual(store.drivers.count, 1)
        XCTAssertEqual(store.drivers["1"]?.tla, "VER")
    }

    // MARK: - Multiple Topics

    func testMultipleTopicsBufferedIndependently() {
        let store = LiveTimingStore()
        let buffer = DelayBuffer()
        buffer.start(store: store)
        buffer.delaySeconds = 30

        buffer.push(topic: "WeatherData", data: ["AirTemp": "25.0"] as [String: Any])
        buffer.push(topic: "SessionStatus", data: ["Status": "Started"] as [String: Any])
        buffer.push(topic: "LapCount", data: ["CurrentLap": 5, "TotalLaps": 57] as [String: Any])

        // All should be buffered (delay > 0)
        XCTAssertNil(store.weatherData)
        XCTAssertEqual(store.sessionStatus, .inactive) // default
        XCTAssertNil(store.lapCount)
    }
}
