import XCTest
@testable import F1Dash

/// Tests for Ergast/Jolpica API response parsing logic.
/// Uses the same manual JSON parsing approach as ErgastClient.
final class ErgastParsingTests: XCTestCase {

    // MARK: - Schedule Parsing

    func testScheduleResponseParsing() throws {
        let json: [String: Any] = [
            "MRData": [
                "RaceTable": [
                    "season": "2024",
                    "Races": [
                        [
                            "season": "2024",
                            "round": "1",
                            "raceName": "Bahrain Grand Prix",
                            "Circuit": [
                                "circuitId": "bahrain",
                                "circuitName": "Bahrain International Circuit",
                                "Location": [
                                    "country": "Bahrain",
                                    "locality": "Sakhir"
                                ]
                            ],
                            "date": "2024-03-02",
                            "time": "15:00:00Z",
                            "FirstPractice": [
                                "date": "2024-02-29",
                                "time": "11:30:00Z"
                            ],
                            "Qualifying": [
                                "date": "2024-03-01",
                                "time": "15:00:00Z"
                            ]
                        ]
                    ]
                ]
            ]
        ]

        let races = parseRaceEvents(from: json)
        XCTAssertEqual(races.count, 1)
        XCTAssertEqual(races[0].raceName, "Bahrain Grand Prix")
        XCTAssertEqual(races[0].round, "1")
        XCTAssertEqual(races[0].country, "Bahrain")
        XCTAssertEqual(races[0].locality, "Sakhir")
        XCTAssertEqual(races[0].date, "2024-03-02")
        XCTAssertEqual(races[0].time, "15:00:00Z")
        XCTAssertNil(races[0].sprintDate)
    }

    func testScheduleWithSprint() throws {
        let json: [String: Any] = [
            "MRData": [
                "RaceTable": [
                    "Races": [
                        [
                            "season": "2024",
                            "round": "4",
                            "raceName": "Chinese Grand Prix",
                            "Circuit": [
                                "circuitId": "shanghai",
                                "circuitName": "Shanghai International Circuit",
                                "Location": [
                                    "country": "China",
                                    "locality": "Shanghai"
                                ]
                            ],
                            "date": "2024-04-21",
                            "time": "07:00:00Z",
                            "Sprint": [
                                "date": "2024-04-20",
                                "time": "03:00:00Z"
                            ]
                        ]
                    ]
                ]
            ]
        ]

        let races = parseRaceEvents(from: json)
        XCTAssertEqual(races.count, 1)
        XCTAssertEqual(races[0].sprintDate, "2024-04-20")
        XCTAssertEqual(races[0].sprintTime, "03:00:00Z")
    }

    func testEmptyScheduleResponse() {
        let json: [String: Any] = [
            "MRData": [
                "RaceTable": [
                    "Races": [] as [[String: Any]]
                ]
            ]
        ]
        let races = parseRaceEvents(from: json)
        XCTAssertTrue(races.isEmpty)
    }

    func testMalformedScheduleResponse() {
        let json: [String: Any] = ["unexpected": "format"]
        let races = parseRaceEvents(from: json)
        XCTAssertTrue(races.isEmpty)
    }

    // MARK: - Driver Standings Parsing

