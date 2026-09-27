import SwiftUI
import SwiftData
import DevotionCore

/// 新建或编辑代祷事项。
struct PrayerEditorView: View {
    let target: PrayerEditorTarget

    @Environment(\.appLanguage) private var lang
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var forWhom: String
    @State private var detail: String
    @State private var answerNote: String

    init(target: PrayerEditorTarget) {
        self.target = target
        var item: PrayerItem?
        if case .edit(let existing) = target { item = existing }
        _title = State(initialValue: item?.title ?? "")
        _forWhom = State(initialValue: item?.forWhom ?? "")
        _detail = State(initialValue: item?.detail ?? "")
        _answerNote = State(initialValue: item?.answerNote ?? "")
    }

    private var editingItem: PrayerItem? {
        if case .edit(let item) = target { return item }
        return nil
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(lang.pick("代祷事项", "Prayer request"), text: $title, axis: .vertical)
                        .font(.body.weight(.medium))
                    TextField(lang.pick("为谁代祷（可选），如：妈妈、小组、教会", "For whom (optional), e.g. Mom, small group"),
                              text: $forWhom)
                }
                Section {
                    TextField(lang.pick("具体的需要、想对神说的话……", "Details, what you'd like to ask God…"),
                              text: $detail, axis: .vertical)
                        .lineLimit(4...)
                } header: {
                    Text(lang.pick("详细内容", "Details"))
                }
                if editingItem?.status == .answered {
                    Section {
                        TextField(lang.pick("神是怎样应允的？", "How did God answer?"), text: $answerNote, axis: .vertical)
                            .lineLimit(3...)
                    } header: {
                        Text(lang.pick("见证", "Testimony"))
                    }
                }
            }
            .paperList()
            .navigationTitle(editingItem == nil ? lang.pick("新的代祷", "New Request") : lang.pick("编辑代祷", "Edit Request"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang.pick("取消", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.pick("保存", "Save"), action: save)
                        .fontWeight(.semibold)
                        .disabled(trimmedTitle.isEmpty)
                }
            }
        }
    }

    private func save() {
        let cleanForWhom = self.forWhom.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDetail = self.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        if let item = editingItem {
            item.title = trimmedTitle
            item.forWhom = cleanForWhom
            item.detail = cleanDetail
            item.answerNote = answerNote.trimmingCharacters(in: .whitespacesAndNewlines)
            item.updatedAt = Date()
        } else {
            let record = PrayerRecord(title: trimmedTitle, forWhom: cleanForWhom, detail: cleanDetail, startDay: .today())
            context.insert(PrayerItem(record: record))
        }
        try? context.save()
        dismiss()
    }
}

/// 标记为「已蒙应允」并写下见证。
struct AnswerPrayerView: View {
    let item: PrayerItem

    @Environment(\.appLanguage) private var lang
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 36))
                            .foregroundStyle(Theme.green)
                        Text(lang.pick("感谢神！", "Praise God!"))
                            .font(Theme.serifTitle)
                            .foregroundStyle(Theme.ink)
                        Text(item.title)
                            .font(.body)
                            .foregroundStyle(Theme.inkSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                Section {
                    TextField(lang.pick("神是怎样应允的？", "How did God answer?"), text: $note, axis: .vertical)
                        .lineLimit(4...)
                } header: {
                    Text(lang.pick("写下见证（可选）", "Testimony (optional)"))
                } footer: {
                    Text(lang.pick("记下来，将来回头数算主恩。", "Write it down so you can remember God's faithfulness."))
                }
            }
            .paperList()
            .navigationTitle(lang.pick("蒙应允", "Answered"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang.pick("取消", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.pick("确定", "Done")) {
                        item.markAnswered(on: .today(), note: note.trimmingCharacters(in: .whitespacesAndNewlines))
                        try? context.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
