import Foundation

/// 一篇灵修笔记的可移植表示：编辑草稿、备份文件、分享与导出都用它。
/// App 里的 SwiftData 模型与它互相转换。
public struct NoteRecord: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var day: DayKey
    public var template: NoteTemplate
    public var title: String
    public var scriptureReference: String
    public var scriptureText: String
    public var body: String
    public var observation: String
    public var application: String
    public var prayer: String
    public var gratitude: String
    public var adoration: String
    public var confession: String
    public var supplication: String
    public var tags: [String]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        day: DayKey,
        template: NoteTemplate = .soap,
        title: String = "",
        scriptureReference: String = "",
        scriptureText: String = "",
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.day = day
        self.template = template
        self.title = title
        self.scriptureReference = scriptureReference
        self.scriptureText = scriptureText
        self.body = ""
        self.observation = ""
        self.application = ""
        self.prayer = ""
        self.gratitude = ""
        self.adoration = ""
        self.confession = ""
        self.supplication = ""
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    public subscript(field: NoteField) -> String {
        get {
            switch field {
            case .body: return body
            case .observation: return observation
            case .application: return application
            case .prayer: return prayer
            case .gratitude: return gratitude
            case .adoration: return adoration
            case .confession: return confession
            case .supplication: return supplication
            }
        }
        set {
            switch field {
            case .body: body = newValue
            case .observation: observation = newValue
            case .application: application = newValue
            case .prayer: prayer = newValue
            case .gratitude: gratitude = newValue
            case .adoration: adoration = newValue
            case .confession: confession = newValue
            case .supplication: supplication = newValue
            }
        }
    }

    // MARK: - 内容

    /// 标题、经文、各栏目或标签中任一有内容即为 true。
    public var hasContent: Bool {
        !title.isBlank || !scriptureReference.isBlank || !scriptureText.isBlank
            || NoteField.allCases.contains { !self[$0].isBlank } || !tags.isEmpty
    }

    /// 除 id 和时间戳以外的内容是否完全相同（用来判断编辑后是否需要保存）。
    public func hasSameContent(as other: NoteRecord) -> Bool {
        var copy = self
        copy.id = other.id
        copy.createdAt = other.createdAt
        copy.updatedAt = other.updatedAt
        return copy == other
    }

    /// 阅读时要显示的栏目：先按当前模板的顺序，再附上其他模板里写过的内容。
    public var visibleFields: [NoteField] {
        let primary = template.fields.filter { !self[$0].isBlank }
        let extra = NoteField.allCases.filter { !template.fields.contains($0) && !self[$0].isBlank }
        return primary + extra
    }

    public func headline(_ language: Language) -> String {
        if !title.isBlank { return title.trimmed }
        if !scriptureReference.isBlank { return scriptureReference.trimmed }
        if let first = visibleFields.first,
           let line = self[first].trimmed.split(whereSeparator: \.isNewline).first {
            return String(line.prefix(40))
        }
        return template.name(language)
    }

    /// 列表里的内容摘要（不重复已用作标题的那一栏）。
    public func snippet(maxLength: Int = 120) -> String {
        var texts = (visibleFields.map { self[$0] } + [scriptureText]).map(\.trimmed).filter { !$0.isEmpty }
        if title.isBlank, scriptureReference.isBlank, !visibleFields.isEmpty {
            texts.removeFirst()
        }
        guard let first = texts.first else { return "" }
        let text = first.split(whereSeparator: \.isNewline).joined(separator: " ")
        return text.count > maxLength ? String(text.prefix(maxLength)) + "…" : text
    }

    /// 搜索：在所有文字栏目和标签中查找（不区分大小写）。
    public func matches(_ query: String) -> Bool {
        let needle = query.trimmed
        guard !needle.isEmpty else { return true }
        let haystack = ([title, scriptureReference, scriptureText] + NoteField.allCases.map { self[$0] } + tags)
            .joined(separator: "\n")
        return haystack.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    /// 用于分享的纯文字。
    public func plainText(_ language: Language) -> String {
        var lines = [day.formatted(language)]
        if !title.isBlank { lines.append(title.trimmed) }
        if !scriptureReference.isBlank || !scriptureText.isBlank {
            lines.append("")
            lines.append("【\(language.pick("经文", "Scripture"))】\(scriptureReference.trimmed)")
            if !scriptureText.isBlank { lines.append(scriptureText.trimmed) }
        }
        for field in visibleFields {
            lines.append("")
            lines.append("【\(field.label(language, in: template))】")
            lines.append(self[field].trimmed)
        }
        if !tags.isEmpty {
            lines.append("")
            lines.append(tags.map { "#\($0)" }.joined(separator: " "))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Codable（缺少的字段用默认值，兼容旧版或手工编辑的备份）

    private enum CodingKeys: String, CodingKey {
        case id, day, template, title, scriptureReference, scriptureText
        case body, observation, application, prayer, gratitude, adoration, confession, supplication
        case tags, createdAt, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        day = try c.decode(DayKey.self, forKey: .day)
        template = (try? c.decodeIfPresent(NoteTemplate.self, forKey: .template)) ?? .soap
        func text(_ key: CodingKeys) throws -> String { try c.decodeIfPresent(String.self, forKey: key) ?? "" }
        title = try text(.title)
        scriptureReference = try text(.scriptureReference)
        scriptureText = try text(.scriptureText)
        body = try text(.body)
        observation = try text(.observation)
        application = try text(.application)
        prayer = try text(.prayer)
        gratitude = try text(.gratitude)
        adoration = try text(.adoration)
        confession = try text(.confession)
        supplication = try text(.supplication)
        tags = try TagParser.normalize(c.decodeIfPresent([String].self, forKey: .tags) ?? [])
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var isBlank: Bool { trimmed.isEmpty }
}

/// 笔记排序：日期新的在前，同一天按创建时间新的在前。
public func noteSortOrder(_ a: NoteRecord, _ b: NoteRecord) -> Bool {
    a.day != b.day ? a.day > b.day : a.createdAt > b.createdAt
}
