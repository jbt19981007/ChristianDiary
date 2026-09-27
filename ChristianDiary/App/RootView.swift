import SwiftUI
import DevotionCore

struct RootView: View {
    @AppStorage(SettingsKey.language) private var languageSetting = LanguageSetting.system
    @AppStorage(SettingsKey.appearance) private var appearance = AppearanceSetting.system
    @AppStorage(SettingsKey.lockEnabled) private var lockEnabled = false
    @AppStorage(SettingsKey.reminderEnabled) private var reminderEnabled = false
    @AppStorage(SettingsKey.reminderMinutes) private var reminderMinutes = 7 * 60

    @Environment(\.scenePhase) private var scenePhase
    @State private var router = AppRouter()
    @State private var bible = BibleStore()
    @State private var lock = AppLock()
    @State private var didLaunch = false

    private var language: Language { languageSetting.resolved }

    var body: some View {
        TabView(selection: $router.selectedTab) {
            TodayView()
                .tabItem { Label(language.pick("今日", "Today"), systemImage: "sun.horizon") }
                .tag(AppTab.today)
            BibleView()
                .tabItem { Label(language.pick("圣经", "Bible"), systemImage: "book") }
                .tag(AppTab.bible)
            NotesView()
                .tabItem { Label(language.pick("笔记", "Journal"), systemImage: "square.and.pencil") }
                .tag(AppTab.notes)
            PrayersView()
                .tabItem { Label(language.pick("代祷", "Prayer"), systemImage: "hands.and.sparkles") }
                .tag(AppTab.prayers)
            SettingsView()
                .tabItem { Label(language.pick("我的", "Me"), systemImage: "person.crop.circle") }
                .tag(AppTab.me)
        }
        .tint(Theme.accent)
        .environment(\.appLanguage, language)
        .environment(\.locale, language.locale)
        .environment(router)
        .environment(bible)
        .environment(lock)
        .preferredColorScheme(appearance.colorScheme)
        .overlay {
            if lockEnabled && (lock.isLocked || scenePhase != .active) {
                LockScreen()
                    .environment(\.appLanguage, language)
                    .transition(.opacity)
            }
        }
        .onAppear {
            guard !didLaunch else { return }
            didLaunch = true
            if lockEnabled { lock.lock() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                if lockEnabled { lock.lock() }
            case .active:
                Task {
                    await ReminderScheduler.reschedule(enabled: reminderEnabled,
                                                       minutesAfterMidnight: reminderMinutes,
                                                       language: language)
                }
            default:
                break
            }
        }
        .task {
            // 预先在后台加载界面语言对应的圣经译本
            await bible.load(BibleTranslation.primary(for: language))
        }
    }
}

/// App 锁定时覆盖在最上层；切到后台时也显示，避免在多任务界面里露出笔记内容。
struct LockScreen: View {
    @Environment(\.appLanguage) private var lang
    @Environment(AppLock.self) private var lock
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.accent)
                Text(lang.pick("灵修笔记已锁定", "Journal Locked"))
                    .font(Theme.serifTitle)
                    .foregroundStyle(Theme.ink)
                Text(lang.pick("「你的话是我脚前的灯，是我路上的光。」", "“Thy word is a lamp unto my feet, and a light unto my path.”"))
                    .font(Theme.scriptureBody)
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                if lock.isLocked {
                    Button {
                        Task { await lock.unlock(language: lang) }
                    } label: {
                        Label(lang.pick("使用 \(AppLock.methodName(lang)) 解锁", "Unlock with \(AppLock.methodName(lang))"),
                              systemImage: "faceid")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: 280)
                    .padding(.top, 8)
                }
            }
        }
        .task(id: scenePhase) {
            if scenePhase == .active {
                await lock.autoUnlockIfNeeded(language: lang)
            }
        }
    }
}
