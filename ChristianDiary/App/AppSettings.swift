import SwiftUI
import DevotionCore

/// UserDefaults（@AppStorage）里保存的设置项。
enum SettingsKey {
    static let language = "settings.language"
    static let appearance = "settings.appearance"
    static let bibleDisplay = "settings.bibleDisplay"
    static let bibleFontSize = "settings.bibleFontSize"
    static let userName = "settings.userName"
    static let reminderEnabled = "settings.reminderEnabled"
    /// 提醒时间：从 0 点起的分钟数
    static let reminderMinutes = "settings.reminderMinutes"
    static let lockEnabled = "settings.lockEnabled"
    /// 上次导出备份的时间（timeIntervalSince1970，0 表示从未备份）
    static let lastBackup = "settings.lastBackup"
    static let lastTemplate = "settings.lastTemplate"
    static let bibleBook = "bible.book"
    static let bibleChapter = "bible.chapter"
}

enum LanguageSetting: String, CaseIterable, Identifiable {
    case system, chinese, english

    var id: String { rawValue }

    var resolved: Language {
        switch self {
        case .system: return Language.preferred(from: Locale.preferredLanguages)
        case .chinese: return .chinese
        case .english: return .english
        }
    }

    func label(_ language: Language) -> String {
        switch self {
        case .system: return language.pick("跟随系统", "System")
        case .chinese: return "简体中文"
        case .english: return "English"
        }
    }
}

enum AppearanceSetting: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    func label(_ language: Language) -> String {
        switch self {
        case .system: return language.pick("跟随系统", "System")
        case .light: return language.pick("浅色", "Light")
        case .dark: return language.pick("深色", "Dark")
        }
    }
}

/// 圣经与经文的显示方式。
enum BibleDisplay: String, CaseIterable, Identifiable {
    case chinese, english, parallel

    var id: String { rawValue }

    func label(_ language: Language) -> String {
        switch self {
        case .chinese: return language.pick("和合本", "Chinese (CUV)")
        case .english: return "KJV"
        case .parallel: return language.pick("中英对照", "Parallel")
        }
    }

    var translations: [BibleTranslation] {
        switch self {
        case .chinese: return [.cuv]
        case .english: return [.kjv]
        case .parallel: return [.cuv, .kjv]
        }
    }

    /// 界面语言对应的默认显示方式
    static func `default`(for language: Language) -> BibleDisplay {
        language == .chinese ? .chinese : .english
    }
}

// MARK: - 界面语言（通过 Environment 传递，切换后所有界面立即刷新）

private struct AppLanguageKey: EnvironmentKey {
    static let defaultValue: Language = .chinese
}

extension EnvironmentValues {
    var appLanguage: Language {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }
}

extension Language {
    var locale: Locale {
        Locale(identifier: self == .chinese ? "zh-Hans" : "en")
    }
}

// MARK: - 标签页导航

enum AppTab: Hashable {
    case today, bible, notes, prayers, me
}

@Observable
final class AppRouter {
    var selectedTab: AppTab = .today
}
