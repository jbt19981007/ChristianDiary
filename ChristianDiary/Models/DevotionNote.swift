import Foundation
import SwiftData
import DevotionCore

/// 灵修笔记（SwiftData 模型）。
///
/// 为了以后能直接打开 iCloud（CloudKit）同步：所有属性都有默认值、
/// 不使用唯一约束。日期用 "YYYY-MM-DD" 字符串存储（见 DayKey）。
@Model
final class DevotionNote {
    var uuid: UUID = UUID()
    var dayString: String = ""
    var templateRaw: String = "soap"
    var title: String = ""
    var scriptureReference: String = ""
    var scriptureText: String = ""
    var body: String = ""
    var observation: String = ""
    var application: String = ""
    var prayer: String = ""
    var gratitude: String = ""
    var adoration: String = ""
    var confession: String = ""
    var supplication: String = ""
    var tags: [String] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(record: NoteRecord) {
        uuid = record.id
        dayString = record.day.string
        templateRaw = record.template.rawValue
        title = record.title
        scriptureReference = record.scriptureReference
        scriptureText = record.scriptureText
        body = record.body
        observation = record.observation
        application = record.application
        prayer = record.prayer
        gratitude = record.gratitude
        adoration = record.adoration
        confession = record.confession
        supplication = record.supplication
        tags = record.tags
        createdAt = record.createdAt
        updatedAt = record.updatedAt
    }

    var day: DayKey {
        DayKey(dayString) ?? DayKey(date: createdAt)
    }

    var template: NoteTemplate {
        NoteTemplate(rawValue: templateRaw) ?? .soap
    }

    var record: NoteRecord {
        var record = NoteRecord(
            id: uuid,
            day: day,
            template: template,
            title: title,
            scriptureReference: scriptureReference,
            scriptureText: scriptureText,
            tags: tags,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        record.body = body
        record.observation = observation
        record.application = application
        record.prayer = prayer
        record.gratitude = gratitude
        record.adoration = adoration
        record.confession = confession
        record.supplication = supplication
        return record
    }

    func apply(_ record: NoteRecord) {
        dayString = record.day.string
        templateRaw = record.template.rawValue
        title = record.title
        scriptureReference = record.scriptureReference
        scriptureText = record.scriptureText
        body = record.body
        observation = record.observation
        application = record.application
        prayer = record.prayer
        gratitude = record.gratitude
        adoration = record.adoration
        confession = record.confession
        supplication = record.supplication
        tags = record.tags
        createdAt = record.createdAt
        updatedAt = record.updatedAt
    }
}
