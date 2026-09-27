/// 经文出处，例如「约翰福音 3:16-17」。
public struct BibleReference: Hashable, Codable, Sendable {
    public let book: Int
    public let chapter: Int
    public let verseStart: Int
    public let verseEnd: Int

    public init(book: Int, chapter: Int, verseStart: Int, verseEnd: Int? = nil) {
        self.book = book
        self.chapter = chapter
        self.verseStart = verseStart
        self.verseEnd = max(verseEnd ?? verseStart, verseStart)
    }

    /// 由若干节（可不连续）生成出处；空数组返回 nil。
    /// 例：[16, 17, 19] → 「3:16-17, 19」
    public static func formatted(book: Int, chapter: Int, verses: [Int], language: Language) -> String? {
        guard let bookInfo = BibleBook.book(book), !verses.isEmpty else { return nil }
        let name = bookInfo.referenceName(language)
        let sorted = Array(Set(verses)).sorted()
        var ranges: [(Int, Int)] = []
        for verse in sorted {
            if let last = ranges.last, last.1 == verse - 1 {
                ranges[ranges.count - 1].1 = verse
            } else {
                ranges.append((verse, verse))
            }
        }
        let parts = ranges.map { $0.0 == $0.1 ? "\($0.0)" : "\($0.0)-\($0.1)" }
        return "\(name) \(chapter):\(parts.joined(separator: ", "))"
    }

    public var verses: ClosedRange<Int> { verseStart...verseEnd }

    public func formatted(_ language: Language) -> String {
        let name = BibleBook.book(book)?.referenceName(language) ?? "?"
        let range = verseStart == verseEnd ? "\(verseStart)" : "\(verseStart)-\(verseEnd)"
        return "\(name) \(chapter):\(range)"
    }
}

/// 某卷书的某一章，用于阅读位置。
public struct ChapterLocation: Hashable, Codable, Sendable {
    public let book: Int
    public let chapter: Int

    public init(book: Int, chapter: Int) {
        self.book = book
        self.chapter = chapter
    }

    public static let genesis1 = ChapterLocation(book: 1, chapter: 1)

    public var bookInfo: BibleBook? { BibleBook.book(book) }

    public func formatted(_ language: Language) -> String {
        let name = bookInfo?.referenceName(language) ?? "?"
        return language == .chinese ? "\(name) \(chapter) 章" : "\(name) \(chapter)"
    }

    /// 下一章（跨卷）；已是启示录末章则返回 nil。
    public var next: ChapterLocation? {
        guard let info = bookInfo else { return nil }
        if chapter < info.chapterCount { return ChapterLocation(book: book, chapter: chapter + 1) }
        return book < 66 ? ChapterLocation(book: book + 1, chapter: 1) : nil
    }

    /// 上一章（跨卷）；已是创世记第一章则返回 nil。
    public var previous: ChapterLocation? {
        if chapter > 1 { return ChapterLocation(book: book, chapter: chapter - 1) }
        guard book > 1, let prev = BibleBook.book(book - 1) else { return nil }
        return ChapterLocation(book: book - 1, chapter: prev.chapterCount)
    }
}
