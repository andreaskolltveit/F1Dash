import Foundation

/// Session information from the SessionInfo topic.
struct SessionInfo {
    var meetingName: String
    var meetingOfficialName: String
    var meetingCountryName: String
    var meetingCircuitShortName: String
    var meetingCircuitKey: Int?
    var sessionName: String  // e.g., "Race", "Qualifying", "Practice 1"
    var sessionType: String  // e.g., "Race", "Qualifying", "Practice"
    var sessionPath: String  // Path for constructing static asset URLs
    var gmtOffset: String?   // e.g., "02:00:00"
    var startDate: Date?
    var endDate: Date?
    var year: Int

    /// Parse from raw JSON dictionary.
    static func from(dict: [String: Any]) -> SessionInfo? {
        let meeting = dict["Meeting"] as? [String: Any] ?? [:]
        let circuit = meeting["Circuit"] as? [String: Any] ?? [:]

        return SessionInfo(
            meetingName: meeting["Name"] as? String ?? "",
            meetingOfficialName: meeting["OfficialName"] as? String ?? "",
            meetingCountryName: meeting["Country"] as? [String: Any] != nil
                ? (meeting["Country"] as! [String: Any])["Name"] as? String ?? ""
                : meeting["Country"] as? String ?? "",
            meetingCircuitShortName: circuit["ShortName"] as? String ?? "",
            meetingCircuitKey: circuit["Key"] as? Int,
            sessionName: dict["Name"] as? String ?? "",
            sessionType: dict["Type"] as? String ?? "",
            sessionPath: dict["Path"] as? String ?? "",
            gmtOffset: dict["GmtOffset"] as? String,
            startDate: (dict["StartDate"] as? String).flatMap(DateFormatting.parseUTC),
            endDate: (dict["EndDate"] as? String).flatMap(DateFormatting.parseUTC),
            year: Calendar.current.component(.year, from: Date())
        )
    }
}

/// Session status from SessionStatus topic.
enum SessionStatusValue: String {
    case inactive = "Inactive"
    case started = "Started"
    case aborted = "Aborted"
    case finished = "Finished"
    case finalised = "Finalised"
    case ends = "Ends"

    var isActive: Bool {
        self == .started
    }
}
