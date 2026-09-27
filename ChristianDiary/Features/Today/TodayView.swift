import SwiftUI
import SwiftData
import DevotionCore

struct TodayView: View {
    @Environment(\.appLanguage) private var lang
    @Environment(AppRouter.self) private var router
    @Query(sort: \DevotionNote.dayString, order: .reverse) private var notes: [DevotionNote]
    @Query(sort: \PrayerItem.createdAt, order: .reverse) private var prayers: [PrayerItem]
    @AppStorage(SettingsKey.userName) private var userName = ""
    @AppStorage(SettingsKey.lastBackup) private var lastBackup: Double = 0
    @AppStorage(SettingsKey.lastTemplate) private var lastTemplate = NoteTemplate.soap
    @AppStorage(SettingsKey.bibleDisplay) private var bibleDisplayRaw = ""

    @State private var verseShift = 0
    @State private var editorRequest: EditorRequest?

    private var today: DayKey { .today() }
    private var bibleDisplay: BibleDisplay { BibleDisplay.resolve(bibleDisplayRaw, language: lang) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(today.formatted(lang))
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                    statsRow
                    verseCard
                    devotionCard
                    prayerCard
                    backupReminder
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .paperBackground()
            .navigationTitle(greeting)
            .navigationDestination(for: DevotionNote.self) { NoteDetailView(note: $0) }
            .sheet(item: $editorRequest) { NoteEditorView(request: $0) }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let base: String
        switch hour {
        case 0..<5: base = lang.pick("夜深了", "Good night")
        case 5..<11: base = lang.pick("早安", "Good morning")
        case 11..<13: base = lang.pick("午安", "Good afternoon")
        case 13..<18: base = lang.pick("下午好", "Good afternoon")
        default: base = lang.pick("晚上好", "Good evening")
        }
        let name = userName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? base : base + lang.pick("，\(name)", ", \(name)")
    }

    // MARK: - 统计

    private var statsRow: some View {
        let days = Set(notes.map(\.day))
        return HStack(spacing: 12) {
            StatTile(value: DevotionStats.currentStreak(days: days, today: today),
                     label: lang.pick("连续灵修", "Day streak"), systemImage: "flame.fill")
            StatTile(value: DevotionStats.count(days: days, in: today.yearMonth),
                     label: lang.pick("本月天数", "This month"), systemImage: "calendar")
            StatTile(value: days.count, label: lang.pick("累计天数", "Total days"), systemImage: "leaf.fill")
        }
    }

    // MARK: - 每日经文

    private var verseCard: some View {
        let verse = DailyVerse.forDay(today, shift: verseShift)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                CardLabel(title: verseShift == 0 ? lang.pick("今日经文", "Verse of the Day") : lang.pick("经文", "Verse"),
                          systemImage: "sparkles")
                Spacer()
                Button {
                    withAnimation(.easeInOut) { verseShift += 1 }
                } label: {
                    Label(lang.pick("换一节", "Another"), systemImage: "arrow.triangle.2.circlepath")
                        .font(.footnote)
                }
                .buttonStyle(.borderless)
            }

