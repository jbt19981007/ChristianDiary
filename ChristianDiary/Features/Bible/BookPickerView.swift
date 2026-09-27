import SwiftUI
import DevotionCore

/// 选择书卷和章。
struct BookPickerView: View {
    let current: ChapterLocation
    let onSelect: (ChapterLocation) -> Void

    @Environment(\.appLanguage) private var lang
    @Environment(\.dismiss) private var dismiss
    @State private var expandedBook: Int?
    @State private var testament: BibleBook.Testament

    init(current: ChapterLocation, onSelect: @escaping (ChapterLocation) -> Void) {
        self.current = current
        self.onSelect = onSelect
        _expandedBook = State(initialValue: current.book)
        _testament = State(initialValue: current.book <= 39 ? .old : .new)
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    Section {
                        Picker("", selection: $testament) {
                            Text(lang.pick("旧约", "Old Testament")).tag(BibleBook.Testament.old)
                            Text(lang.pick("新约", "New Testament")).tag(BibleBook.Testament.new)
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }

                    Section {
                        ForEach(testament == .old ? BibleBook.oldTestament : BibleBook.newTestament) { book in
                            bookRow(book)
                        }
                    }
                    .listRowBackground(Theme.card)
                }
                .listStyle(.insetGrouped)
                .paperList()
                .onAppear { proxy.scrollTo(current.book, anchor: .center) }
                .onChange(of: testament) { _, _ in expandedBook = nil }
            }
            .navigationTitle(lang.pick("选择书卷", "Books"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang.pick("关闭", "Close")) { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func bookRow(_ book: BibleBook) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if book.chapterCount == 1 {
                    select(ChapterLocation(book: book.number, chapter: 1))
                } else {
                    expandedBook = expandedBook == book.number ? nil : book.number
                }
            }
        } label: {
            HStack {
                Text(book.name(lang))
                    .foregroundStyle(book.number == current.book ? Theme.accent : Theme.ink)
                    .fontWeight(book.number == current.book ? .semibold : .regular)
                Spacer()
                Text(lang.pick("\(book.chapterCount) 章", "\(book.chapterCount) ch."))
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
                if book.chapterCount > 1 {
                    Image(systemName: expandedBook == book.number ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .id(book.number)

        if expandedBook == book.number {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(1...book.chapterCount, id: \.self) { chapter in
                    let isCurrent = book.number == current.book && chapter == current.chapter
                    Button {
                        select(ChapterLocation(book: book.number, chapter: chapter))
                    } label: {
                        Text(String(chapter))
                            .font(.subheadline.weight(isCurrent ? .bold : .regular))
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .foregroundStyle(isCurrent ? Color.white : Theme.ink)
                            .background(isCurrent ? Theme.accent : Theme.cardMuted,
                                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func select(_ location: ChapterLocation) {
        onSelect(location)
        dismiss()
    }
}
