import XCTest
@testable import F1Dash

final class StandingsModelTests: XCTestCase {

    // MARK: - DriverStanding

    func testDriverStandingPointsDouble() {
        let standing = DriverStanding(
            position: "1", positionText: "1", points: "395.5", wins: "15",
            driverId: "max_verstappen", permanentNumber: "1", code: "VER",
            givenName: "Max", familyName: "Verstappen", nationality: "Dutch",
            constructorName: "Red Bull", constructorId: "red_bull"
        )
        XCTAssertEqual(standing.pointsDouble, 395.5)
        XCTAssertEqual(standing.positionInt, 1)
        XCTAssertEqual(standing.id, "max_verstappen")
    }

    func testDriverStandingZeroPoints() {
        let standing = DriverStanding(
            position: "20", positionText: "20", points: "0", wins: "0",
            driverId: "test", permanentNumber: nil, code: nil,
            givenName: "Test", familyName: "Driver", nationality: "Test",
            constructorName: "Test", constructorId: "test"
        )
        XCTAssertEqual(standing.pointsDouble, 0)
        XCTAssertEqual(standing.positionInt, 20)
    }

    func testDriverStandingInvalidPoints() {
        let standing = DriverStanding(
            position: "N/A", positionText: "N/A", points: "invalid", wins: "0",
            driverId: "test", permanentNumber: nil, code: nil,
            givenName: "Test", familyName: "Driver", nationality: "Test",
            constructorName: "Test", constructorId: "test"
        )
        XCTAssertEqual(standing.pointsDouble, 0)
        XCTAssertEqual(standing.positionInt, 0)
    }

    // MARK: - ConstructorStanding

    func testConstructorStandingPointsDouble() {
        let standing = ConstructorStanding(
            position: "1", positionText: "1", points: "860", wins: "21",
            constructorId: "red_bull", constructorName: "Red Bull", nationality: "Austrian"
        )
        XCTAssertEqual(standing.pointsDouble, 860)
        XCTAssertEqual(standing.positionInt, 1)
        XCTAssertEqual(standing.id, "red_bull")
    }

    // MARK: - RaceEvent

    func testRaceEventId() {
        let event = RaceEvent(
            season: "2024", round: "1", raceName: "Bahrain GP",
            circuitName: "Sakhir", circuitId: "bahrain", country: "Bahrain",
            locality: "Sakhir", date: "2024-03-02", time: "15:00:00Z",
            fp1Date: nil, fp1Time: nil, qualifyingDate: nil, qualifyingTime: nil,
            sprintDate: nil, sprintTime: nil
        )
        XCTAssertEqual(event.id, "2024-1")
        XCTAssertEqual(event.roundInt, 1)
    }

    func testRaceEventRaceDate() {
        let event = RaceEvent(
            season: "2024", round: "1", raceName: "Bahrain GP",
            circuitName: "Sakhir", circuitId: "bahrain", country: "Bahrain",
            locality: "Sakhir", date: "2024-03-02", time: "15:00:00Z",
            fp1Date: nil, fp1Time: nil, qualifyingDate: nil, qualifyingTime: nil,
            sprintDate: nil, sprintTime: nil
        )
        XCTAssertNotNil(event.raceDate)
    }

    func testRaceEventRaceDateWithoutTime() {
        let event = RaceEvent(
            season: "2024", round: "1", raceName: "Test GP",
            circuitName: "Test", circuitId: "test", country: "Test",
            locality: "Test", date: "2024-03-02", time: nil,
            fp1Date: nil, fp1Time: nil, qualifyingDate: nil, qualifyingTime: nil,
            sprintDate: nil, sprintTime: nil
        )
        XCTAssertNotNil(event.raceDate)
    }

    func testRaceEventIsFuturePast() {
        // Past event
        let past = RaceEvent(
            season: "2020", round: "1", raceName: "Past GP",
            circuitName: "Test", circuitId: "test", country: "Test",
            locality: "Test", date: "2020-01-01", time: "15:00:00Z",
            fp1Date: nil, fp1Time: nil, qualifyingDate: nil, qualifyingTime: nil,
            sprintDate: nil, sprintTime: nil
        )
        XCTAssertFalse(past.isFuture)

        // Future event (well into the future)
        let future = RaceEvent(
            season: "2030", round: "1", raceName: "Future GP",
            circuitName: "Test", circuitId: "test", country: "Test",
            locality: "Test", date: "2030-12-31", time: "15:00:00Z",
            fp1Date: nil, fp1Time: nil, qualifyingDate: nil, qualifyingTime: nil,
            sprintDate: nil, sprintTime: nil
        )
        XCTAssertTrue(future.isFuture)
    }

    func testRaceEventSprintDetection() {
        let sprintEvent = RaceEvent(
            season: "2024", round: "1", raceName: "Sprint GP",
            circuitName: "Test", circuitId: "test", country: "Test",
            locality: "Test", date: "2024-03-02", time: "15:00:00Z",
            fp1Date: nil, fp1Time: nil, qualifyingDate: nil, qualifyingTime: nil,
            sprintDate: "2024-03-01", sprintTime: "15:00:00Z"
        )
        XCTAssertNotNil(sprintEvent.sprintDate)

        let nonSprintEvent = RaceEvent(
            season: "2024", round: "2", raceName: "Normal GP",
            circuitName: "Test", circuitId: "test", country: "Test",
            locality: "Test", date: "2024-03-16", time: "15:00:00Z",
            fp1Date: nil, fp1Time: nil, qualifyingDate: nil, qualifyingTime: nil,
            sprintDate: nil, sprintTime: nil
        )
        XCTAssertNil(nonSprintEvent.sprintDate)
    }
}
