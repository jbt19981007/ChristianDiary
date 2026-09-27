import XCTest
@testable import DevotionCore

final class NoteRecordTests: XCTestCase {
    private let day = DayKey(year: 2026, month: 9, day: 27)

    func testTemplatesCoverFields() {
        for template in NoteTemplate.allCases {
            XCTAssertFalse(template.fields.isEmpty)
            XCTAssertFalse(template.name(.chinese).isEmpty)
            XCTAssertFalse(template.name(.english).isEmpty)
            for field in template.fields {
                XCTAssertFalse(field.label(.chinese, in: template).isEmpty)
                XCTAssertFalse(field.placeholder(.english, in: template).isEmpty)
            }
        }
        XCTAssertEqual(Set(NoteTemplate.allCases.flatMap(\.fields)), Set(NoteField.allCases), "每个栏目都属于某个模板")
    }

    func testSubscriptReadsAndWritesEveryField() {
        var note = NoteRecord(day: day)
        for field in NoteField.allCases {
            note[field] = field.rawValue
        }
        for field in NoteField.allCases {
            XCTAssertEqual(note[field], field.rawValue)
        }
    }

    func testHasContent() {
        var note = NoteRecord(day: day)
        XCTAssertFalse(note.hasContent)
        note.prayer = "   \n "
        XCTAssertFalse(note.hasContent, "只有空白不算内容")
        note.prayer = "主啊"
        XCTAssertTrue(note.hasContent)
        XCTAssertTrue(NoteRecord(day: day, tags: ["信心"]).hasContent)
    }

    func testHeadlineAndSnippet() {
        var note = NoteRecord(day: day, template: .soap)
        XCTAssertEqual(note.headline(.chinese), "SOAP 灵修")
        note.observation = "神是信实的\n第二行"
        note.application = "今天要饶恕人"
        XCTAssertEqual(note.headline(.chinese), "神是信实的", "没有标题和经文时用第一栏的第一行")
        XCTAssertEqual(note.snippet(), "今天要饶恕人", "摘要不重复标题所用的栏目")
        note.scriptureReference = "约翰福音 3:16"
        XCTAssertEqual(note.headline(.chinese), "约翰福音 3:16")
        XCTAssertEqual(note.snippet(), "神是信实的 第二行")
        note.title = "  神爱世人 "
        XCTAssertEqual(note.headline(.english), "神爱世人")
        XCTAssertEqual(String(repeating: "长", count: 200).count, 200)
        note.observation = String(repeating: "长", count: 200)
        XCTAssertEqual(note.snippet(maxLength: 10), String(repeating: "长", count: 10) + "…")
    }

    func testVisibleFieldsKeepContentFromOtherTemplates() {
        var note = NoteRecord(day: day, template: .soap)
        note.prayer = "祷告"
        note.observation = "观察"
        note.gratitude = "感恩"
        XCTAssertEqual(note.visibleFields, [.observation, .prayer, .gratitude])
        note.template = .gratitude
        XCTAssertEqual(note.visibleFields, [.gratitude, .prayer, .observation])
    }

    func testHasSameContentIgnoresTimestamps() {
        var a = NoteRecord(day: day, title: "标题", createdAt: Date(timeIntervalSince1970: 0))
        var b = a
        b.id = UUID()
        b.updatedAt = Date()
        XCTAssertTrue(a.hasSameContent(as: b))
        b.prayer = "新的祷告"
        XCTAssertFalse(a.hasSameContent(as: b))
        a.prayer = "新的祷告"
        a.tags = ["信心"]
        XCTAssertFalse(a.hasSameContent(as: b))
    }

    func testSearchMatchesAllTextAndTags() {
        var note = NoteRecord(day: day, scriptureReference: "诗篇 23:1", tags: ["平安"])
        note.supplication = "Pray for my Family"
        XCTAssertTrue(note.matches("诗篇"))
        XCTAssertTrue(note.matches("family"))
        XCTAssertTrue(note.matches("平安"))
        XCTAssertTrue(note.matches("  "))
        XCTAssertFalse(note.matches("启示录"))
    }

    func testPlainText() {
        var note = NoteRecord(day: day, template: .soap, title: "主是我的牧者", scriptureReference: "诗篇 23:1",
                              scriptureText: "耶和华是我的牧者，我必不至缺乏。", tags: ["信心", "平安"])
        note.observation = "神看顾我"
        note.prayer = "感谢主"
        XCTAssertEqual(note.plainText(.chinese), """
        2026年9月27日 星期日
        主是我的牧者

        【经文】诗篇 23:1
        耶和华是我的牧者，我必不至缺乏。

        【观察】
        神看顾我

        【祷告】
        感谢主

        #信心 #平安
        """)
    }

