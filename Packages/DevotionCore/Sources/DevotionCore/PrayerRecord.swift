import Foundation

public enum PrayerStatus: String, Codable, Sendable, CaseIterable {
    case praying
    case answered
}

/// 一条代祷事项的可移植表示（备份、分享用）。
public struct PrayerRecord: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var title: String
    public var forWhom: String
    public var detail: String
    public var status: PrayerStatus
    public var startDay: DayKey
    public var answeredDay: DayKey?
    public var answerNote: String
    public var prayedCount: Int
    public var lastPrayedDay: DayKey?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        forWhom: String = "",
        detail: String = "",
        status: PrayerStatus = .praying,
        startDay: DayKey,
        answeredDay: DayKey? = nil,
        answerNote: String = "",
        prayedCount: Int = 0,
        lastPrayedDay: DayKey? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.forWhom = forWhom
        self.detail = detail
        self.status = status
        self.startDay = startDay
        self.answeredDay = answeredDay
        self.answerNote = answerNote
        self.prayedCount = prayedCount
        self.lastPrayedDay = lastPrayedDay
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    /// 从开始代祷到蒙应允（或到今天）共多少天，含首尾。
    public func daysPrayed(until today: DayKey) -> Int {
        max(startDay.days(until: answeredDay ?? today) + 1, 1)
    }

    /// 分享到微信等的文字。
    public func shareText(_ language: Language, today: DayKey) -> String {
        var lines: [String] = []
        switch status {
        case .praying:
            lines.append(language.pick("🙏 代祷事项", "🙏 Prayer Request"))
        case .answered:
            lines.append(language.pick("✨ 感谢神，祷告蒙应允", "✨ Praise God — prayer answered"))
        }
        lines.append(title.trimmed)
        if !forWhom.isBlank { lines.append(language.pick("为：", "For: ") + forWhom.trimmed) }
        if !detail.isBlank { lines.append(""); lines.append(detail.trimmed) }
        if status == .answered {
            if !answerNote.isBlank { lines.append(""); lines.append(answerNote.trimmed) }
            let days = daysPrayed(until: today)
            lines.append("")
            lines.append(language.pick("历时 \(days) 天", "After \(days) day\(days == 1 ? "" : "s") of prayer"))
        }
        return lines.joined(separator: "\n")
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, forWhom, detail, status, startDay, answeredDay, answerNote
        case prayedCount, lastPrayedDay, createdAt, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        forWhom = try c.decodeIfPresent(String.self, forKey: .forWhom) ?? ""
        detail = try c.decodeIfPresent(String.self, forKey: .detail) ?? ""
        status = (try? c.decodeIfPresent(PrayerStatus.self, forKey: .status)) ?? .praying
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        startDay = try c.decodeIfPresent(DayKey.self, forKey: .startDay) ?? DayKey(date: createdAt)
        answeredDay = try c.decodeIfPresent(DayKey.self, forKey: .answeredDay)
        answerNote = try c.decodeIfPresent(String.self, forKey: .answerNote) ?? ""
        prayedCount = try max(c.decodeIfPresent(Int.self, forKey: .prayedCount) ?? 0, 0)
        lastPrayedDay = try c.decodeIfPresent(DayKey.self, forKey: .lastPrayedDay)
    }
}
