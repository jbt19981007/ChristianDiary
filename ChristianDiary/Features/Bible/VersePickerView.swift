import SwiftUI
import DevotionCore

/// 在编辑笔记时从圣经中点选经文，一键引用。
struct VersePickerView: View {
    /// 回传（出处, 经文）
    let onPick: (String, String) -> Void

    @Environment(BibleStore.self) private var bible
    @Environment(\.appLanguage) private var lang
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.bibleBook) private var lastBook = 1
    @AppStorage(SettingsKey.bibleChapter) private var lastChapter = 1
    @AppStorage(SettingsKey.bibleDisplay) private var displayRaw = ""
    @AppStorage(SettingsKey.bibleFontSize) private var fontSize: Double = 19

    @State private var chosenLocation: ChapterLocation?
    @State private var selection: Set<Int> = []
    @State private var showingBooks = false

    private var location: ChapterLocation {
        if let chosenLocation { return chosenLocation }
        let info = BibleBook.book(lastBook) ?? BibleBook.all[0]
        return ChapterLocation(book: info.number, chapter: min(max(lastChapter, 1), info.chapterCount))
    }

    private var display: BibleDisplay { .resolve(displayRaw, language: lang) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(lang.pick("点选要引用的经文（可多选）", "Tap the verses you want to quote"))
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSecondary)
                    ChapterTextView(location: location, display: display,
                                    fontSize: CGFloat(max(fontSize - 2, 13)), selection: $selection)
                    ChapterNavigation(location: location) { next in
                        chosenLocation = next
                        selection = []
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
            .paperBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang.pick("取消", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Button {
                        showingBooks = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(location.formatted(lang)).font(.headline)
                            Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Theme.ink)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(selection.isEmpty ? lang.pick("引用", "Quote") : lang.pick("引用 \(selection.count) 节", "Quote \(selection.count)")) {
                        let picked = VerseSelection(location: location, verses: Array(selection))
                        onPick(picked.reference(lang), picked.text(from: bible, display: display))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selection.isEmpty)
                }
            }
            .sheet(isPresented: $showingBooks) {
                BookPickerView(current: location) { picked in
                    chosenLocation = picked
                    selection = []
                }
            }
        }
    }
}
