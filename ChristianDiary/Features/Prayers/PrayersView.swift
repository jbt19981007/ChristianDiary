import SwiftUI
import SwiftData
import DevotionCore

struct PrayersView: View {
    @Environment(\.appLanguage) private var lang
    @Environment(\.modelContext) private var context
    @Query(sort: \PrayerItem.createdAt, order: .reverse) private var prayers: [PrayerItem]

    @State private var filter: PrayerStatus = .praying
    @State private var editorTarget: PrayerEditorTarget?
    @State private var answering: PrayerItem?
    @State private var pendingDeletion: PrayerItem?

    private var shown: [PrayerItem] {
        let list = prayers.filter { $0.status == filter }
        guard filter == .answered else { return list }
        return list.sorted { ($0.answeredDayString ?? "") > ($1.answeredDayString ?? "") }
    }

    private func count(_ status: PrayerStatus) -> Int {
        prayers.filter { $0.status == status }.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(lang.pick("「应当一无挂虑，只要凡事借着祷告、祈求，和感谢，将你们所要的告诉神。」",
                                       "“Be careful for nothing; but in every thing by prayer and supplication with thanksgiving let your requests be made known unto God.”"))
                            .font(Theme.scriptureBody)
                            .foregroundStyle(Theme.inkSecondary)
                        Text(lang.pick("腓立比书 4:6", "Philippians 4:6"))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.accent)
                        Picker("", selection: $filter) {
                            Text(lang.pick("代祷中 \(count(.praying))", "Praying (\(count(.praying)))"))
                                .tag(PrayerStatus.praying)
                            Text(lang.pick("已蒙应允 \(count(.answered))", "Answered (\(count(.answered)))"))
                                .tag(PrayerStatus.answered)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))

                if shown.isEmpty {
                    emptyState
                        .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(shown) { item in
                            PrayerRow(item: item,
                                      onEdit: { editorTarget = .edit(item) },
                                      onAnswer: { answering = item },
                                      onDelete: { pendingDeletion = item })
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        pendingDeletion = item
                                    } label: {
                                        Label(lang.pick("删除", "Delete"), systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    if item.status == .praying {
                                        Button {
                                            answering = item
                                        } label: {
                                            Label(lang.pick("蒙应允", "Answered"), systemImage: "sparkles")
                                        }
                                        .tint(Theme.green)
                                    } else {
                                        Button {
                                            item.reopen()
                                            try? context.save()
                                        } label: {
                                            Label(lang.pick("继续代祷", "Keep praying"), systemImage: "arrow.uturn.backward")
                                        }
                                        .tint(Theme.accent)
                                    }
                                }
                        }
                    }
                    .listRowBackground(Theme.card)
                }
            }
            .listStyle(.insetGrouped)
            .paperList()
            .navigationTitle(lang.pick("代祷", "Prayer"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editorTarget = .new
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(lang.pick("添加代祷事项", "Add prayer request"))
                }
            }
            .sheet(item: $editorTarget) { PrayerEditorView(target: $0) }
            .sheet(item: $answering) { AnswerPrayerView(item: $0) }
            .confirmationDialog(
                lang.pick("删除这条代祷事项？", "Delete this prayer request?"),
                isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
                titleVisibility: .visible
            ) {
                Button(lang.pick("删除", "Delete"), role: .destructive) {
                    if let item = pendingDeletion {
                        context.delete(item)
                        try? context.save()
                    }
                    pendingDeletion = nil
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if filter == .praying {
            ContentUnavailableView {
                Label(lang.pick("还没有代祷事项", "No prayer requests"), systemImage: "hands.and.sparkles")
            } description: {
                Text(lang.pick("把家人、朋友、教会和自己的需要带到神面前。",
                               "Bring the needs of your family, friends, church and yourself to God."))
            } actions: {
                Button(lang.pick("添加代祷事项", "Add a prayer request")) { editorTarget = .new }
                    .buttonStyle(SoftButtonStyle())
            }
        } else {
            ContentUnavailableView(
                lang.pick("还没有蒙应允的祷告", "No answered prayers yet"),
                systemImage: "sparkles",
                description: Text(lang.pick("神垂听祷告。祷告蒙应允时，在这里记下见证。",
                                            "God hears prayer. When He answers, record it here."))
            )
        }
    }
}

/// 代祷列表中的一项。
struct PrayerRow: View {
    let item: PrayerItem
    let onEdit: () -> Void
    let onAnswer: () -> Void
    let onDelete: () -> Void

    @Environment(\.appLanguage) private var lang
    @Environment(\.modelContext) private var context

    var body: some View {
        let today = DayKey.today()
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    if !item.forWhom.isEmpty {
                        Label(item.forWhom, systemImage: "person")
                            .font(.caption)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }
                Spacer()
                Menu {
                    Button(action: onEdit) {
                        Label(lang.pick("编辑", "Edit"), systemImage: "pencil")
                    }
                    ShareLink(item: item.record.shareText(lang, today: today)) {
                        Label(lang.pick("分享", "Share"), systemImage: "square.and.arrow.up")
                    }
                    if item.status == .praying {
                        Button(action: onAnswer) {
                            Label(lang.pick("标记为蒙应允", "Mark as answered"), systemImage: "sparkles")
                        }
                    } else {
                        Button {
                            item.reopen()
                            try? context.save()
                        } label: {
                            Label(lang.pick("移回代祷中", "Move back to praying"), systemImage: "arrow.uturn.backward")
                        }
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label(lang.pick("删除", "Delete"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.inkSecondary)
                        .frame(width: 32, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(lang.pick("更多操作", "More"))
            }

            if !item.detail.isEmpty {
                Text(item.detail)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink.opacity(0.85))
                    .lineLimit(4)
            }

            if item.status == .answered {
                if !item.answerNote.isEmpty {
                    Text(item.answerNote)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.greenSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                Label(answeredSummary(today: today), systemImage: "sparkles")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.green)
            } else {
                HStack {
                    Text(prayingSummary)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                    Spacer()
                    PrayedButton(item: item)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var prayingSummary: String {
        let since = item.startDay.formatted(lang, weekday: false, year: item.startDay.year != DayKey.today().year)
        return lang.pick("\(since)开始 · 已代祷 \(item.prayedCount) 次",
                         "Since \(since) · prayed \(item.prayedCount) time\(item.prayedCount == 1 ? "" : "s")")
    }

    private func answeredSummary(today: DayKey) -> String {
        let days = item.record.daysPrayed(until: today)
        let answered = (item.answeredDay ?? today).formatted(lang, weekday: false)
        return lang.pick("\(answered)蒙应允 · 历时 \(days) 天",
                         "Answered \(answered) · after \(days) day\(days == 1 ? "" : "s")")
    }
}

enum PrayerEditorTarget: Identifiable {
    case new
    case edit(PrayerItem)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let item): return item.uuid.uuidString
        }
    }
}
