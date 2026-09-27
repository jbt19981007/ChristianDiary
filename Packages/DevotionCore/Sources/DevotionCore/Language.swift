/// App 支持的界面 / 经文语言。
public enum Language: String, CaseIterable, Codable, Sendable {
    case chinese = "zh"
    case english = "en"

    /// 根据系统首选语言推断：中文系统用中文，其余用英文。
    public static func preferred(from preferredLanguages: [String]) -> Language {
        guard let first = preferredLanguages.first?.lowercased() else { return .chinese }
        return first.hasPrefix("zh") ? .chinese : .english
    }

    /// 在中英文之间选一个字符串。
    public func pick(_ chinese: String, _ english: String) -> String {
        self == .chinese ? chinese : english
    }
}