    func testDecodingToleratesMissingFields() throws {
        let json = #"{"id":"5A3C1E2B-8E5B-4B8B-9E36-2B0C8D1E4F10","day":"2026-09-27","observation":"亮光","tags":["a","a"," b "]}"#
        let note = try JSONDecoder().decode(NoteRecord.self, from: Data(json.utf8))
        XCTAssertEqual(note.template, .soap)
        XCTAssertEqual(note.observation, "亮光")
        XCTAssertEqual(note.title, "")
        XCTAssertEqual(note.tags, ["a", "b"])
        XCTAssertEqual(note.updatedAt, note.createdAt)
    }
}

final class StatsAndTagsTests: XCTestCase {
    private func days(_ values: [String]) -> Set<DayKey> {
        Set(values.compactMap(DayKey.init))
    }

    func testCurrentStreak() throws {
        let today = try XCTUnwrap(DayKey("2026-09-27"))
        XCTAssertEqual(DevotionStats.currentStreak(days: [], today: today), 0)
        XCTAssertEqual(DevotionStats.currentStreak(days: days(["2026-09-25", "2026-09-26", "2026-09-27"]), today: today), 3)
        XCTAssertEqual(DevotionStats.currentStreak(days: days(["2026-09-25", "2026-09-26"]), today: today), 2,
                       "今天还没写，不算中断")
        XCTAssertEqual(DevotionStats.currentStreak(days: days(["2026-09-24", "2026-09-25"]), today: today), 0)
        XCTAssertEqual(DevotionStats.currentStreak(days: days(["2026-09-23", "2026-09-25", "2026-09-26", "2026-09-27"]), today: today), 3)
    }

    func testLongestStreakAndMonthCount() {
        let set = days(["2026-02-27", "2026-02-28", "2026-03-01", "2026-03-02", "2026-03-10", "2026-03-11"])
        XCTAssertEqual(DevotionStats.longestStreak(days: set), 4, "跨月连续")
        XCTAssertEqual(DevotionStats.longestStreak(days: []), 0)
        XCTAssertEqual(DevotionStats.count(days: set, in: YearMonth(year: 2026, month: 3)), 4)
    }

    func testTagParsing() {
        XCTAssertEqual(TagParser.parse("信心 家庭，感恩、#祷告;信心"), ["信心", "家庭", "感恩", "祷告"])
        XCTAssertEqual(TagParser.parse("   "), [])
        XCTAssertEqual(TagParser.parse(String(repeating: "长", count: 30)).first?.count, TagParser.maxLength)
        XCTAssertEqual(TagParser.parse((1...20).map(String.init).joined(separator: " ")).count, TagParser.maxTags)
        XCTAssertEqual(TagParser.format(["信心", "家庭"]), "信心 家庭")
    }
}

final class PrayerRecordTests: XCTestCase {
    func testDaysPrayedAndShareText() throws {
        let start = try XCTUnwrap(DayKey("2026-09-01"))
        let today = try XCTUnwrap(DayKey("2026-09-27"))
        var prayer = PrayerRecord(title: "妈妈的身体", forWhom: "妈妈", detail: "求主医治", startDay: start)
        XCTAssertEqual(prayer.daysPrayed(until: today), 27)
        XCTAssertEqual(prayer.shareText(.chinese, today: today), "🙏 代祷事项\n妈妈的身体\n为：妈妈\n\n求主医治")

        prayer.status = .answered
        prayer.answeredDay = try XCTUnwrap(DayKey("2026-09-10"))
        prayer.answerNote = "检查结果一切正常"
        XCTAssertEqual(prayer.daysPrayed(until: today), 10)
        let english = prayer.shareText(.english, today: today)
        XCTAssertTrue(english.hasPrefix("✨ Praise God"))
        XCTAssertTrue(english.hasSuffix("After 10 days of prayer"))
    }
}

final class BackupTests: XCTestCase {
    private func sampleFile() -> BackupFile {
        var note = NoteRecord(day: DayKey(year: 2026, month: 9, day: 27), template: .acts, title: "标题",
                              createdAt: Date(timeIntervalSince1970: 1_790_000_000.123))
        note.adoration = "赞美"
        note.tags = ["信心"]
        let prayer = PrayerRecord(title: "教会", startDay: DayKey(year: 2026, month: 9, day: 1),
                                  lastPrayedDay: DayKey(year: 2026, month: 9, day: 26),
                                  createdAt: Date(timeIntervalSince1970: 1_780_000_000.5))
        return BackupFile(notes: [note], prayers: [prayer], exportedAt: Date(timeIntervalSince1970: 1_790_500_000))
    }

