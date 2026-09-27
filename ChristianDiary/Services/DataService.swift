import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import DevotionCore

/// 备份、恢复、导出与清除数据。
@MainActor
enum DataService {
    struct RestoreSummary {
        var notesAdded = 0
        var notesUpdated = 0
        var prayersAdded = 0
        var prayersUpdated = 0

        func message(_ language: Language) -> String {
            language.pick(
                "恢复完成：新增 \(notesAdded) 篇笔记、\(prayersAdded) 条代祷，更新 \(notesUpdated + prayersUpdated) 条。",
                "Restored: \(notesAdded) new notes, \(prayersAdded) new prayers, \(notesUpdated + prayersUpdated) updated."
            )
        }
    }

    static func allNotes(_ context: ModelContext) throws -> [DevotionNote] {
        try context.fetch(FetchDescriptor<DevotionNote>())
    }

    static func allPrayers(_ context: ModelContext) throws -> [PrayerItem] {
        try context.fetch(FetchDescriptor<PrayerItem>())
    }

    static func backupData(_ context: ModelContext) throws -> Data {
        let file = BackupFile(
            notes: try allNotes(context).map(\.record).sorted(by: noteSortOrder),
            prayers: try allPrayers(context).map(\.record).sorted { $0.createdAt > $1.createdAt }
        )
        return try BackupCodec.encode(file)
    }

    /// 合并恢复：本机没有的记录新增；同一条记录保留较新的版本。
    static func restore(_ data: Data, into context: ModelContext) throws -> RestoreSummary {
        let file = try BackupCodec.decode(data)
        var summary = RestoreSummary()

        let notes = try allNotes(context)
        let noteIndex = Dictionary(notes.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
        let notePlan = MergePlan(incoming: file.notes, existing: noteIndex.mapValues(\.updatedAt))
        for record in notePlan.inserts {
            context.insert(DevotionNote(record: record))
        }
        for record in notePlan.updates {
            noteIndex[record.id]?.apply(record)
        }
        summary.notesAdded = notePlan.inserts.count
        summary.notesUpdated = notePlan.updates.count

        let prayers = try allPrayers(context)
        let prayerIndex = Dictionary(prayers.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
        let prayerPlan = MergePlan(incoming: file.prayers, existing: prayerIndex.mapValues(\.updatedAt))
        for record in prayerPlan.inserts {
            context.insert(PrayerItem(record: record))
        }
        for record in prayerPlan.updates {
            prayerIndex[record.id]?.apply(record)
        }
        summary.prayersAdded = prayerPlan.inserts.count
        summary.prayersUpdated = prayerPlan.updates.count

        try context.save()
        return summary
    }

    static func markdown(_ context: ModelContext, language: Language) throws -> String {
        MarkdownExporter.export(notes: try allNotes(context).map(\.record), language: language, exportedOn: .today())
    }

    static func eraseAll(_ context: ModelContext) throws {
        for note in try allNotes(context) {
            context.delete(note)
        }
        for prayer in try allPrayers(context) {
            context.delete(prayer)
        }
        try context.save()
    }
}

/// 用于「导出到文件」的文档。
struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .plainText, .markdownText] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

extension UTType {
    static let markdownText = UTType(filenameExtension: "md", conformingTo: .plainText) ?? .plainText
}
