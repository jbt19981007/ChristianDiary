import Foundation
import SwiftData
import DevotionCore

/// 代祷事项（SwiftData 模型），同样按 CloudKit 兼容的方式设计。
@Model
final class PrayerItem {
    var uuid: UUID = UUID()
    var title: String = ""
    var forWhom: String = ""
    var detail: String = ""
    var statusRaw: String = "praying"
    var startDayString: String = ""
    var answeredDayString: String?
    var answerNote: String = ""
    var prayedCount: Int = 0
    var lastPrayedDayString: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(record: PrayerRecord) {
        uuid = record.id
        title = record.title
        forWhom = record.forWhom
        detail = record.detail
        statusRaw = record.status.rawValue
        startDayString = record.startDay.string
        answeredDayString = record.answeredDay?.string
        answerNote = record.answerNote
        prayedCount = record.prayedCount
        lastPrayedDayString = record.lastPrayedDay?.string
        createdAt = record.createdAt
        updatedAt = record.updatedAt
    }

    var status: PrayerStatus {
        PrayerStatus(rawValue: statusRaw) ?? .praying
    }

    var startDay: DayKey {
        DayKey(startDayString) ?? DayKey(date: createdAt)
    }

    var answeredDay: DayKey? {
        answeredDayString.flatMap { DayKey($0) }
    }

    func hasPrayed(on day: DayKey) -> Bool {
        lastPrayedDayString == day.string
    }

    /// 「今天已为此祷告」，同一天只计一次。
    func markPrayed(on day: DayKey) {
        guard !hasPrayed(on: day) else { return }
        prayedCount += 1
        lastPrayedDayString = day.string
        updatedAt = Date()
    }

    func markAnswered(on day: DayKey, note: String) {
        statusRaw = PrayerStatus.answered.rawValue
        answeredDayString = day.string
        answerNote = note
        updatedAt = Date()
    }

    func reopen() {
        statusRaw = PrayerStatus.praying.rawValue
        answeredDayString = nil
        updatedAt = Date()
    }

    var record: PrayerRecord {
        PrayerRecord(
            id: uuid,
            title: title,
            forWhom: forWhom,
            detail: detail,
            status: status,
            startDay: startDay,
            answeredDay: answeredDay,
            answerNote: answerNote,
            prayedCount: prayedCount,
            lastPrayedDay: lastPrayedDayString.flatMap { DayKey($0) },
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func apply(_ record: PrayerRecord) {
        title = record.title
        forWhom = record.forWhom
        detail = record.detail
        statusRaw = record.status.rawValue
        startDayString = record.startDay.string
        answeredDayString = record.answeredDay?.string
        answerNote = record.answerNote
        prayedCount = record.prayedCount
        lastPrayedDayString = record.lastPrayedDay?.string
        createdAt = record.createdAt
        updatedAt = record.updatedAt
    }
}
