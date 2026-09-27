import SwiftUI
import SwiftData
import DevotionCore

struct NotesView: View {
    @Environment(\.appLanguage) private var lang
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\DevotionNote.dayString, order: .reverse),
                  SortDescriptor(\DevotionNote.createdAt, order: .reverse)])
    private var notes: [DevotionNote]
    @AppStorage(SettingsKey.lastTemplate) private var lastTemplate = NoteTemplate.soap

    @State private var searchText = ""
    @State private var selectedTag: String?
    @State private var selectedDay: DayKey?
    @State private var month = DayKey.today().yearMonth
    @State private var editorRequest: EditorRequest?
    @State private var pendingDeletion: DevotionNote?

    private var today: DayKey { .today() }

    private var filteredNotes: [DevotionNote] {
        notes.filter { note in
            if let selectedDay, note.dayString != selectedDay.string { return false }
            if let selectedTag, !note.tags.contains(selectedTag) { return false }
            if !searchText.isEmpty, !note.record.matches(searchText) { return false }
            return true
        }
    }

    private var allTags: [String] {
        var counts: [String: Int] = [:]
        for note in notes {
            for tag in note.tags { counts[tag, default: 0] += 1 }
        }
        return counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.map(\.key)
    }

    private struct MonthGroup: Identifiable {
        let month: YearMonth
        var notes: [DevotionNote]
        var id: YearMonth { month }
    }

    /// 按月分组（笔记已按日期倒序）。
    private var groups: [MonthGroup] {
        var result: [MonthGroup] = []
        for note in filteredNotes {
            let month = note.day.yearMonth
            if result.last?.month == month {
                result[result.count - 1].notes.append(note)
            } else {
                result.append(MonthGroup(month: month, notes: [note]))
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    Section {
                        MonthCalendarView(month: $month, selectedDay: $selectedDay,
                                          markedDays: Set(notes.map(\.day)), today: today)
                            .padding(.vertical, 4)
                    }
                    .listRowBackground(Theme.card)
                }

                if !allTags.isEmpty {
                    Section {
                        tagBar
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }

                if let selectedDay {
                    Section {
                        HStack {
                            Label(selectedDay.formatted(lang), systemImage: "calendar")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Button(lang.pick("显示全部", "Show all")) {
                                withAnimation { self.selectedDay = nil }
                            }
                            .buttonStyle(.borderless)
                            .font(.subheadline)
                        }
                        Button {
                            editorRequest = .new(day: selectedDay, template: lastTemplate)
                        } label: {
                            Label(lang.pick("为这一天写灵修", "Write for this day"), systemImage: "square.and.pencil")
                        }
                    }
                    .listRowBackground(Theme.card)
                }

                ForEach(groups) { group in
                    Section {
                        ForEach(group.notes) { note in
                            NavigationLink(value: note) {
                                NoteRow(note: note)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    pendingDeletion = note
                                } label: {
                                    Label(lang.pick("删除", "Delete"), systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        Text(group.month.formatted(lang))
                    }
                    .listRowBackground(Theme.card)
                }

                if filteredNotes.isEmpty {
                    emptyState
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .paperList()
            .searchable(text: $searchText, prompt: lang.pick("搜索经文、标题或内容", "Search notes"))
            .navigationTitle(lang.pick("灵修笔记", "Journal"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editorRequest = .new(day: selectedDay ?? today, template: lastTemplate)
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel(lang.pick("写灵修", "New entry"))
                }
            }
            .navigationDestination(for: DevotionNote.self) { NoteDetailView(note: $0) }
            .sheet(item: $editorRequest) { NoteEditorView(request: $0) }
            .confirmationDialog(
                lang.pick("删除这篇灵修笔记？", "Delete this entry?"),
                isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
                titleVisibility: .visible
            ) {
                Button(lang.pick("删除", "Delete"), role: .destructive) {
                    if let note = pendingDeletion {
                        context.delete(note)
                        try? context.save()
                    }
                    pendingDeletion = nil
                }
            } message: {
                Text(lang.pick("删除后无法恢复。", "This can't be undone."))
            }
        }
    }

    private var tagBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(allTags, id: \.self) { tag in
                    Button {
                        withAnimation { selectedTag = selectedTag == tag ? nil : tag }
                    } label: {
                        TagChip(text: "#" + tag, selected: selectedTag == tag)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if notes.isEmpty {
            ContentUnavailableView {
                Label(lang.pick("还没有灵修笔记", "No entries yet"), systemImage: "book.closed")
            } description: {
                Text(lang.pick("每天读一段经文，写下神对你说的话。", "Read a passage each day and write what God is saying to you."))
            } actions: {
                Button(lang.pick("写第一篇", "Write your first entry")) {
                    editorRequest = .new(day: today, template: lastTemplate)
                }
                .buttonStyle(SoftButtonStyle())
            }
        } else if selectedDay != nil && searchText.isEmpty && selectedTag == nil {
            ContentUnavailableView(lang.pick("这一天还没有灵修", "No entries on this day"), systemImage: "calendar")
        } else {
            ContentUnavailableView.search(text: searchText)
        }
    }
}
