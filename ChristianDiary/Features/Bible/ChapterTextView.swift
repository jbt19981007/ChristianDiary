import SwiftUI
import DevotionCore

/// 一章经文：可按中文 / 英文 / 中英对照显示，点击经文可选中。
struct ChapterTextView: View {
    let location: ChapterLocation
    let display: BibleDisplay
    let fontSize: CGFloat
    @Binding var selection: Set<Int>

    @Environment(BibleStore.self) private var bible
    @Environment(\.appLanguage) private var lang

    private struct Row: Identifiable {
        let number: Int
        let primary: String?
        let secondary: String?
        var id: Int { number }
    }

    private var rows: [Row] {
        let translations = display.translations
        let first = bible.text(translations[0])?.verses(in: location) ?? []
        let second = translations.count > 1 ? (bible.text(translations[1])?.verses(in: location) ?? []) : []
        let secondByNumber = Dictionary(second.map { ($0.number, $0.text) }, uniquingKeysWith: { a, _ in a })
        var numbers = first.map(\.number)
        // 两个译本分节略有不同时，补上只在第二个译本里出现的节
        for verse in second where !numbers.contains(verse.number) { numbers.append(verse.number) }
        let firstByNumber = Dictionary(first.map { ($0.number, $0.text) }, uniquingKeysWith: { a, _ in a })
        return numbers.sorted().map { Row(number: $0, primary: firstByNumber[$0], secondary: secondByNumber[$0]) }
    }

    var body: some View {
        if !bible.isReady(display.translations) {
            ProgressView(lang.pick("正在载入经文…", "Loading…"))
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
                .task { await bible.load(display.translations) }
        } else {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(rows) { row in
                    verseRow(row)
                }
            }
        }
    }

    private func verseRow(_ row: Row) -> some View {
        let selected = selection.contains(row.number)
        return Button {
            if selected { selection.remove(row.number) } else { selection.insert(row.number) }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(row.number))
                    .font(.system(size: fontSize * 0.6, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(minWidth: 18, alignment: .trailing)
                VStack(alignment: .leading, spacing: 6) {
                    if let primary = row.primary {
                        Text(primary)
                            .font(Theme.scripture(size: fontSize))
                            .lineSpacing(fontSize * 0.45)
                            .foregroundStyle(Theme.ink)
                    }
                    if let secondary = row.secondary {
                        Text(secondary)
                            .font(Theme.scripture(size: fontSize * 0.85))
                            .lineSpacing(fontSize * 0.3)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(selected ? Theme.highlight : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 把选中的经文整理成「出处 + 经文」。
@MainActor
struct VerseSelection {
    let location: ChapterLocation
    let verses: [Int]

    func reference(_ language: Language) -> String {
        BibleReference.formatted(book: location.book, chapter: location.chapter, verses: verses, language: language) ?? ""
    }

    /// 按显示方式取经文：中英对照时中文在上、英文在下。
    func text(from bible: BibleStore, display: BibleDisplay) -> String {
        display.translations.compactMap { translation in
            bible.text(translation)?.text(book: location.book, chapter: location.chapter, verses: verses)
        }
        .joined(separator: "\n")
    }

    func shareText(from bible: BibleStore, display: BibleDisplay, language: Language) -> String {
        let versions = display.translations.map(\.shortName).joined(separator: " / ")
        return "\(text(from: bible, display: display))\n——\(reference(language))（\(versions)）"
    }
}
