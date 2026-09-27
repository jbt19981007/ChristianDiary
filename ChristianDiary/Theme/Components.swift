import SwiftUI

// MARK: - 卡片与背景

struct CardBackground: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 0.5)
            )
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        modifier(CardBackground(padding: padding))
    }

    func paperBackground() -> some View {
        background(Theme.paper.ignoresSafeArea())
    }

    /// 列表使用纸张底色、卡片行背景。
    func paperList() -> some View {
        scrollContentBackground(.hidden).background(Theme.paper.ignoresSafeArea())
    }
}

/// 卡片左上角的小标题。
struct CardLabel: View {
    let title: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Theme.inkSecondary)
    }
}

// MARK: - 标签

struct TagChip: View {
    let text: String
    var selected = false

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(selected ? Color.white : Theme.accent)
            .background(selected ? Theme.accent : Theme.accentSoft, in: Capsule())
    }
}

/// 自动换行排列（用于标签）。
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var width: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            width = max(width, x - spacing)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - 经文引用块

struct ScriptureQuote: View {
    let text: String
    let reference: String
    var secondaryText: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Theme.accent)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 8) {
                if !text.isEmpty {
                    Text(text)
                        .font(Theme.scriptureBody)
                        .lineSpacing(6)
                        .foregroundStyle(Theme.ink)
                }
                if let secondaryText, !secondaryText.isEmpty {
                    Text(secondaryText)
                        .font(Theme.scriptureBody)
                        .lineSpacing(4)
                        .foregroundStyle(Theme.inkSecondary)
                }
                if !reference.isEmpty {
                    Text(reference)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - 按钮样式

/// 主要操作按钮：暖棕底色、圆角胶囊。
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(Theme.accent.opacity(configuration.isPressed ? 0.8 : 1), in: Capsule())
    }
}

/// 次要操作按钮：浅色底。
struct SoftButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent
    var background: Color = Theme.accentSoft

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(background.opacity(configuration.isPressed ? 0.7 : 1), in: Capsule())
    }
}
