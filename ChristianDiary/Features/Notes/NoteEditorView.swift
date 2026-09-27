import SwiftUI
import SwiftData
import DevotionCore

/// 打开编辑器的请求：新建（可带预填内容）或编辑已有笔记。
struct EditorRequest: Identifiable {
    let id = UUID()
    let note: DevotionNote?
    let prefill: NoteRecord

    static func edit(_ note: DevotionNote) -> EditorRequest {
        EditorRequest(note: note, prefill: note.record)
    }

    static func new(day: DayKey, template: NoteTemplate, reference: String = "", text: String = "") -> EditorRequest {
        EditorRequest(note: nil, prefill: NoteRecord(day: day, template: template,
                                                     scriptureReference: reference, scriptureText: text))
    }
}

/// 灵修笔记编辑器。
///
/// 编辑的是一份草稿（NoteRecord），在点「完成」、关闭页面或 App 进入后台时自动保存；
/// 新笔记只有写了内容才会保存，不会留下空白笔记。
struct NoteEditorView: View {
    let request: EditorRequest

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.appLanguage) private var lang
    @AppStorage(SettingsKey.lastTemplate) private var lastTemplate = NoteTemplate.soap

    @State private var draft: NoteRecord
    @State private var tagText: String
    @State private var savedNote: DevotionNote?
    @State private var showingVersePicker = false
    @FocusState private var focus: Focus?

    private enum Focus: Hashable {
        case title, reference, scripture, tags
        case field(NoteField)
    }

    init(request: EditorRequest) {
        self.request = request
        _draft = State(initialValue: request.prefill)
        _tagText = State(initialValue: TagParser.format(request.prefill.tags))
        _savedNote = State(initialValue: request.note)
    }

    /// 当前模板的栏目，加上其他模板里已经写过内容的栏目（切换模板不丢内容）。
    private var editorFields: [NoteField] {
        let primary = draft.template.fields
        let extra = NoteField.allCases.filter { !primary.contains($0) && !draft[$0].isEmpty }
        return primary + extra
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    templatePicker
                    headerCard
                    scriptureCard
                    ForEach(editorFields) { field in
                        fieldCard(field)
                    }
                    tagsCard
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .paperBackground()
            .navigationTitle(request.note == nil ? lang.pick("新的灵修", "New Entry") : lang.pick("编辑灵修", "Edit Entry"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.pick("完成", "Done")) {
                        commit()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        focus = nil
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                    }
                    .accessibilityLabel(lang.pick("收起键盘", "Hide keyboard"))
                }
            }
            .sheet(isPresented: $showingVersePicker) {
                VersePickerView { reference, text in
                    insertScripture(reference: reference, text: text)
                }
            }
        }
        .onDisappear { commit() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { commit() }
        }
    }

    // MARK: - 各部分

    private var templatePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(NoteTemplate.allCases) { template in
                    let selected = draft.template == template
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            draft.template = template
                            lastTemplate = template
                        }
                    } label: {
                        Label(template.name(lang), systemImage: template.systemImage)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .foregroundStyle(selected ? Color.white : Theme.ink)
                            .background(selected ? Theme.accent : Theme.card, in: Capsule())
                            .overlay(Capsule().strokeBorder(selected ? Color.clear : Theme.border, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .accessibilityLabel(lang.pick("选择模板", "Choose a template"))
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            DatePicker(
                lang.pick("日期", "Date"),
                selection: Binding(get: { draft.day.date() }, set: { draft.day = DayKey(date: $0) }),
                displayedComponents: .date
            )
            .foregroundStyle(Theme.inkSecondary)
            Divider()
            TextField(lang.pick("标题（可选）", "Title (optional)"), text: $draft.title, axis: .vertical)
                .font(Theme.serifTitle)
                .foregroundStyle(Theme.ink)
                .focused($focus, equals: .title)
            Text(draft.template.summary(lang))
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
        }
        .card()
    }

    private var scriptureCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                sectionTitle(lang.pick("经文", "Scripture"), hint: lang.pick("今天读的经文", "What did you read today?"))
                Spacer()
                Button {
                    showingVersePicker = true
                } label: {
                    Label(lang.pick("从圣经选", "Pick verses"), systemImage: "book")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(SoftButtonStyle())
            }
            TextField(lang.pick("出处，如：诗篇 23:1-6", "Reference, e.g. Psalm 23:1-6"), text: $draft.scriptureReference)
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.accent)
                .focused($focus, equals: .reference)
            TextField(lang.pick("把触动你的经文抄写下来（可选）", "Copy the verses that spoke to you (optional)"),
                      text: $draft.scriptureText, axis: .vertical)
                .font(Theme.scriptureBody)
                .lineSpacing(5)
                .lineLimit(2...)
                .focused($focus, equals: .scripture)
        }
        .card()
    }

    private func fieldCard(_ field: NoteField) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(field.label(lang, in: draft.template), hint: field.hint(lang, in: draft.template))
            TextField(field.placeholder(lang, in: draft.template),
                      text: Binding(get: { draft[field] }, set: { draft[field] = $0 }),
                      axis: .vertical)
                .lineSpacing(5)
                .lineLimit(4...)
                .focused($focus, equals: .field(field))
        }
        .card()
    }

    private var tagsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(lang.pick("标签", "Tags"), hint: lang.pick("方便以后查找", "Helps you find entries later"))
            TextField(lang.pick("用空格分隔，如：信心 家庭 感恩", "Separate with spaces, e.g. faith family"), text: $tagText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focus, equals: .tags)
            let tags = TagParser.parse(tagText)
            if !tags.isEmpty {
                FlowLayout {
                    ForEach(tags, id: \.self) { TagChip(text: "#" + $0) }
                }
            }
        }
        .card()
    }

    private func sectionTitle(_ title: String, hint: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.accent)
            Text(hint)
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
        }
    }

    // MARK: - 数据

    private func insertScripture(reference: String, text: String) {
        if draft.scriptureReference.trimmingCharacters(in: .whitespaces).isEmpty {
            draft.scriptureReference = reference
        } else {
            draft.scriptureReference += lang.pick("；", "; ") + reference
        }
        if draft.scriptureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.scriptureText = text
        } else {
            draft.scriptureText += "\n" + text
        }
    }

    private func commit() {
        var record = draft
        record.tags = TagParser.parse(tagText)
        if let note = savedNote {
            let current = note.record
            guard !record.hasSameContent(as: current) else { return }
            record.createdAt = current.createdAt
            record.updatedAt = Date()
            note.apply(record)
        } else {
            guard record.hasContent else { return }
            let now = Date()
            record.createdAt = now
            record.updatedAt = now
            let note = DevotionNote(record: record)
            context.insert(note)
            savedNote = note
        }
        try? context.save()
    }
}
