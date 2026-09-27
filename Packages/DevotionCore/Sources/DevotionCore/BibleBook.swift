/// 圣经 66 卷书卷信息（书名采用和合本 / KJV 通用英文名）。
public struct BibleBook: Hashable, Identifiable, Sendable {
    public enum Testament: String, Sendable {
        case old, new
    }

    /// 1 = 创世记 … 66 = 启示录
    public let number: Int
    public let chineseName: String
    public let chineseAbbreviation: String
    public let englishName: String
    public let englishAbbreviation: String
    public let chapterCount: Int

    public var id: Int { number }
    public var testament: Testament { number <= 39 ? .old : .new }

    public func name(_ language: Language) -> String {
        language == .chinese ? chineseName : englishName
    }

    /// 引用单篇经文时的书名：英文诗篇用单数「Psalm 23:1」。
    public func referenceName(_ language: Language) -> String {
        language == .english && number == 19 ? "Psalm" : name(language)
    }

    public func abbreviation(_ language: Language) -> String {
        language == .chinese ? chineseAbbreviation : englishAbbreviation
    }

    public static func book(_ number: Int) -> BibleBook? {
        (1...all.count).contains(number) ? all[number - 1] : nil
    }

    public static var oldTestament: [BibleBook] { Array(all.prefix(39)) }
    public static var newTestament: [BibleBook] { Array(all.suffix(27)) }

    public static let all: [BibleBook] = rawBooks.enumerated().map { index, book in
        BibleBook(number: index + 1, chineseName: book.0, chineseAbbreviation: book.1,
                  englishName: book.2, englishAbbreviation: book.3, chapterCount: book.4)
    }

    // 显式标注类型，避免编译器推断大型字面量时过慢
    private static let rawBooks: [(String, String, String, String, Int)] = [
        ("创世记", "创", "Genesis", "Gen", 50),
        ("出埃及记", "出", "Exodus", "Exod", 40),
        ("利未记", "利", "Leviticus", "Lev", 27),
        ("民数记", "民", "Numbers", "Num", 36),
        ("申命记", "申", "Deuteronomy", "Deut", 34),
        ("约书亚记", "书", "Joshua", "Josh", 24),
        ("士师记", "士", "Judges", "Judg", 21),
        ("路得记", "得", "Ruth", "Ruth", 4),
        ("撒母耳记上", "撒上", "1 Samuel", "1 Sam", 31),
        ("撒母耳记下", "撒下", "2 Samuel", "2 Sam", 24),
        ("列王纪上", "王上", "1 Kings", "1 Kgs", 22),
        ("列王纪下", "王下", "2 Kings", "2 Kgs", 25),
        ("历代志上", "代上", "1 Chronicles", "1 Chr", 29),
        ("历代志下", "代下", "2 Chronicles", "2 Chr", 36),
        ("以斯拉记", "拉", "Ezra", "Ezra", 10),
        ("尼希米记", "尼", "Nehemiah", "Neh", 13),
        ("以斯帖记", "斯", "Esther", "Esth", 10),
        ("约伯记", "伯", "Job", "Job", 42),
        ("诗篇", "诗", "Psalms", "Ps", 150),
        ("箴言", "箴", "Proverbs", "Prov", 31),
        ("传道书", "传", "Ecclesiastes", "Eccl", 12),
        ("雅歌", "歌", "Song of Solomon", "Song", 8),
        ("以赛亚书", "赛", "Isaiah", "Isa", 66),
        ("耶利米书", "耶", "Jeremiah", "Jer", 52),
        ("耶利米哀歌", "哀", "Lamentations", "Lam", 5),
        ("以西结书", "结", "Ezekiel", "Ezek", 48),
        ("但以理书", "但", "Daniel", "Dan", 12),
        ("何西阿书", "何", "Hosea", "Hos", 14),
        ("约珥书", "珥", "Joel", "Joel", 3),
        ("阿摩司书", "摩", "Amos", "Amos", 9),
        ("俄巴底亚书", "俄", "Obadiah", "Obad", 1),
        ("约拿书", "拿", "Jonah", "Jonah", 4),
        ("弥迦书", "弥", "Micah", "Mic", 7),
        ("那鸿书", "鸿", "Nahum", "Nah", 3),
        ("哈巴谷书", "哈", "Habakkuk", "Hab", 3),
        ("西番雅书", "番", "Zephaniah", "Zeph", 3),
        ("哈该书", "该", "Haggai", "Hag", 2),
        ("撒迦利亚书", "亚", "Zechariah", "Zech", 14),
        ("玛拉基书", "玛", "Malachi", "Mal", 4),
        ("马太福音", "太", "Matthew", "Matt", 28),
        ("马可福音", "可", "Mark", "Mark", 16),
        ("路加福音", "路", "Luke", "Luke", 24),
        ("约翰福音", "约", "John", "John", 21),
        ("使徒行传", "徒", "Acts", "Acts", 28),
        ("罗马书", "罗", "Romans", "Rom", 16),
        ("哥林多前书", "林前", "1 Corinthians", "1 Cor", 16),
        ("哥林多后书", "林后", "2 Corinthians", "2 Cor", 13),
        ("加拉太书", "加", "Galatians", "Gal", 6),
        ("以弗所书", "弗", "Ephesians", "Eph", 6),
        ("腓立比书", "腓", "Philippians", "Phil", 4),
        ("歌罗西书", "西", "Colossians", "Col", 4),
        ("帖撒罗尼迦前书", "帖前", "1 Thessalonians", "1 Thess", 5),
        ("帖撒罗尼迦后书", "帖后", "2 Thessalonians", "2 Thess", 3),
        ("提摩太前书", "提前", "1 Timothy", "1 Tim", 6),
        ("提摩太后书", "提后", "2 Timothy", "2 Tim", 4),
        ("提多书", "多", "Titus", "Titus", 3),
        ("腓利门书", "门", "Philemon", "Phlm", 1),
        ("希伯来书", "来", "Hebrews", "Heb", 13),
        ("雅各书", "雅", "James", "Jas", 5),
        ("彼得前书", "彼前", "1 Peter", "1 Pet", 5),
        ("彼得后书", "彼后", "2 Peter", "2 Pet", 3),
        ("约翰一书", "约一", "1 John", "1 John", 5),
        ("约翰二书", "约二", "2 John", "2 John", 1),
        ("约翰三书", "约三", "3 John", "3 John", 1),
        ("犹大书", "犹", "Jude", "Jude", 1),
        ("启示录", "启", "Revelation", "Rev", 22),
    ]
}
