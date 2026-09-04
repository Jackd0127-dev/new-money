import Foundation

struct CalendarMonthPresentationKey: Equatable {
    var revision: PlannerPresentationRevision
    var startDate: String
    var endDate: String
}

struct CalendarMonthPresentation {
    var eventsByDate: [String: [CalendarEvent]]
    var eventDates: [String]

    static func make(snapshot: PlannerSnapshot, startDate: String, endDate: String) -> Self {
        let events = PlannerDerivedData.calendarEvents(
            snapshot: snapshot,
            startDate: startDate,
            endDate: endDate
        )
        let eventsByDate = Dictionary(grouping: events, by: \.date)
        return Self(eventsByDate: eventsByDate, eventDates: eventsByDate.keys.sorted())
    }
}
