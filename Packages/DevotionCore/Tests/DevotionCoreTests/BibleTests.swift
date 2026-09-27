import XCTest
@testable import DevotionCore

/// App 内置的经文数据（ChristianDiary/Resources/Bible），测试直接读取仓库里的文件。
enum BundledBible {
    static let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // DevotionCoreTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // DevotionCore
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // 仓库根目录
        .appendingPathComponent("ChristianDiary/Resources/Bible")

    static func load(_ translation: BibleTranslation) throws -> BibleText {
        let url = directory.appendingPathComponent("\(translation.resourceName).txt")
        return try BibleText(translation: translation, tsv: String(contentsOf: url, encoding: .utf8))
    }

    static let cuv = Result { try load(.cuv) }
    static let kjv = Result { try load(.kjv) }
}

final class BibleBookTests: XCTestCase {
    func testCanon() {
        XCTAssertEqual(BibleBook.all.count, 66)
        XCTAssertEqual(BibleBook.oldTestament.count, 39)
        XCTAssertEqual(BibleBook.newTestament.count, 27)
        XCTAssertEqual(BibleBook.all.map(\.chapterCount).reduce(0, +), 1189)
        XCTAssertEqual(BibleBook.all.map(\.number), Array(1...66))
        XCTAssertEqual(BibleBook.book(43)?.chineseName, "约翰福音")
        XCTAssertEqual(BibleBook.book(43)?.englishName, "John")
        XCTAssertEqual(BibleBook.book(40)?.testament, .new)
        XCTAssertNil(BibleBook.book(0))
        XCTAssertNil(BibleBook.book(67))
    }

    func testReferenceFormatting() {
        let single = BibleReference(book: 43, chapter: 3, verseStart: 16)
        XCTAssertEqual(single.formatted(.chinese), "约翰福音 3:16")
        XCTAssertEqual(single.formatted(.english), "John 3:16")
        XCTAssertEqual(BibleReference(book: 20, chapter: 3, verseStart: 5, verseEnd: 6).formatted(.chinese), "箴言 3:5-6")
        XCTAssertEqual(BibleReference(book: 1, chapter: 1, verseStart: 5, verseEnd: 2).verseEnd, 5, "结束节不早于起始节")
        XCTAssertEqual(BibleReference.formatted(book: 43, chapter: 3, verses: [19, 16, 17, 17], language: .chinese),
                       "约翰福音 3:16-17, 19")
        XCTAssertEqual(BibleReference.formatted(book: 19, chapter: 23, verses: [1, 2, 3], language: .english), "Psalm 23:1-3")
        XCTAssertNil(BibleReference.formatted(book: 19, chapter: 23, verses: [], language: .english))
    }

    func testChapterNavigation() {
        XCTAssertEqual(ChapterLocation(book: 1, chapter: 50).next, ChapterLocation(book: 2, chapter: 1))
        XCTAssertEqual(ChapterLocation(book: 2, chapter: 1).previous, ChapterLocation(book: 1, chapter: 50))
        XCTAssertEqual(ChapterLocation(book: 19, chapter: 23).next, ChapterLocation(book: 19, chapter: 24))
        XCTAssertNil(ChapterLocation.genesis1.previous)
        XCTAssertNil(ChapterLocation(book: 66, chapter: 22).next)
        XCTAssertEqual(ChapterLocation(book: 19, chapter: 23).formatted(.chinese), "诗篇 23 章")
        XCTAssertEqual(ChapterLocation(book: 19, chapter: 23).formatted(.english), "Psalm 23")
    }
}

final class BibleTextTests: XCTestCase {
    private func sampleTSV(omitting book: Int? = nil) -> String {
        var lines: [String] = []
        for info in BibleBook.all where info.number != book {
            for chapter in 1...info.chapterCount {
                lines.append("\(info.number)\t\(chapter)\t1\t\(info.englishName) \(chapter):1")
                lines.append("\(info.number)\t\(chapter)\t2\tSecond verse")
            }
        }
        return lines.joined(separator: "\n")
    }

    func testParsesSample() throws {
        let text = try BibleText(translation: .kjv, tsv: sampleTSV())
        XCTAssertEqual(text.verseCount, 1189 * 2)
        XCTAssertEqual(text.verses(book: 43, chapter: 3).map(\.number), [1, 2])
        XCTAssertEqual(text.text(book: 43, chapter: 3, verses: [1, 2]), "John 3:1 Second verse")
        XCTAssertEqual(text.verses(book: 43, chapter: 99), [])
        XCTAssertEqual(text.verses(book: 99, chapter: 1), [])
    }

