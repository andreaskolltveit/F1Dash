import XCTest
@testable import F1Dash

final class StateMergerTests: XCTestCase {

    // MARK: - Dict + Dict (recursive merge)

    func testMergeDictIntoDict() {
        let base: [String: Any] = [
            "a": 1,
            "b": ["x": 10, "y": 20],
            "c": "keep"
        ]
        let update: [String: Any] = [
            "a": 2,
            "b": ["y": 99, "z": 30],
            "d": "new"
        ]

        let result = StateMerger.merge(base: base, update: update) as! [String: Any]

        XCTAssertEqual(result["a"] as? Int, 2, "Simple value should be replaced")
        XCTAssertEqual(result["c"] as? String, "keep", "Untouched key should survive")
        XCTAssertEqual(result["d"] as? String, "new", "New key should be added")

        let nested = result["b"] as! [String: Any]
        XCTAssertEqual(nested["x"] as? Int, 10, "Nested untouched key should survive")
        XCTAssertEqual(nested["y"] as? Int, 99, "Nested key should be updated")
        XCTAssertEqual(nested["z"] as? Int, 30, "Nested new key should be added")
    }

    func testDeepNestedMerge() {
        let base: [String: Any] = [
            "Lines": [
                "1": ["Position": "1", "GapToLeader": ""],
                "44": ["Position": "2", "GapToLeader": "+3.456"]
            ]
        ]
        let update: [String: Any] = [
            "Lines": [
                "1": ["GapToLeader": "LEADER"],
                "44": ["Position": "3"]
            ]
        ]

        let result = StateMerger.merge(base: base, update: update) as! [String: Any]
        let lines = result["Lines"] as! [String: Any]
        let driver1 = lines["1"] as! [String: Any]
        let driver44 = lines["44"] as! [String: Any]

        XCTAssertEqual(driver1["Position"] as? String, "1", "Untouched field should survive")
        XCTAssertEqual(driver1["GapToLeader"] as? String, "LEADER", "Updated field should change")
        XCTAssertEqual(driver44["Position"] as? String, "3", "Updated field should change")
        XCTAssertEqual(driver44["GapToLeader"] as? String, "+3.456", "Untouched field should survive")
    }

    // MARK: - Array + Dict (numeric keys as indices)

    func testMergeArrayWithDictIndices() {
        let base: [Any] = ["a", "b", "c", "d"]
        let update: [String: Any] = ["1": "B", "3": "D"]

        let result = StateMerger.merge(base: base, update: update) as! [Any]

        XCTAssertEqual(result[0] as? String, "a", "Index 0 untouched")
        XCTAssertEqual(result[1] as? String, "B", "Index 1 updated")
        XCTAssertEqual(result[2] as? String, "c", "Index 2 untouched")
        XCTAssertEqual(result[3] as? String, "D", "Index 3 updated")
    }

    func testMergeArrayExtends() {
        let base: [Any] = ["a", "b"]
        let update: [String: Any] = ["4": "e"]

        let result = StateMerger.merge(base: base, update: update) as! [Any]

        XCTAssertEqual(result.count, 5, "Array should extend to fit index 4")
        XCTAssertEqual(result[4] as? String, "e", "New index should be set")
    }

    // MARK: - Replace (default case)

    func testReplaceScalarWithScalar() {
        let result = StateMerger.merge(base: "old", update: "new")
        XCTAssertEqual(result as? String, "new")
    }

    func testReplaceNilBase() {
        let result = StateMerger.merge(base: nil, update: ["key": "value"])
        XCTAssertNotNil(result as? [String: Any])
    }

    func testReplaceNilUpdate() {
        let result = StateMerger.merge(base: "keep", update: nil)
        XCTAssertEqual(result as? String, "keep")
    }

    // MARK: - Real F1 scenario: TimingData partial update

    func testTimingDataPartialUpdate() {
        let base: [String: Any] = [
            "Lines": [
                "1": [
                    "Position": "1",
                    "Sectors": [
                        "0": ["Value": "31.234", "Segments": ["0": ["Status": 2049]]],
                        "1": ["Value": "", "Segments": [:]],
                        "2": ["Value": "", "Segments": [:]]
                    ]
                ]
            ]
        ]

        // F1 sends: driver 1, sector 1 completed
        let update: [String: Any] = [
            "Lines": [
                "1": [
                    "Sectors": [
                        "1": ["Value": "28.567", "Segments": ["0": ["Status": 2051]]]
                    ]
                ]
            ]
        ]

        let result = StateMerger.merge(base: base, update: update) as! [String: Any]
        let lines = result["Lines"] as! [String: Any]
        let driver = lines["1"] as! [String: Any]
        let sectors = driver["Sectors"] as! [String: Any]

        // Sector 0 should be untouched
        let s0 = sectors["0"] as! [String: Any]
        XCTAssertEqual(s0["Value"] as? String, "31.234")

        // Sector 1 should be updated
        let s1 = sectors["1"] as! [String: Any]
        XCTAssertEqual(s1["Value"] as? String, "28.567")
        let s1segs = s1["Segments"] as! [String: Any]
        let seg0 = s1segs["0"] as! [String: Any]
        XCTAssertEqual(seg0["Status"] as? Int, 2051, "Purple sector status")

        // Position should survive
        XCTAssertEqual(driver["Position"] as? String, "1")
    }
}
