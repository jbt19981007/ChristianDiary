import SwiftUI
import UIKit
import DevotionCore

/// 圣经阅读：从上次读到的地方继续。
struct BibleView: View {
    @Environment(\.appLanguage) private var lang
    @Environment(BibleStore.self) private var bible
    @AppStorage(SettingsKey.bibleBook) private var book = 1
    @AppStorage(SettingsKey.bibleChapter) private var chapter = 1
    @AppStorage(SettingsKey.bibleDisplay) private var displayRaw = ""
    @AppStorage(SettingsKey.bibleFontSize) private var fontSize: Double = 19
    @AppStorage(SettingsKey.lastTemplate) private var lastTemplate = NoteTemplate.soap

    @State private var selection: Set<Int> = []
    @State private var showingBooks = false
    @State private var showingSearch = false
    @State private var editorRequest: EditorRequest?
    @State private var copied = false

    private var location: ChapterLocation {
        let info = BibleBook.book(book) ?? BibleBook.all[0]
        return ChapterLocation(book: info.number, chapter: min(max(chapter, 1), info.chapterCount))
    }

    private var display: BibleDisplay { .resolve(displayRaw, language: lang) }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(location.formatted(lang))
                            .font(Theme.serifTitle)
                            .foregroundStyle(Theme.ink)
                            .id("top")
                        ChapterTextView(location: location, display: display,
                                        fontSize: CGFloat(fontSize), selection: $selection)
                        ChapterNavigation(location: location, go: go)
                            .padding(.top, 8)
                    }
                    .padding()
                    .padding(.bottom, selection.isEmpty ? 0 : 60)
                }
                .onChange(of: location) { _, _ in
                    selection = []
                    proxy.scrollTo("top", anchor: .top)
                }
            }
            .paperBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button {
                        showingBooks = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(location.formatted(lang))
                                .font(.headline)
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Theme.ink)
                    }
                    .accessibilityLabel(lang.pick("选择书卷和章", "Choose book and chapter"))
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel(lang.pick("搜索经文", "Search"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    displayMenu
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !selection.isEmpty {
                    selectionBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selection.isEmpty)
            .sheet(isPresented: $showingBooks) {
                BookPickerView(current: location, onSelect: go)
            }
            .sheet(isPresented: $showingSearch) {
                BibleSearchView(onSelect: go)
            }
            .sheet(item: $editorRequest) { NoteEditorView(request: $0) }
        }
    }

    private var displayMenu: some View {
        Menu {
            Picker(lang.pick("显示", "Display"), selection: Binding(get: { display }, set: { displayRaw = $0.rawValue })) {
                ForEach(BibleDisplay.allCases) { option in
                    Text(option.label(lang)).tag(option)
                }
            }
            Divider()
            Button {
                fontSize = min(fontSize + 2, 32)
            } label: {
                Label(lang.pick("放大字体", "Larger text"), systemImage: "textformat.size.larger")
            }
            Button {
                fontSize = max(fontSize - 2, 13)
            } label: {
                Label(lang.pick("缩小字体", "Smaller text"), systemImage: "textformat.size.smaller")
            }
        } label: {
            Image(systemName: "textformat.size")
        }
        .accessibilityLabel(lang.pick("显示设置", "Display settings"))
    }

    private var selectionBar: some View {
        let current = VerseSelection(location: location, verses: Array(selection))
        return HStack(spacing: 16) {
            Text(current.reference(lang))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button {
                UIPasteboard.general.string = current.shareText(from: bible, display: display, language: lang)
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    copied = false
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
            }
            .accessibilityLabel(lang.pick("复制", "Copy"))
            ShareLink(item: current.shareText(from: bible, display: display, language: lang)) {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel(lang.pick("分享", "Share"))
            Button {
                editorRequest = .new(day: .today(), template: lastTemplate,
                                     reference: current.reference(lang),
                                     text: current.text(from: bible, display: display))
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .accessibilityLabel(lang.pick("写灵修", "Write a devotion"))
            Button {
                selection = []
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Theme.inkSecondary)
            }
            .accessibilityLabel(lang.pick("取消选择", "Clear selection"))
        }
        .font(.title3)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 0.5))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func go(to location: ChapterLocation) {
        book = location.book
        chapter = location.chapter
    }
}

/// 上一章 / 下一章。
struct ChapterNavigation: View {
    let location: ChapterLocation
    let go: (ChapterLocation) -> Void
    @Environment(\.appLanguage) private var lang

    var body: some View {
        HStack {
            if let previous = location.previous {
                Button {
                    go(previous)
                } label: {
                    Label(previous.formatted(lang), systemImage: "chevron.left")
                }
            }
            Spacer()
            if let next = location.next {
                Button {
                    go(next)
                } label: {
                    HStack(spacing: 4) {
                        Text(next.formatted(lang))
                        Image(systemName: "chevron.right")
                    }
                }
            }
        }
        .buttonStyle(SoftButtonStyle())
        .lineLimit(1)
    }
}