    func testRoundTrip() throws {
        let original = sampleFile()
        let data = try BackupCodec.encode(original)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(json.contains("\"app\" : \"christian-diary\""))
        XCTAssertTrue(json.contains("\"day\" : \"2026-09-27\""))

        let decoded = try BackupCodec.decode(data)
        XCTAssertEqual(decoded.notes.count, 1)
        XCTAssertEqual(decoded.notes[0].title, "标题")
        XCTAssertEqual(decoded.notes[0].adoration, "赞美")
        XCTAssertEqual(decoded.notes[0].template, .acts)
        XCTAssertEqual(decoded.notes[0].createdAt.timeIntervalSince1970, 1_790_000_000.123, accuracy: 0.001)
        XCTAssertEqual(decoded.prayers[0].lastPrayedDay?.string, "2026-09-26")
        XCTAssertNil(decoded.prayers[0].answeredDay)
    }

    func testRejectsOtherFiles() {
        XCTAssertThrowsError(try BackupCodec.decode(Data("not json".utf8))) {
            XCTAssertEqual($0 as? BackupError, .unreadable)
        }
        XCTAssertThrowsError(try BackupCodec.decode(Data(#"{"hello":"world"}"#.utf8))) {
            XCTAssertEqual($0 as? BackupError, .notABackup)
        }
        XCTAssertThrowsError(try BackupCodec.decode(Data(#"{"app":"christian-diary","version":99}"#.utf8))) {
            XCTAssertEqual($0 as? BackupError, .newerVersion(99))
        }
        XCTAssertThrowsError(try BackupCodec.decode(Data(#"{"app":"christian-diary","version":1,"notes":[{"id":"x"}]}"#.utf8))) {
            XCTAssertEqual($0 as? BackupError, .unreadable)
        }
        XCTAssertFalse(BackupError.notABackup.message(.chinese).isEmpty)
    }

    func testAcceptsTimestampsWithoutFractionalSeconds() throws {
        let json = #"{"app":"christian-diary","version":1,"exportedAt":"2026-09-27T08:00:00Z","notes":[],"prayers":[]}"#
        let file = try BackupCodec.decode(Data(json.utf8))
        XCTAssertEqual(file.exportedAt.timeIntervalSince1970, 1_790_496_000, accuracy: 0.001)
    }

    func testMergePlan() {
        let base = Date(timeIntervalSince1970: 1_790_000_000)
        let existingNote = NoteRecord(day: DayKey(year: 2026, month: 9, day: 1), createdAt: base)
        let newer = NoteRecord(id: existingNote.id, day: existingNote.day, createdAt: base, updatedAt: base.addingTimeInterval(60))
        let older = NoteRecord(day: DayKey(year: 2026, month: 9, day: 2), createdAt: base)
        let brandNew = NoteRecord(day: DayKey(year: 2026, month: 9, day: 3), createdAt: base)

        let existing: [UUID: Date] = [existingNote.id: base, older.id: base.addingTimeInterval(10)]
        let plan = MergePlan(incoming: [newer, older, brandNew, brandNew], existing: existing)
        XCTAssertEqual(plan.inserts.map(\.id), [brandNew.id], "重复的记录只处理一次")
        XCTAssertEqual(plan.updates.map(\.id), [existingNote.id])
        XCTAssertEqual(plan.skipped, 1)
    }
}

final class MarkdownExporterTests: XCTestCase {
    func testExport() {
        var first = NoteRecord(day: DayKey(year: 2026, month: 9, day: 27), template: .soap, title: "牧者",
                               scriptureReference: "诗篇 23:1", scriptureText: "耶和华是我的牧者，\n我必不至缺乏。")
        first.observation = "神看顾"
        var second = NoteRecord(day: DayKey(year: 2026, month: 9, day: 26), template: .free, scriptureReference: "约翰福音 3:16")
        second.body = "神爱世人"
        second.tags = ["爱"]

        let markdown = MarkdownExporter.export(notes: [first, second], language: .chinese,
                                               exportedOn: DayKey(year: 2026, month: 9, day: 28))
        XCTAssertTrue(markdown.hasPrefix("# 灵修笔记\n\n导出于 2026年9月28日 星期一，共 2 篇。"))
        let olderIndex = try? XCTUnwrap(markdown.range(of: "## 2026年9月26日")).lowerBound
        let newerIndex = try? XCTUnwrap(markdown.range(of: "## 2026年9月27日 星期日 · 牧者")).lowerBound
        XCTAssertNotNil(olderIndex)
        XCTAssertNotNil(newerIndex)
        if let olderIndex, let newerIndex { XCTAssertLessThan(olderIndex, newerIndex, "按日期从旧到新") }
        XCTAssertTrue(markdown.contains("> 耶和华是我的牧者，\n> 我必不至缺乏。\n>\n> —— 诗篇 23:1"))
        XCTAssertTrue(markdown.contains("**经文：** 约翰福音 3:16"))
        XCTAssertTrue(markdown.contains("### 观察\n\n神看顾"))
        XCTAssertTrue(markdown.contains("### 默想\n\n神爱世人"))
        XCTAssertTrue(markdown.contains("标签：#爱"))
    }
}
