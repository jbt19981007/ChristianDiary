import SwiftUI
import SwiftData

@main
struct ChristianDiaryApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        // 数据保存在本机。以后在 Xcode 里为 App 打开 iCloud（CloudKit）能力后，
        // SwiftData 会自动通过 iCloud 同步，不需要修改代码。
        .modelContainer(for: [DevotionNote.self, PrayerItem.self])
    }
}