    func testRejectsMalformedData() {
        XCTAssertThrowsError(try BibleText(translation: .kjv, tsv: "1\t1\tx\tbad")) { error in
            XCTAssertEqual(error as? BibleText.ParseError, .malformedLine(1))
        }
        XCTAssertThrowsError(try BibleText(translation: .kjv, tsv: "1\t51\t1\tno such chapter"))
        XCTAssertThrowsError(try BibleText(translation: .kjv, tsv: sampleTSV(omitting: 65))) { error in
            XCTAssertEqual(error as? BibleText.ParseError, .missingBook(65))
        }
    }

    func testBundledChineseUnionVersion() throws {
        let cuv = try BundledBible.cuv.get()
        XCTAssertEqual(cuv.verseCount, 31_100)
        XCTAssertEqual(cuv.text(for: BibleReference(book: 43, chapter: 3, verseStart: 16)),
                       "神爱世人，甚至将他的独生子赐给他们，叫一切信他的，不至灭亡，反得永生。")
        XCTAssertEqual(cuv.verses(book: 19, chapter: 119).count, 176)
        XCTAssertEqual(cuv.text(book: 1, chapter: 1, verses: [1]), "起初神创造天地。")
        // 中文经文连写，不加空格
        XCTAssertEqual(cuv.text(for: BibleReference(book: 1, chapter: 1, verseStart: 1, verseEnd: 2))?.contains(" "), false)
        XCTAssertTrue(cuv.search("我必不至缺乏").contains { $0.reference == BibleReference(book: 19, chapter: 23, verseStart: 1) })
    }

    func testBundledKingJamesVersion() throws {
        let kjv = try BundledBible.kjv.get()
        XCTAssertEqual(kjv.verseCount, 31_102)
        XCTAssertEqual(kjv.text(for: BibleReference(book: 1, chapter: 1, verseStart: 1)),
                       "In the beginning God created the heaven and the earth.")
        XCTAssertEqual(kjv.verses(book: 66, chapter: 22).count, 21)
        let hits = kjv.search("SHEPHERD", limit: 5)
        XCTAssertEqual(hits.count, 5, "不区分大小写，并遵守 limit")
        XCTAssertEqual(hits.map(\.reference), hits.map(\.reference).sorted { ($0.book, $0.chapter, $0.verseStart) < ($1.book, $1.chapter, $1.verseStart) })
        XCTAssertEqual(kjv.search("   "), [])
    }
}

final class DailyVerseTests: XCTestCase {
    func testDataMatchesBundledBible() throws {
        let cuv = try BundledBible.cuv.get()
        let kjv = try BundledBible.kjv.get()
        XCTAssertGreaterThanOrEqual(DailyVerse.all.count, 90)
        XCTAssertEqual(Set(DailyVerse.all.map(\.reference)).count, DailyVerse.all.count, "不应重复")
        for verse in DailyVerse.all {
            XCTAssertFalse(verse.chinese.isEmpty)
            XCTAssertEqual(kjv.text(for: verse.reference), verse.english, verse.reference.formatted(.english))
            XCTAssertTrue(try XCTUnwrap(cuv.text(for: verse.reference)).hasSuffix(verse.chinese), verse.reference.formatted(.chinese))
        }
    }

    func testRotationIsDeterministic() throws {
        let day = try XCTUnwrap(DayKey("2026-09-27"))
        XCTAssertEqual(DailyVerse.forDay(day), DailyVerse.forDay(day))
        XCTAssertNotEqual(DailyVerse.forDay(day), DailyVerse.forDay(day.adding(days: 1)))
        XCTAssertEqual(DailyVerse.forDay(day, shift: 1), DailyVerse.forDay(day.adding(days: 1)))
        XCTAssertEqual(DailyVerse.forDay(day, shift: DailyVerse.all.count), DailyVerse.forDay(day))
        XCTAssertEqual(DailyVerse.forDay(DayKey(epochDay: -12_345), shift: -7), DailyVerse.forDay(DayKey(epochDay: -12_352)))
    }

    func testShareText() {
        let verse = DailyVerse.all[0]
        XCTAssertEqual(verse.shareText(.chinese), "耶和华是我的牧者，我必不至缺乏。\n——诗篇 23:1（和合本）")
        XCTAssertEqual(verse.shareText(.english), "The LORD is my shepherd; I shall not want.\n— Psalm 23:1 (KJV)")
    }
}
