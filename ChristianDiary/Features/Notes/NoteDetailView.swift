import SwiftUI
import SwiftData
import DevotionCore

/// 阅读一篇灵修笔记。
struct NoteDetailView: View {
    let note: DevotionNote

    @Environment(\.appLanguage) private var lang
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var editorRequest: EditorRequest?
    @State private var confirmingDelete = false
    @State private var isDeleting = false

    var body: some View {
        ScrollView {
            if isDeleting {
                EmptyView()
            } else {
                content(note.record)
            }
        }
        .paperBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ShareLink(item: note.record.plainText(lang)) {
                    Image(systemName: "square.and.arrow.up")
                }
                Menu {
                    Button {
                        editorRequest = .edit(note)
                    } label: {
                        Label(lang.pick("编辑", "Edit"), systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label(lang.pick("删除", "Delete"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $editorRequest) { NoteEditorView(request: $0) }
        .confirmationDialog(lang.pick("删除这篇灵修笔记？", "Delete this entry?"),
                            isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button(lang.pick("删除", "Delete"), role: .destructive, action: delete)
        } message: {
            Text(lang.pick("删除后无法恢复。", "This can't be undone."))
        }
    }

    private func content(_ record: NoteRecord) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(record.day.formatted(lang))
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                if !record.title.isEmpty {
                    Text(record.title)
                        .font(.system(.title, design: .serif).weight(.semibold))
                        .foregroundStyle(Theme.ink)
                }
                Label(record.template.name(lang), systemImage: record.template.systemImage)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.accent)
            }

            if !record.scriptureReference.isEmpty || !record.scriptureText.isEmpty {
                ScriptureQuote(text: record.scriptureText, reference: record.scriptureReference)
                    .textSelection(.enabled)
                    .card()
            }

            ForEach(record.visibleFields) { field in
                VStack(alignment: .leading, spacing: 8) {
                    Text(field.label(lang, in: record.template))
                        .font(.headline)
                        .foregroundStyle(Theme.accent)
                    Text(record[field].trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.body)
                        .lineSpacing(6)
                        .foregroundStyle(Theme.ink)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if !record.hasContent {
                Text(lang.pick("这篇笔记还是空的。", "This entry is empty."))
                    .foregroundStyle(Theme.inkSecondary)
            }

            if !record.tags.isEmpty {
                FlowLayout {
                    ForEach(record.tags, id: \.self) { TagChip(text: "#" + $0) }
                }
            }

            Text(lang.pick("最后编辑：", "Last edited: ")
                 + record.updatedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)

            Button {
                editorRequest = .edit(note)
            } label: {
                Label(lang.pick("编辑", "Edit"), systemImage: "pencil")
            }
            .buttonStyle(SoftButtonStyle())
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func delete() {
        // 先隐藏内容并返回上一页，再删除，避免页面在删除后还读取已删除的数据
        isDeleting = true
        dismiss()
        let target = note
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            context.delete(target)
            try? context.save()
        }
    }
}
