import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import DevotionCore

/// 「我的」：统计、提醒、隐私、外观、数据备份。
struct SettingsView: View {
    @Environment(\.appLanguage) private var lang
    @Environment(\.modelContext) private var context
    @Query private var notes: [DevotionNote]
    @Query private var prayers: [PrayerItem]

    @AppStorage(SettingsKey.userName) private var userName = ""
    @AppStorage(SettingsKey.language) private var languageSetting = LanguageSetting.system
    @AppStorage(SettingsKey.appearance) private var appearance = AppearanceSetting.system
    @AppStorage(SettingsKey.bibleDisplay) private var bibleDisplayRaw = ""
    @AppStorage(SettingsKey.reminderEnabled) private var reminderEnabled = false
    @AppStorage(SettingsKey.reminderMinutes) private var reminderMinutes = 7 * 60
    @AppStorage(SettingsKey.lockEnabled) private var lockEnabled = false
    @AppStorage(SettingsKey.lastBackup) private var lastBackup: Double = 0

    @State private var notificationsDenied = false
    @State private var exportDocument: ExportDocument?
    @State private var exportType: UTType = .json
    @State private var exportFilename = ""
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var alertMessage: String?
    @State private var confirmingErase = false

    var body: some View {
        NavigationStack {
            Form {
                statsSection
                profileSection
                reminderSection
                privacySection
                appearanceSection
                dataSection
                eraseSection
                aboutSection
            }
            .paperList()
            .navigationTitle(lang.pick("我的", "Me"))
            .fileExporter(isPresented: $showingExporter, document: exportDocument,
                          contentType: exportType, defaultFilename: exportFilename) { result in
                switch result {
                case .success:
                    if exportType == .json { lastBackup = Date().timeIntervalSince1970 }
                case .failure(let error):
                    alertMessage = lang.pick("导出失败：", "Export failed: ") + error.localizedDescription
                }
            }
            .confirmationDialog(lang.pick("确定清除所有数据吗？", "Erase all data?"),
                                isPresented: $confirmingErase, titleVisibility: .visible) {
                Button(lang.pick("全部清除", "Erase everything"), role: .destructive, action: eraseAll)
            } message: {
                Text(lang.pick("这会永久删除这台 iPhone 上的所有灵修笔记和代祷事项，无法恢复。建议先导出备份。",
                               "This permanently deletes all entries and prayer requests on this iPhone. Export a backup first."))
            }
        }
        // fileImporter 与 fileExporter 放在不同的视图上，避免同一视图上互相冲突
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): restore(from: url)
            case .failure(let error): alertMessage = error.localizedDescription
            }
        }
        .alert(alertMessage ?? "", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button(lang.pick("好", "OK"), role: .cancel) {}
        }
        .task { await refreshNotificationStatus() }
        .onChange(of: languageSetting) { _, _ in
            Task { await rescheduleReminders() }
        }
    }

    // MARK: - 统计

    private var statsSection: some View {
        let days = Set(notes.map(\.day))
        let current = DevotionStats.currentStreak(days: days, today: .today())
        let longest = DevotionStats.longestStreak(days: days)
        let answered = prayers.filter { $0.status == .answered }.count
        return Section {
            LabeledContent(lang.pick("灵修天数", "Days with devotions"), value: "\(days.count)")
            LabeledContent(lang.pick("笔记篇数", "Entries"), value: "\(notes.count)")
            LabeledContent(lang.pick("当前连续", "Current streak"), value: lang.pick("\(current) 天", "\(current) days"))
            LabeledContent(lang.pick("最长连续", "Longest streak"), value: lang.pick("\(longest) 天", "\(longest) days"))
            LabeledContent(lang.pick("蒙应允的祷告", "Answered prayers"), value: "\(answered)")
        } header: {
            Text(lang.pick("我的灵修", "My Journey"))
        }
    }

    private var profileSection: some View {
        Section {
            TextField(lang.pick("你的称呼（用于首页问候）", "Your name (for greetings)"), text: $userName)
        } header: {
            Text(lang.pick("个人", "Profile"))
        }
    }

    // MARK: - 提醒

    private var reminderSection: some View {
        Section {
            Toggle(lang.pick("每日灵修提醒", "Daily reminder"),
                   isOn: Binding(get: { reminderEnabled }, set: { newValue in Task { await setReminder(newValue) } }))
            if reminderEnabled {
                DatePicker(lang.pick("提醒时间", "Time"), selection: reminderTime, displayedComponents: .hourAndMinute)
            }
        } header: {
            Text(lang.pick("提醒", "Reminder"))
        } footer: {
            if notificationsDenied {
                Text(lang.pick("通知权限已关闭，请到 iPhone「设置 › 通知 › 灵修笔记」中打开。",
                               "Notifications are off. Turn them on in Settings › Notifications."))
            } else {
                Text(lang.pick("每天在设定的时间收到当天的经文。", "Receive today's verse at the time you choose."))
            }
        }
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60,
                                      second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                reminderMinutes = (parts.hour ?? 7) * 60 + (parts.minute ?? 0)
                Task { await rescheduleReminders() }
            }
        )
    }

    private func setReminder(_ enabled: Bool) async {
        if enabled {
            let granted = await ReminderScheduler.requestAuthorization()
            notificationsDenied = !granted
            reminderEnabled = granted
        } else {
            reminderEnabled = false
        }
        await rescheduleReminders()
    }

    private func rescheduleReminders() async {
        await ReminderScheduler.reschedule(enabled: reminderEnabled, minutesAfterMidnight: reminderMinutes,
                                           language: languageSetting.resolved)
    }

    private func refreshNotificationStatus() async {
        let status = await ReminderScheduler.authorizationStatus()
        notificationsDenied = status == .denied
        if status == .denied, reminderEnabled {
            reminderEnabled = false
        }
    }

    // MARK: - 隐私

    private var privacySection: some View {
        Section {
            Toggle(lang.pick("使用 \(AppLock.methodName(lang)) 锁定", "Lock with \(AppLock.methodName(lang))"),
                   isOn: Binding(get: { lockEnabled }, set: { newValue in Task { await setLock(newValue) } }))
                .disabled(!AppLock.isAvailable && !lockEnabled)
        } header: {
            Text(lang.pick("隐私", "Privacy"))
        } footer: {
            Text(AppLock.isAvailable
                 ? lang.pick("打开 App 时需要验证身份；切到后台时自动隐藏内容。",
                             "Require authentication to open the app, and hide content in the app switcher.")
                 : lang.pick("这台设备没有设置锁屏密码，无法使用 App 锁。", "Set a device passcode to use app lock."))
        }
    }

    private func setLock(_ enabled: Bool) async {
        if enabled {
            lockEnabled = await AppLock.confirmIdentity(language: lang)
        } else {
            lockEnabled = false
        }
    }

    // MARK: - 外观

    private var appearanceSection: some View {
        Section {
            Picker(lang.pick("语言", "Language"), selection: $languageSetting) {
                ForEach(LanguageSetting.allCases) { Text($0.label(lang)).tag($0) }
            }
            Picker(lang.pick("外观", "Appearance"), selection: $appearance) {
                ForEach(AppearanceSetting.allCases) { Text($0.label(lang)).tag($0) }
            }
            Picker(lang.pick("经文显示", "Scripture"),
                   selection: Binding(get: { BibleDisplay.resolve(bibleDisplayRaw, language: lang) },
                                      set: { bibleDisplayRaw = $0.rawValue })) {
                ForEach(BibleDisplay.allCases) { Text($0.label(lang)).tag($0) }
            }
        } header: {
            Text(lang.pick("外观与语言", "Appearance & Language"))
        }
    }

    // MARK: - 数据

    private var dataSection: some View {
        Section {
            Button {
                export(kind: .json)
            } label: {
                Label(lang.pick("导出备份", "Export backup"), systemImage: "square.and.arrow.up")
            }
            Button {
                export(kind: .markdownText)
            } label: {
                Label(lang.pick("导出为 Markdown", "Export as Markdown"), systemImage: "doc.text")
            }
            Button {
                showingImporter = true
            } label: {
                Label(lang.pick("从备份恢复", "Restore from backup"), systemImage: "square.and.arrow.down")
            }
        } header: {
            Text(lang.pick("数据与备份", "Data & Backup"))
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text(lang.pick("所有内容只保存在这台 iPhone 上，不会上传到任何服务器。换手机或删除 App 前，请先导出备份，保存到「文件」、电脑或网盘。恢复时会与现有内容合并，不会覆盖。",
                               "Everything stays on this iPhone and is never uploaded. Export a backup before changing phones or deleting the app. Restoring merges with existing data."))
                Text(lastBackupText)
            }
        }
    }

    private var lastBackupText: String {
        guard lastBackup > 0 else { return lang.pick("还没有备份过。", "No backup yet.") }
        let day = DayKey(date: Date(timeIntervalSince1970: lastBackup))
        return lang.pick("上次备份：", "Last backup: ") + day.formatted(lang, weekday: false)
    }

    private func export(kind: UTType) {
        do {
            let today = DayKey.today().string
            if kind == .json {
                exportDocument = ExportDocument(data: try DataService.backupData(context))
                exportFilename = lang.pick("灵修笔记备份-", "devotion-backup-") + today
            } else {
                let markdown = try DataService.markdown(context, language: lang)
                exportDocument = ExportDocument(data: Data(markdown.utf8))
                exportFilename = lang.pick("灵修笔记-", "devotion-journal-") + today
            }
            exportType = kind
            showingExporter = true
        } catch {
            alertMessage = lang.pick("导出失败：", "Export failed: ") + error.localizedDescription
        }
    }

    private func restore(from url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let summary = try DataService.restore(data, into: context)
            alertMessage = summary.message(lang)
        } catch let error as BackupError {
            alertMessage = error.message(lang)
        } catch {
            alertMessage = lang.pick("恢复失败：", "Restore failed: ") + error.localizedDescription
        }
    }

    private var eraseSection: some View {
        Section {
            Button(role: .destructive) {
                confirmingErase = true
            } label: {
                Label(lang.pick("清除所有数据", "Erase all data"), systemImage: "trash")
            }
        }
    }

    private func eraseAll() {
        do {
            try DataService.eraseAll(context)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    // MARK: - 关于

    private var aboutSection: some View {
        Section {
            LabeledContent(lang.pick("版本", "Version"), value: appVersion)
            LabeledContent(lang.pick("中文圣经", "Chinese Bible"), value: lang.pick("和合本", "Chinese Union Version"))
            LabeledContent(lang.pick("英文圣经", "English Bible"), value: "King James Version")
            VStack(alignment: .leading, spacing: 6) {
                Text(lang.pick("「你的话是我脚前的灯，是我路上的光。」", "“Thy word is a lamp unto my feet, and a light unto my path.”"))
                    .font(Theme.scriptureBody)
                    .foregroundStyle(Theme.ink)
                Text(lang.pick("诗篇 119:105", "Psalm 119:105"))
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
            }
            .padding(.vertical, 4)
        } header: {
            Text(lang.pick("关于", "About"))
        } footer: {
            Text(lang.pick("内置经文为公有领域的和合本（1919）与英王钦定本 KJV。",
                           "Built-in scripture: Chinese Union Version (1919) and King James Version, both in the public domain."))
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
