import Foundation
import Testing
@testable import MacinTalk

struct WordCounterTests {
    @Test func emptyString() {
        #expect(WordCounter.count("") == 0)
    }

    @Test func whitespaceOnly() {
        #expect(WordCounter.count("   \n\t  ") == 0)
    }

    @Test func singleWord() {
        #expect(WordCounter.count("hello") == 1)
    }

    @Test func multipleSpacesAndNewlinesBetweenWords() {
        #expect(WordCounter.count("hello   world\nfoo\n\nbar") == 4)
    }

    @Test func leadingAndTrailingWhitespace() {
        #expect(WordCounter.count("  hello world  ") == 2)
    }
}

struct UsageStatsCalculatorTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private var now: Date {
        DateComponents(calendar: calendar, year: 2026, month: 7, day: 16, hour: 12).date!
    }

    @Test func excludesEntriesFromOtherDays() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let entries = [
            UsageStatsCalculator.Entry(createdAt: yesterday, wordCount: 100, durationSeconds: 60),
            UsageStatsCalculator.Entry(createdAt: now, wordCount: 10, durationSeconds: 10)
        ]

        let stats = UsageStatsCalculator.stats(for: entries, now: now, calendar: calendar)
        #expect(stats.wordsToday == 10)
    }

    @Test func sumsWordsToday() {
        let entries = [
            UsageStatsCalculator.Entry(createdAt: now, wordCount: 10, durationSeconds: 10),
            UsageStatsCalculator.Entry(createdAt: now, wordCount: 20, durationSeconds: 20)
        ]

        let stats = UsageStatsCalculator.stats(for: entries, now: now, calendar: calendar)
        #expect(stats.wordsToday == 30)
    }

    @Test func usesMeasuredDurationWhenPresent() {
        let entries = [
            UsageStatsCalculator.Entry(createdAt: now, wordCount: 300, durationSeconds: 30)
        ]

        let stats = UsageStatsCalculator.stats(for: entries, now: now, calendar: calendar)
        #expect(stats.minutesSavedToday == 7)
    }

    @Test func fallsBackToSpeakingEstimateWhenDurationIsNil() {
        let entries = [
            UsageStatsCalculator.Entry(createdAt: now, wordCount: 150, durationSeconds: nil)
        ]

        let stats = UsageStatsCalculator.stats(for: entries, now: now, calendar: calendar)
        #expect(stats.minutesSavedToday == 3)
    }

    @Test func clampsToZeroWhenSpeakingTookLonger() {
        let entries = [
            UsageStatsCalculator.Entry(createdAt: now, wordCount: 10, durationSeconds: 600)
        ]

        let stats = UsageStatsCalculator.stats(for: entries, now: now, calendar: calendar)
        #expect(stats.minutesSavedToday == 0)
    }

    @Test func returnsEmptyEquivalentForNoEntries() {
        let stats = UsageStatsCalculator.stats(for: [], now: now, calendar: calendar)
        #expect(stats == UsageStats.empty)
    }
}
