import Foundation

enum WordCounter {
    static func count(_ text: String) -> Int {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
}

enum UsageStatsConstants {
    static let assumedTypingWordsPerMinute = 40.0
    static let assumedSpeakingWordsPerMinute = 150.0
}

struct UsageStats: Equatable, Sendable {
    var wordsToday: Int
    var minutesSavedToday: Int

    static let empty = UsageStats(wordsToday: 0, minutesSavedToday: 0)
}

enum UsageStatsCalculator {
    struct Entry: Equatable, Sendable {
        var createdAt: Date
        var wordCount: Int
        var durationSeconds: Double?
    }

    static func stats(for entries: [Entry], now: Date = .now, calendar: Calendar = .current) -> UsageStats {
        let todaysEntries = entries.filter { calendar.isDate($0.createdAt, inSameDayAs: now) }

        let wordsToday = todaysEntries.reduce(0) { $0 + $1.wordCount }

        let totalSavedMinutes = todaysEntries.reduce(0.0) { partial, entry in
            let typingMinutes = Double(entry.wordCount) / UsageStatsConstants.assumedTypingWordsPerMinute
            let speakingMinutes = entry.durationSeconds.map { $0 / 60.0 }
                ?? (Double(entry.wordCount) / UsageStatsConstants.assumedSpeakingWordsPerMinute)
            let savedMinutes = max(0, typingMinutes - speakingMinutes)
            return partial + savedMinutes
        }

        return UsageStats(wordsToday: wordsToday, minutesSavedToday: Int(totalSavedMinutes.rounded()))
    }
}
