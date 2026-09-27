import SwiftUI
import DevotionCore

/// 笔记列表中的一行。
struct NoteRow: View {
    let note: DevotionNote
    var showsDate = true
    @Environment(\.appLanguage) private var lang

    var body: some View {
        let record = note.record
        let snippet = record.snippet()
        HStack(alignment: .top, spacing: 14) {
            if showsDate {
                VStack(spacing: 0) {
                    Text(String(record.day.day))
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Text(record.day.shortWeekday(lang))
                        .font(.caption2)
                        .foregroundStyle(Theme.inkSecondary)
                }
                .frame(width: 40)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: record.template.systemImage)
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                    Text(record.headline(lang))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                }
                if !snippet.isEmpty {
                    Text(snippet)
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                        .lineLimit(2)
                }
                if !record.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(record.tags.prefix(3), id: \.self) { TagChip(text: $0) }
                        if record.tags.count > 3 {
                            Text("+\(record.tags.count - 3)")
                                .font(.caption)
                                .foregroundStyle(Theme.inkSecondary)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}
