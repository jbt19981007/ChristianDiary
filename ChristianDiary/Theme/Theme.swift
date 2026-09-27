import SwiftUI
import UIKit

/// 温暖纸张风配色：米白纸张底色、暖棕/金色点缀，深色模式下是温暖的深棕。
enum Theme {
    static let paper = Color(light: 0xF6F1E9, dark: 0x171512)
    static let card = Color(light: 0xFFFDF8, dark: 0x221F1B)
    static let cardMuted = Color(light: 0xF0E8DC, dark: 0x2C2823)
    static let ink = Color(light: 0x2A241F, dark: 0xEEE7DD)
    static let inkSecondary = Color(light: 0x6F6358, dark: 0xA89D90)
    static let border = Color(light: 0xE6DCCD, dark: 0x38322B)
    static let accent = Color(light: 0x9A6431, dark: 0xD9A66B)
    static let accentSoft = Color(light: 0xF3E4D0, dark: 0x3A2E21)
    static let green = Color(light: 0x5E7A4A, dark: 0x9DBB84)
    static let greenSoft = Color(light: 0xE4EBD9, dark: 0x2A3324)
    /// 经文选中时的底色
    static let highlight = Color(light: 0xF7E7B8, dark: 0x4A3B1E)

    /// 经文字体（衬线）
    static func scripture(size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    static let scriptureBody = Font.system(.body, design: .serif)
    static let serifTitle = Font.system(.title2, design: .serif).weight(.semibold)
}

extension Color {
    /// 随浅色 / 深色模式自动切换的颜色。
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
