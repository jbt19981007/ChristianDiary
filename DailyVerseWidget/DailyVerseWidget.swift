import WidgetKit
import UIKit
import SwiftUI
import DevotionCore

// 每日经文小组件：主屏幕（小 / 中 / 大）与锁屏（矩形 / 单行）。
// 经文数据编译在 DevotionCore 里，不需要与 App 共享数据（不需要 App Group）。

struct VerseEntry: TimelineEntry {
    let date: Date
    let verse: DailyVerse
    let language: Language
}

struct VerseProvider: TimelineProvider {
    func placeholder(in context: Context) -> VerseEntry {
        entry(for: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (VerseEntry) -> Void) {
        completion(entry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VerseEntry>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        // 今天和之后两天的零点各一条，零点准时换经文
        let entries = [entry(for: now)] + (1...2).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startOfToday).map { entry(for: $0) }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(for date: Date) -> VerseEntry {
        VerseEntry(date: date,
                   verse: DailyVerse.forDay(DayKey(date: date)),
                   language: Language.preferred(from: Locale.preferredLanguages))
    }
}

struct DailyVerseWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: VerseEntry

    private var lang: Language { entry.language }
    private var reference: String { entry.verse.reference.formatted(lang) }
    private var text: String { entry.verse.text(lang) }

    var body: some View {
        switch family {
        case .accessoryInline:
            Label(reference, systemImage: "book")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(reference)
                    .font(.headline)
                    .widgetAccentable()
                Text(text)
                    .font(.caption)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .systemSmall:
            VStack(alignment: .leading, spacing: 6) {
                header
                Text(text)
                    .font(.system(size: 14, design: .serif))
                    .foregroundStyle(WidgetTheme.ink)
                    .lineSpacing(3)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
                referenceText
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case .systemLarge:
            VStack(alignment: .leading, spacing: 12) {
                header
                Text(text)
                    .font(.system(size: 22, design: .serif))
                    .foregroundStyle(WidgetTheme.ink)
                    .lineSpacing(6)
                    .minimumScaleFactor(0.7)
                Text(entry.verse.text(lang == .chinese ? .english : .chinese))
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(WidgetTheme.inkSecondary)
                    .lineSpacing(3)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                referenceText
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        default:
            VStack(alignment: .leading, spacing: 8) {
                header
                Text(text)
                    .font(.system(size: 17, design: .serif))
                    .foregroundStyle(WidgetTheme.ink)
                    .lineSpacing(4)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                referenceText
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var header: some View {
        Label(lang.pick("今日经文", "Verse of the Day"), systemImage: "sparkles")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(WidgetTheme.accent)
    }

    private var referenceText: some View {
        Text(reference)
            .font(.caption.weight(.semibold))
            .foregroundStyle(WidgetTheme.accent)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

struct DailyVerseWidget: Widget {
    private let kind = "DailyVerseWidget"
    private var lang: Language { Language.preferred(from: Locale.preferredLanguages) }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VerseProvider()) { entry in
            DailyVerseWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetTheme.paper }
        }
        .configurationDisplayName(Text(lang.pick("每日经文", "Verse of the Day")))
        .description(Text(lang.pick("每天一节经文，和合本 / KJV。", "A verse each day from the Bible.")))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct DailyVerseWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyVerseWidget()
    }
}

/// 小组件使用的配色（与 App 的温暖纸张风一致）。
enum WidgetTheme {
    static let paper = Color(light: 0xF6F1E9, dark: 0x1D1A16)
    static let ink = Color(light: 0x2A241F, dark: 0xEEE7DD)
    static let inkSecondary = Color(light: 0x6F6358, dark: 0xA89D90)
    static let accent = Color(light: 0x9A6431, dark: 0xD9A66B)
}

private extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                           green: CGFloat((rgb >> 8) & 0xFF) / 255,
                           blue: CGFloat(rgb & 0xFF) / 255,
                           alpha: 1)
        })
    }
}

#Preview(as: .systemMedium) {
    DailyVerseWidget()
} timeline: {
    VerseEntry(date: .now, verse: DailyVerse.all[0], language: .chinese)
    VerseEntry(date: .now, verse: DailyVerse.all[1], language: .english)
}
