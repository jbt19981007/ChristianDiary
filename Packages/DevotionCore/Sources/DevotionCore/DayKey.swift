import Foundation

/// 一个日历日（与时区无关），以 "YYYY-MM-DD" 字符串存储。
///
/// 灵修笔记按「哪一天」归档，而不是按精确时间点；用日历日可以避免跨时区、
/// 夏令时导致的日期错乱，也方便排序、分组和 iCloud 同步。
public struct DayKey: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    /// 不校验合法性；请只传入真实存在的日期，或使用 `init?(_:)`。
    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init?(_ string: String) {
        let parts = string.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m), (1...31).contains(d)
        else { return nil }
        let candidate = DayKey(year: y, month: m, day: d)
        // 通过「日序号 → 日期」往返检查，排除 2 月 30 日之类的日期
        guard DayKey(epochDay: candidate.epochDay) == candidate else { return nil }
        self = candidate
    }

    public init(date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1)
    }

    public static func today(calendar: Calendar = .current) -> DayKey {
        DayKey(date: Date(), calendar: calendar)
    }

    /// 距 1970-01-01 的天数（公历推算，Howard Hinnant 算法）。
    public var epochDay: Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yearOfEra = y - era * 400
        let shiftedMonth = (month + 9) % 12 // 3 月 = 0
        let dayOfYear = (153 * shiftedMonth + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    public init(epochDay: Int) {
        let z = epochDay + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let dayOfEra = z - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let shiftedMonth = (5 * dayOfYear + 2) / 153
        let d = dayOfYear - (153 * shiftedMonth + 2) / 5 + 1
        let m = shiftedMonth < 10 ? shiftedMonth + 3 : shiftedMonth - 9
        self.init(year: yearOfEra + era * 400 + (m <= 2 ? 1 : 0), month: m, day: d)
    }

    public var string: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public var description: String { string }

    public func adding(days: Int) -> DayKey {
        DayKey(epochDay: epochDay + days)
    }

    /// `other` 比自己晚多少天（更早则为负数）。
    public func days(until other: DayKey) -> Int {
        other.epochDay - epochDay
    }

    /// 0 = 星期日（主日），1 = 星期一 … 6 = 星期六
    public var weekday: Int {
        ((epochDay % 7) + 7 + 4) % 7 // 1970-01-01 是星期四
    }

    public var yearMonth: YearMonth {
        YearMonth(year: year, month: month)
    }

    /// 当天 0 点对应的 Date（用于日期选择器、通知等）。
    public func date(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let key = DayKey(raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "无效日期：\(raw)")
        }
        self = key
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }
}

// MARK: - 格式化

extension DayKey {
    static let chineseWeekdays = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]
    static let englishWeekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    static let englishMonths = ["January", "February", "March", "April", "May", "June",
                                "July", "August", "September", "October", "November", "December"]

    /// 例：「2026年9月27日 星期日」/「Sunday, September 27, 2026」
    public func formatted(_ language: Language, weekday showWeekday: Bool = true, year showYear: Bool = true) -> String {
        switch language {
        case .chinese:
            let date = "\(showYear ? "\(year)年" : "")\(month)月\(day)日"
            return showWeekday ? "\(date) \(DayKey.chineseWeekdays[weekday])" : date
        case .english:
            let date = "\(DayKey.englishMonths[month - 1]) \(day)\(showYear ? ", \(year)" : "")"
            return showWeekday ? "\(DayKey.englishWeekdays[weekday]), \(date)" : date
        }
    }

    /// 简短星期：「周日」/「Sun」
    public func shortWeekday(_ language: Language) -> String {
        switch language {
        case .chinese: return "周" + String(DayKey.chineseWeekdays[weekday].suffix(1))
        case .english: return String(DayKey.englishWeekdays[weekday].prefix(3))
        }
    }
}

/// 一个月份，用于月历。
public struct YearMonth: Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int

    public init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    public var firstDay: DayKey { DayKey(year: year, month: month, day: 1) }

    public var numberOfDays: Int {
        adding(months: 1).firstDay.epochDay - firstDay.epochDay
    }

    public var days: [DayKey] {
        (0..<numberOfDays).map { firstDay.adding(days: $0) }
    }

    public func adding(months: Int) -> YearMonth {
        let index = year * 12 + (month - 1) + months
        let y = index >= 0 ? index / 12 : (index - 11) / 12
        return YearMonth(year: y, month: index - y * 12 + 1)
    }

    public func contains(_ day: DayKey) -> Bool {
        day.year == year && day.month == month
    }

    /// 月历格子：每周从主日（星期日）开始，前后用 nil 补齐整周。
    public var calendarGrid: [DayKey?] {
        var cells: [DayKey?] = Array(repeating: nil, count: firstDay.weekday)
        cells.append(contentsOf: days.map { Optional($0) })
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    public func formatted(_ language: Language) -> String {
        switch language {
        case .chinese: return "\(year)年\(month)月"
        case .english: return "\(DayKey.englishMonths[month - 1]) \(year)"
        }
    }

    public static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }
}
