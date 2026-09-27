/// 每日经文。经文数据见 Generated/DailyVerseData.swift（由脚本从内置圣经生成）。
public struct DailyVerse: Hashable, Sendable {
    public let reference: BibleReference
    public let chinese: String
    public let english: String

    public init(reference: BibleReference, chinese: String, english: String) {
        self.reference = reference
        self.chinese = chinese
        self.english = english
    }

    public func text(_ language: Language) -> String {
        language == .chinese ? chinese : english
    }

    /// 某一天的经文。`shift` 用于「换一节」：在当天经文的基础上往后挪。
    public static func forDay(_ day: DayKey, shift: Int = 0) -> DailyVerse {
        let count = all.count
        let index = ((day.epochDay + shift) % count + count) % count
        return all[index]
    }

    /// 用于分享的文字，例如：
    /// 耶和华是我的牧者，我必不至缺乏。
    /// ——诗篇 23:1（和合本）
    public func shareText(_ language: Language) -> String {
        switch language {
        case .chinese: return "\(chinese)\n——\(reference.formatted(.chinese))（和合本）"
        case .english: return "\(english)\n— \(reference.formatted(.english)) (KJV)"
        }
    }
}
