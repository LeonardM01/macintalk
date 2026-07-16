import Foundation
import Testing
@testable import MacinTalk

struct HistoryGroupingTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private var now: Date {
        DateComponents(calendar: calendar, year: 2026, month: 7, day: 16, hour: 12).date!
    }

    @Test func labelsSameDayAsToday() {
        let sameDayLater = calendar.date(byAdding: .hour, value: 3, to: now)!
        #expect(HistoryGrouping.label(for: sameDayLater, now: now, calendar: calendar) == "Today")
    }

    @Test func labelsPreviousDayAsYesterday() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        #expect(HistoryGrouping.label(for: yesterday, now: now, calendar: calendar) == "Yesterday")
    }

    @Test func labelsOlderDateWithFormattedDate() {
        let older = calendar.date(byAdding: .day, value: -10, to: now)!
        let label = HistoryGrouping.label(for: older, now: now, calendar: calendar)
        #expect(label != "Today")
        #expect(label != "Yesterday")
        #expect(!label.isEmpty)
    }

    @Test func respectsInjectedNowRatherThanAmbientDate() {
        let fixedNow = DateComponents(calendar: calendar, year: 2020, month: 1, day: 1, hour: 0).date!
        #expect(HistoryGrouping.label(for: fixedNow, now: fixedNow, calendar: calendar) == "Today")
    }
}
