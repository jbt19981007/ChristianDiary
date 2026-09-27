import SwiftUI
import DevotionCore

/// 经文搜索。
struct BibleSearchView: View {
    let onSelect: (ChapterLocation) -> Void

    @Environment(BibleStore.self) private var bible
    @Environment(\.appLanguage) private var lang
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var translation: BibleTranslation?
    @State private var results: [BibleText.SearchHit] = []
    @State private var isSearching = false

    private let limit = 200

    private var activeTranslation: BibleTranslation {
        translation ?? .primary(for: lang)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("", selection: Binding(get: { activeTranslation }, set: { translation = $0 })) {
                        ForEach(BibleTranslation.allCases) { item in
                            Text(item.shortName).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if isSearching {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                } else if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(lang.pick("输入关键词搜索整本圣经，例如「平安」「牧者」。",
                                   "Search the whole Bible, e.g. “peace” or “shepherd”."))
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                        .listRowBackground(Color.clear)
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                        .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(results) { hit in
                            Button {
                                onSelect(ChapterLocation(book: hit.reference.book, chapter: hit.reference.chapter))
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(hit.reference.formatted(lang))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Theme.accent)
                                    Text(hit.text)
                                        .font(Theme.scriptureBody)
                                        .foregroundStyle(Theme.ink)
                                        .lineLimit(3)
                                }
                            }
                        }
                    } header: {
                        Text(results.count >= limit
                             ? lang.pick("只显示前 \(limit) 条", "Showing the first \(limit) results")
                             : lang.pick("共 \(results.count) 条", "\(results.count) results"))
                    }
                    .listRowBackground(Theme.card)
                }
            }
            .listStyle(.insetGrouped)
            .paperList()
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: lang.pick("搜索经文", "Search scripture"))
            .navigationTitle(lang.pick("搜索经文", "Search"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang.pick("关闭", "Close")) { dismiss() }
                }
            }
            .task(id: "\(activeTranslation.rawValue)|\(query)") {
                await search()
            }
        }
    }

    private func search() async {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else {
            results = []
            return
        }
        // 输入停顿一下再搜索
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }

        isSearching = true
        defer { isSearching = false }
        let translation = activeTranslation
        await bible.load(translation)
        guard let text = bible.text(translation) else {
            results = []
            return
        }
        let maxResults = self.limit
        let hits = await Task.detached(priority: .userInitiated) {
            text.search(needle, limit: maxResults)
        }.value
        guard !Task.isCancelled else { return }
        results = hits
    }
}
