import Foundation

/// 内置的圣经译本。
public enum BibleTranslation: String, CaseIterable, Codable, Sendable, Identifiable {
    /// 和合本（简体），1919，公有领域
    case cuv
    /// King James Version，1769 标准文本，公有领域
    case kjv

    public var id: String { rawValue }

    /// App 包内的资源文件名（不含扩展名，扩展名为 txt）
    public var resourceName: String { rawValue }

    public var language: Language { self == .cuv ? .chinese : .english }

    public var shortName: String { self == .cuv ? "和合本" : "KJV" }

    public static func primary(for language: Language) -> BibleTranslation {
        language == .chinese ? .cuv : .kjv
    }
}

public struct BibleVerse: Hashable, Sendable, Identifiable {
    public let number: Int
    public let text: String
    public var id: Int { number }

    public init(number: Int, text: String) {
        self.number = number
        self.text = text
    }
}

/// 一个译本的全部经文。
///
/// 数据格式（由 tools/build_bible.py 生成）：每行一节，
/// `书卷序号<TAB>章<TAB>节<TAB>经文`，按书卷、章、节顺序排列。
public struct BibleText: Sendable {
    public let translation: BibleTranslation
    /// chapters[书卷序号 - 1][章 - 1] = 该章各节
    private let chapters: [[[BibleVerse]]]

    public enum ParseError: Error, Equatable {
        case malformedLine(Int)
        case missingBook(Int)
    }

    public init(translation: BibleTranslation, tsv: String) throws {
        var books: [[[BibleVerse]]] = BibleBook.all.map { Array(repeating: [], count: $0.chapterCount) }
        var lineNumber = 0
        for line in tsv.split(separator: "\n", omittingEmptySubsequences: true) {
            lineNumber += 1
            let fields = line.split(separator: "\t", maxSplits: 3, omittingEmptySubsequences: false)
            guard fields.count == 4,
                  let book = Int(fields[0]), let chapter = Int(fields[1]), let verse = Int(fields[2]),
                  (1...books.count).contains(book), (1...books[book - 1].count).contains(chapter)
            else { throw ParseError.malformedLine(lineNumber) }
            books[book - 1][chapter - 1].append(BibleVerse(number: verse, text: String(fields[3])))
        }
        if let empty = books.firstIndex(where: { $0.contains(where: \.isEmpty) }) {
            throw ParseError.missingBook(empty + 1)
        }
        self.translation = translation
        self.chapters = books
    }

    public func verses(book: Int, chapter: Int) -> [BibleVerse] {
        guard (1...chapters.count).contains(book), (1...chapters[book - 1].count).contains(chapter) else { return [] }
        return chapters[book - 1][chapter - 1]
    }

    public func verses(in location: ChapterLocation) -> [BibleVerse] {
        verses(book: location.book, chapter: location.chapter)
    }

    /// 取出一段经文的文字；中文直接相连，英文用空格分隔。
    public func text(for reference: BibleReference) -> String? {
        text(book: reference.book, chapter: reference.chapter, verses: Array(reference.verses))
    }

    public func text(book: Int, chapter: Int, verses numbers: [Int]) -> String? {
        let wanted = Set(numbers)
        let found = verses(book: book, chapter: chapter).filter { wanted.contains($0.number) }
        guard !found.isEmpty else { return nil }
        return found.map(\.text).joined(separator: translation.language == .chinese ? "" : " ")
    }

    public struct SearchHit: Hashable, Sendable, Identifiable {
        public let reference: BibleReference
        public let text: String
        public var id: BibleReference { reference }
    }

    /// 简单的全文搜索（不区分大小写），按圣经顺序返回。
    public func search(_ query: String, limit: Int = 200) -> [SearchHit] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }
        var hits: [SearchHit] = []
        for (bookIndex, book) in chapters.enumerated() {
            for (chapterIndex, verses) in book.enumerated() {
                for verse in verses where verse.text.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
                    let reference = BibleReference(book: bookIndex + 1, chapter: chapterIndex + 1, verseStart: verse.number)
                    hits.append(SearchHit(reference: reference, text: verse.text))
                    if hits.count >= limit { return hits }
                }
            }
        }
        return hits
    }

    public var verseCount: Int {
        chapters.reduce(0) { $0 + $1.reduce(0) { $0 + $1.count } }
    }
}