    func testDriverStandingsResponseParsing() throws {
        let json: [String: Any] = [
            "MRData": [
                "StandingsTable": [
                    "StandingsLists": [
                        [
                            "DriverStandings": [
                                [
                                    "position": "1",
                                    "positionText": "1",
                                    "points": "575",
                                    "wins": "19",
                                    "Driver": [
                                        "driverId": "max_verstappen",
                                        "permanentNumber": "1",
                                        "code": "VER",
                                        "givenName": "Max",
                                        "familyName": "Verstappen",
                                        "nationality": "Dutch"
                                    ],
                                    "Constructors": [
                                        ["constructorId": "red_bull", "name": "Red Bull"]
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]

        let standings = parseDriverStandings(from: json)
        XCTAssertEqual(standings.count, 1)
        XCTAssertEqual(standings[0].driverId, "max_verstappen")
        XCTAssertEqual(standings[0].code, "VER")
        XCTAssertEqual(standings[0].points, "575")
        XCTAssertEqual(standings[0].wins, "19")
        XCTAssertEqual(standings[0].constructorName, "Red Bull")
        XCTAssertEqual(standings[0].givenName, "Max")
        XCTAssertEqual(standings[0].familyName, "Verstappen")
    }

    func testEmptyDriverStandings() {
        let json: [String: Any] = [
            "MRData": [
                "StandingsTable": [
                    "StandingsLists": [] as [[String: Any]]
                ]
            ]
        ]
        let standings = parseDriverStandings(from: json)
        XCTAssertTrue(standings.isEmpty)
    }

    // MARK: - Constructor Standings Parsing

    func testConstructorStandingsResponseParsing() throws {
        let json: [String: Any] = [
            "MRData": [
                "StandingsTable": [
                    "StandingsLists": [
                        [
                            "ConstructorStandings": [
                                [
                                    "position": "1",
                                    "positionText": "1",
                                    "points": "860",
                                    "wins": "21",
                                    "Constructor": [
                                        "constructorId": "red_bull",
                                        "name": "Red Bull",
                                        "nationality": "Austrian"
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]

        let standings = parseConstructorStandings(from: json)
        XCTAssertEqual(standings.count, 1)
        XCTAssertEqual(standings[0].constructorId, "red_bull")
        XCTAssertEqual(standings[0].constructorName, "Red Bull")
        XCTAssertEqual(standings[0].points, "860")
    }

    // MARK: - Schedule Edge Cases

    func testScheduleMultipleRaces() {
        let json: [String: Any] = [
            "MRData": [
                "RaceTable": [
                    "Races": [
                        [
                            "season": "2024", "round": "1", "raceName": "Bahrain GP",
                            "Circuit": ["circuitId": "bahrain", "circuitName": "Bahrain", "Location": ["country": "Bahrain", "locality": "Sakhir"]],
                            "date": "2024-03-02", "time": "15:00:00Z"
                        ],
                        [
                            "season": "2024", "round": "2", "raceName": "Saudi Arabian GP",
                            "Circuit": ["circuitId": "jeddah", "circuitName": "Jeddah", "Location": ["country": "Saudi Arabia", "locality": "Jeddah"]],
                            "date": "2024-03-09", "time": "17:00:00Z"
                        ],
                        [
                            "season": "2024", "round": "3", "raceName": "Australian GP",
                            "Circuit": ["circuitId": "albert_park", "circuitName": "Albert Park", "Location": ["country": "Australia", "locality": "Melbourne"]],
                            "date": "2024-03-24", "time": "04:00:00Z"
                        ]
                    ]
                ]
            ]
        ]

        let races = parseRaceEvents(from: json)
        XCTAssertEqual(races.count, 3)
        XCTAssertEqual(races[0].round, "1")
        XCTAssertEqual(races[1].round, "2")
        XCTAssertEqual(races[2].round, "3")
        XCTAssertEqual(races[2].country, "Australia")
    }

    func testScheduleWithAllSessionDates() {
        let json: [String: Any] = [
            "MRData": [
                "RaceTable": [
                    "Races": [
                        [
                            "season": "2024", "round": "1", "raceName": "Test GP",
                            "Circuit": ["circuitId": "test", "circuitName": "Test", "Location": ["country": "Test", "locality": "Test"]],
                            "date": "2024-03-02", "time": "15:00:00Z",
                            "FirstPractice": ["date": "2024-02-29", "time": "11:30:00Z"],
                            "Qualifying": ["date": "2024-03-01", "time": "15:00:00Z"],
                            "Sprint": ["date": "2024-03-01", "time": "11:00:00Z"]
                        ]
                    ]
                ]
            ]
        ]

        let races = parseRaceEvents(from: json)
        XCTAssertEqual(races.count, 1)
        XCTAssertEqual(races[0].fp1Date, "2024-02-29")
        XCTAssertEqual(races[0].fp1Time, "11:30:00Z")
        XCTAssertEqual(races[0].qualifyingDate, "2024-03-01")
        XCTAssertEqual(races[0].qualifyingTime, "15:00:00Z")
        XCTAssertEqual(races[0].sprintDate, "2024-03-01")
        XCTAssertEqual(races[0].sprintTime, "11:00:00Z")
    }

    func testScheduleMissingCircuit() {
        let json: [String: Any] = [
            "MRData": [
                "RaceTable": [
                    "Races": [
                        ["season": "2024", "round": "1", "raceName": "Mystery GP", "date": "2024-06-01"]
                    ]
                ]
            ]
        ]

        let races = parseRaceEvents(from: json)
        XCTAssertEqual(races.count, 1)
        XCTAssertEqual(races[0].circuitName, "")
        XCTAssertEqual(races[0].country, "")
    }

    func testScheduleMissingTime() {
        let json: [String: Any] = [
            "MRData": [
                "RaceTable": [
                    "Races": [
                        [
                            "season": "2024", "round": "1", "raceName": "Test GP",
                            "Circuit": ["circuitId": "test", "circuitName": "Test", "Location": ["country": "Test", "locality": "Test"]],
                            "date": "2024-03-02"
                        ]
                    ]
                ]
            ]
        ]

        let races = parseRaceEvents(from: json)
        XCTAssertEqual(races.count, 1)
        XCTAssertNil(races[0].time)
    }

    // MARK: - Driver Standings Edge Cases

    func testDriverStandingsMultipleDrivers() {
        let json: [String: Any] = [
            "MRData": [
                "StandingsTable": [
                    "StandingsLists": [
                        [
                            "DriverStandings": [
                                [
                                    "position": "1", "positionText": "1", "points": "575", "wins": "19",
                                    "Driver": ["driverId": "max_verstappen", "code": "VER", "givenName": "Max", "familyName": "Verstappen", "nationality": "Dutch"],
                                    "Constructors": [["constructorId": "red_bull", "name": "Red Bull"]]
                                ],
                                [
                                    "position": "2", "positionText": "2", "points": "285", "wins": "2",
                                    "Driver": ["driverId": "norris", "code": "NOR", "givenName": "Lando", "familyName": "Norris", "nationality": "British"],
                                    "Constructors": [["constructorId": "mclaren", "name": "McLaren"]]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]

        let standings = parseDriverStandings(from: json)
        XCTAssertEqual(standings.count, 2)
        XCTAssertEqual(standings[0].driverId, "max_verstappen")
        XCTAssertEqual(standings[0].pointsDouble, 575)
        XCTAssertEqual(standings[1].driverId, "norris")
        XCTAssertEqual(standings[1].pointsDouble, 285)
    }

    func testDriverStandingsNoCode() {
        let json: [String: Any] = [
            "MRData": [
                "StandingsTable": [
                    "StandingsLists": [
                        [
                            "DriverStandings": [
                                [
                                    "position": "1", "positionText": "1", "points": "100", "wins": "5",
                                    "Driver": ["driverId": "test_driver", "givenName": "Test", "familyName": "Driver", "nationality": "Test"],
                                    "Constructors": [["constructorId": "test", "name": "Test Team"]]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]

        let standings = parseDriverStandings(from: json)
        XCTAssertEqual(standings.count, 1)
        XCTAssertNil(standings[0].code)
        XCTAssertNil(standings[0].permanentNumber)
    }

    func testDriverStandingsMalformedResponse() {
        let json: [String: Any] = ["MRData": ["unexpected": "structure"]]
        let standings = parseDriverStandings(from: json)
        XCTAssertTrue(standings.isEmpty)
    }

    // MARK: - Constructor Standings Edge Cases

    func testConstructorStandingsMultipleTeams() {
        let json: [String: Any] = [
            "MRData": [
                "StandingsTable": [
                    "StandingsLists": [
                        [
                            "ConstructorStandings": [
                                [
                                    "position": "1", "positionText": "1", "points": "860", "wins": "21",
                                    "Constructor": ["constructorId": "red_bull", "name": "Red Bull", "nationality": "Austrian"]
                                ],
                                [
                                    "position": "2", "positionText": "2", "points": "400", "wins": "5",
                                    "Constructor": ["constructorId": "mclaren", "name": "McLaren", "nationality": "British"]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]

        let standings = parseConstructorStandings(from: json)
        XCTAssertEqual(standings.count, 2)
        XCTAssertEqual(standings[0].constructorName, "Red Bull")
        XCTAssertEqual(standings[1].constructorName, "McLaren")
    }

    func testConstructorStandingsMalformedResponse() {
        let json: [String: Any] = ["garbage": true]
        let standings = parseConstructorStandings(from: json)
        XCTAssertTrue(standings.isEmpty)
    }

    func testConstructorStandingsEmptyLists() {
        let json: [String: Any] = [
            "MRData": [
                "StandingsTable": [
                    "StandingsLists": [] as [[String: Any]]
                ]
            ]
        ]
        let standings = parseConstructorStandings(from: json)
        XCTAssertTrue(standings.isEmpty)
    }

    // MARK: - Helpers (mirror ErgastClient's parsing)

    private func parseRaceEvents(from json: [String: Any]) -> [RaceEvent] {
        guard let mrData = json["MRData"] as? [String: Any],
              let raceTable = mrData["RaceTable"] as? [String: Any],
              let races = raceTable["Races"] as? [[String: Any]] else {
            return []
        }
        return races.compactMap { parseRaceEvent($0) }
    }

    private func parseRaceEvent(_ dict: [String: Any]) -> RaceEvent? {
        let circuit = dict["Circuit"] as? [String: Any] ?? [:]
        let location = circuit["Location"] as? [String: Any] ?? [:]
        let sprint = dict["Sprint"] as? [String: Any]

        return RaceEvent(
            season: dict["season"] as? String ?? "",
            round: dict["round"] as? String ?? "",
            raceName: dict["raceName"] as? String ?? "",
            circuitName: circuit["circuitName"] as? String ?? "",
            circuitId: circuit["circuitId"] as? String ?? "",
            country: location["country"] as? String ?? "",
            locality: location["locality"] as? String ?? "",
            date: dict["date"] as? String ?? "",
            time: dict["time"] as? String,
            fp1Date: (dict["FirstPractice"] as? [String: Any])?["date"] as? String,
            fp1Time: (dict["FirstPractice"] as? [String: Any])?["time"] as? String,
            qualifyingDate: (dict["Qualifying"] as? [String: Any])?["date"] as? String,
            qualifyingTime: (dict["Qualifying"] as? [String: Any])?["time"] as? String,
            sprintDate: sprint?["date"] as? String,
            sprintTime: sprint?["time"] as? String
        )
    }

    private func parseDriverStandings(from json: [String: Any]) -> [DriverStanding] {
        guard let mrData = json["MRData"] as? [String: Any],
              let table = mrData["StandingsTable"] as? [String: Any],
              let lists = table["StandingsLists"] as? [[String: Any]],
              let first = lists.first,
              let standings = first["DriverStandings"] as? [[String: Any]] else {
            return []
        }
        return standings.compactMap { dict in
            let driver = dict["Driver"] as? [String: Any] ?? [:]
            let constructors = dict["Constructors"] as? [[String: Any]] ?? []
            let constructor = constructors.first ?? [:]
            return DriverStanding(
                position: dict["position"] as? String ?? "",
                positionText: dict["positionText"] as? String ?? "",
                points: dict["points"] as? String ?? "0",
                wins: dict["wins"] as? String ?? "0",
                driverId: driver["driverId"] as? String ?? "",
                permanentNumber: driver["permanentNumber"] as? String,
                code: driver["code"] as? String,
                givenName: driver["givenName"] as? String ?? "",
                familyName: driver["familyName"] as? String ?? "",
                nationality: driver["nationality"] as? String ?? "",
                constructorName: constructor["name"] as? String ?? "",
                constructorId: constructor["constructorId"] as? String ?? ""
            )
        }
    }

    private func parseConstructorStandings(from json: [String: Any]) -> [ConstructorStanding] {
        guard let mrData = json["MRData"] as? [String: Any],
              let table = mrData["StandingsTable"] as? [String: Any],
              let lists = table["StandingsLists"] as? [[String: Any]],
              let first = lists.first,
              let standings = first["ConstructorStandings"] as? [[String: Any]] else {
            return []
        }
        return standings.compactMap { dict in
            let constructor = dict["Constructor"] as? [String: Any] ?? [:]
            return ConstructorStanding(
                position: dict["position"] as? String ?? "",
                positionText: dict["positionText"] as? String ?? "",
                points: dict["points"] as? String ?? "0",
                wins: dict["wins"] as? String ?? "0",
                constructorId: constructor["constructorId"] as? String ?? "",
                constructorName: constructor["name"] as? String ?? "",
                nationality: constructor["nationality"] as? String ?? ""
            )
        }
    }
}