            VStack(alignment: .leading, spacing: 10) {
                switch bibleDisplay {
                case .chinese:
                    verseText(verse.chinese)
                case .english:
                    verseText(verse.english)
                case .parallel:
                    verseText(verse.chinese)
                    Text(verse.english)
                        .font(Theme.scriptureBody)
                        .lineSpacing(4)
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
            .id(verse.reference)
            .transition(.opacity)

            Text(verse.reference.formatted(lang))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity, alignment: .trailing)

            HStack(spacing: 10) {
                Button {
                    editorRequest = .new(day: today, template: lastTemplate,
                                         reference: verse.reference.formatted(lang),
                                         text: quote(verse))
                } label: {
                    Label(lang.pick("用这节经文灵修", "Reflect on this"), systemImage: "square.and.pencil")
                }
                .buttonStyle(SoftButtonStyle())

                ShareLink(item: verse.shareText(lang)) {
                    Label(lang.pick("分享", "Share"), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(SoftButtonStyle(tint: Theme.inkSecondary, background: Theme.cardMuted))
            }
        }
        .card()
    }

    private func verseText(_ text: String) -> some View {
        Text(text)
            .font(Theme.scripture(size: 20))
            .lineSpacing(8)
            .foregroundStyle(Theme.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func quote(_ verse: DailyVerse) -> String {
        switch bibleDisplay {
        case .chinese: return verse.chinese
        case .english: return verse.english
        case .parallel: return verse.chinese + "\n" + verse.english
        }
    }

    // MARK: - 今日灵修

    private var devotionCard: some View {
        let todays = notes.filter { $0.dayString == today.string }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                CardLabel(title: lang.pick("今日灵修", "Today's Devotion"), systemImage: "book.closed")
                Spacer()
                if !todays.isEmpty {
                    Label(lang.pick("已完成", "Done"), systemImage: "checkmark.seal.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.green)
                }
            }
            if todays.isEmpty {
                Text(lang.pick("安静片刻，读一段经文，写下神对你说的话。",
                               "Take a quiet moment, read a passage, and write down what God is saying to you."))
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                Button {
                    editorRequest = .new(day: today, template: lastTemplate)
                } label: {
                    Label(lang.pick("开始今天的灵修", "Start today's devotion"), systemImage: "pencil.line")
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                ForEach(todays) { note in
                    NavigationLink(value: note) {
                        NoteRow(note: note, showsDate: false)
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    editorRequest = .new(day: today, template: lastTemplate)
                } label: {
                    Label(lang.pick("再写一篇", "Write another"), systemImage: "plus")
                        .font(.subheadline)
                }
                .buttonStyle(.borderless)
            }
        }
        .card()
    }

    // MARK: - 代祷

    private var prayerCard: some View {
        let praying = prayers.filter { $0.status == .praying }
        let answeredCount = prayers.count - praying.count
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                CardLabel(title: lang.pick("代祷", "Prayer List"), systemImage: "hands.and.sparkles")
                Spacer()
                Button(lang.pick("全部", "All")) { router.selectedTab = .prayers }
                    .font(.footnote)
                    .buttonStyle(.borderless)
            }
            if praying.isEmpty {
                Text(lang.pick("把挂念的人和事带到神面前。", "Bring the people and needs on your heart to God."))
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                Button(lang.pick("添加代祷事项", "Add a prayer request")) { router.selectedTab = .prayers }
                    .buttonStyle(SoftButtonStyle())
            } else {
                ForEach(praying.prefix(3)) { item in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.body.weight(.medium))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            if !item.forWhom.isEmpty {
                                Text(item.forWhom)
                                    .font(.caption)
                                    .foregroundStyle(Theme.inkSecondary)
                            }
                        }
                        Spacer()
                        PrayedButton(item: item)
                    }
                }
                if praying.count > 3 {
                    Text(lang.pick("还有 \(praying.count - 3) 项", "\(praying.count - 3) more"))
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
            if answeredCount > 0 {
                Label(lang.pick("神已应允 \(answeredCount) 个祷告", "\(answeredCount) answered prayers"), systemImage: "sparkles")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.green)
            }
        }
        .card()
    }

    // MARK: - 备份提醒

    @ViewBuilder
    private var backupReminder: some View {
        let stale = lastBackup == 0 || Date().timeIntervalSince1970 - lastBackup > 30 * 86_400
        if notes.count >= 5 && stale {
            VStack(alignment: .leading, spacing: 10) {
                CardLabel(title: lang.pick("记得备份", "Remember to back up"), systemImage: "externaldrive")
                Text(lang.pick("笔记只保存在这台 iPhone 上。你已经写了 \(notes.count) 篇，建议导出一份备份，存到「文件」或电脑里。",
                               "Your notes are stored only on this iPhone. You've written \(notes.count) entries — export a backup to Files or your computer."))
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                Button(lang.pick("去备份", "Back up now")) { router.selectedTab = .me }
                    .buttonStyle(SoftButtonStyle())
            }
            .card()
        }
    }
}

struct StatTile: View {
    let value: Int
    let label: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: systemImage)
                .font(.footnote)
                .foregroundStyle(Theme.accent)
            Text(value, format: .number)
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .card(padding: 12)
    }
}

/// 「为此祷告」按钮：每天只能计一次。
struct PrayedButton: View {
    let item: PrayerItem
    @Environment(\.appLanguage) private var lang
    @Environment(\.modelContext) private var context

    var body: some View {
        let today = DayKey.today()
        let done = item.hasPrayed(on: today)
        Button {
            withAnimation {
                item.markPrayed(on: today)
                try? context.save()
            }
        } label: {
            Label(done ? lang.pick("今日已代祷", "Prayed") : lang.pick("为此祷告", "Pray"),
                  systemImage: done ? "checkmark" : "hands.sparkles")
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
        }
        .buttonStyle(SoftButtonStyle(tint: done ? Theme.green : Theme.accent,
                                     background: done ? Theme.greenSoft : Theme.accentSoft))
        .disabled(done)
    }
}

extension BibleDisplay {
    /// 读取设置；从未设置过时按界面语言决定。
    static func resolve(_ raw: String, language: Language) -> BibleDisplay {
        BibleDisplay(rawValue: raw) ?? .default(for: language)
    }
}
