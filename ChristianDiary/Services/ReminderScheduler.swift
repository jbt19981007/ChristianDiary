import Foundation
import UserNotifications
import DevotionCore

/// 每日灵修提醒（本地通知）。
///
/// 每条通知的内容都是当天的经文，所以不用重复通知，而是一次排好接下来 60 天
/// （系统最多允许 64 条待发通知）。每次打开 App 都会重新排一次。
enum ReminderScheduler {
    private static let identifierPrefix = "daily-devotion-"
    private static let daysAhead = 60

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// 请求通知权限，返回是否获得授权。
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func reschedule(enabled: Bool, minutesAfterMidnight: Int, language: Language) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        )
        guard enabled else { return }

        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        let hour = minutesAfterMidnight / 60
        let minute = minutesAfterMidnight % 60
        let today = DayKey.today()
        let calendar = Calendar.current
        let now = Date()

        for offset in 0..<daysAhead {
            let day = today.adding(days: offset)
            var components = DateComponents(year: day.year, month: day.month, day: day.day, hour: hour, minute: minute)
            components.calendar = calendar
            if let fireDate = calendar.date(from: components), fireDate <= now { continue }

            let verse = DailyVerse.forDay(day)
            let content = UNMutableNotificationContent()
            content.title = language.pick("今日灵修", "Daily Devotion")
            content.body = "\(verse.text(language))\n—— \(verse.reference.formatted(language))"
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: identifierPrefix + day.string, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    static func timeLabel(minutesAfterMidnight: Int) -> String {
        String(format: "%02d:%02d", minutesAfterMidnight / 60, minutesAfterMidnight % 60)
    }
}
