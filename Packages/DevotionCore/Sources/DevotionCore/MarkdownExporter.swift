/// 把笔记导出为 Markdown，方便存档、打印或导入其他笔记软件。
public enum MarkdownExporter {
    public static func export(notes: [NoteRecord], language: Language, exportedOn: DayKey) -> String {
        let sorted = notes.sorted { $0.day != $1.day ? $0.day < $1.day : $0.createdAt < $1.createdAt }
        var out: [String] = [
            language.pick("# 灵修笔记", "# Devotion Journal"),
            "",
            language.pick("导出于 \(exportedOn.formatted(.chinese))，共 \(notes.count) 篇。",
                          "Exported on \(exportedOn.formatted(.english)) · \(notes.count) entries."),
            "",
        ]
        for note in sorted {
            let title = note.title.isBlank ? "" : " · \(note.title.trimmed)"
            out.append("---")
            out.append("")
            out.append("## \(note.day.formatted(language))\(title)")
            out.append("")
            if !note.scriptureText.isBlank {
                out.append(contentsOf: note.scriptureText.trimmed.split(whereSeparator: \.isNewline).map { "> \($0)" })
                if !note.scriptureReference.isBlank {
                    out.append(">")
                    out.append("> —— \(note.scriptureReference.trimmed)")
                }
                out.append("")
            } else if !note.scriptureReference.isBlank {
                out.append(language.pick("**经文：**", "**Scripture:**") + " \(note.scriptureReference.trimmed)")
                out.append("")
            }
            for field in note.visibleFields {
                out.append("### \(field.label(language, in: note.template))")
                out.append("")
                out.append(note[field].trimmed)
                out.append("")
            }
            if !note.tags.isEmpty {
                out.append(language.pick("标签：", "Tags: ") + note.tags.map { "#\($0)" }.joined(separator: " "))
                out.append("")
            }
        }
        return out.joined(separator: "\n")
    }
}
