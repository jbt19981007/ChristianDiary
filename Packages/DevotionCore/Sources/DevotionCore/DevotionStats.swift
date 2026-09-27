import Foundation

/// 灵修统计：连续天数等。
public enum DevotionStats {
    /// 截至今天的连续灵修天数。今天还没写时，从昨天往前算（给今天留机会，不算中断）。
    public static func currentStreak(days: Set<DayKey>, today: DayKey) -> Int {
        var day = days.contains(today) ? today : today.adding(days: -1)
        var count = 0
        while days.contains(day) {
            count += 1
            day = day.adding(days: -1)
        }
        return count
    }

    /// 历史上最长的连续灵修天数。
    public static func longestStreak(days: Set<DayKey>) -> Int {
        var best = 0
        var run = 0
        var previous: DayKey?
        for day in days.sorted() {
            if let previous, previous.days(until: day) == 1 {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        return best
    }

    public static func count(days: Set<DayKey>, in month: YearMonth) -> Int {
        days.filter { month.contains($0) }.count
    }
}

/// 标签解析：支持空格、逗号、顿号、分号、# 分隔。
public enum TagParser {
    public static let maxTags = 12
    public static let maxLength = 20

    public static func parse(_ text: String) -> [String] {
        let separators = CharacterSet(charactersIn: " \t\n,，、;；#＃")
        return normalize(text.components(separatedBy: separators))
    }

    /// 去空白、去重（保持顺序）、截断。
    public static func normalize(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in tags {
            let tag = String(raw.trimmed.prefix(maxLength))
            guard !tag.isEmpty, seen.insert(tag).inserted else { continue }
            result.append(tag)
            if result.count == maxTags { break }
        }
        return result
    }

    public static func format(_ tags: [String]) -> String {
        tags.joined(separator: " ")
    }
}
