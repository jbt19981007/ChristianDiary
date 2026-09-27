# 灵修笔记 · ChristianDiary

一款帮助基督徒每天亲近神的 iOS 灵修笔记 App：读经、默想、记录、祷告。
原生 SwiftUI 开发，温暖纸张风设计，支持简体中文与英文。

> 需求说明见 [docs/需求说明.md](docs/需求说明.md)。

## 功能

| 模块 | 内容 |
| --- | --- |
| **今日** | 问候、连续灵修天数、每日经文（换一节 / 分享 / 用它写灵修）、今日灵修、代祷提醒 |
| **圣经** | 内置完整**和合本（简体）**与 **KJV**，中文 / 英文 / 中英对照；按卷章阅读、记住位置、字号调节、全文搜索；点选经文可复制、分享、直接写灵修 |
| **笔记** | 四种模板：SOAP 灵修、自由书写、感恩日记、ACTS 祷告；从圣经点选经文引用；标签、搜索、月历回顾；自动保存 |
| **代祷** | 代祷事项、为谁代祷、「今天已为此祷告」计数；标记蒙应允并写下见证；文字分享到微信等 |
| **我的** | 灵修统计、每日提醒（推送当天经文）、Face ID 锁、语言与外观、备份 / 恢复 / 导出 Markdown |
| **小组件** | 主屏幕（小 / 中 / 大）与锁屏小组件，显示每日经文 |

数据只保存在本机（SwiftData），可以导出 JSON 备份、随时恢复。

## 在自己的 iPhone 上运行

需要：一台 Mac（Xcode 16 或更新版本）、一部 iOS 17 以上的 iPhone、一个 Apple ID（免费即可）。

1. 下载代码，双击打开 `ChristianDiary.xcodeproj`。
2. 在左侧选中项目 **ChristianDiary**，分别选中两个 Target：**ChristianDiary** 和 **DailyVerseWidgetExtension**，
   在 **Signing & Capabilities** 里：
   - **Team** 选择你的 Apple ID（没有的话点 *Add an Account…* 登录）；
   - **Bundle Identifier** 改成你自己的唯一名称，例如 `com.你的名字.ChristianDiary`，
     小组件的要以它开头，例如 `com.你的名字.ChristianDiary.DailyVerseWidget`。
3. 用数据线连接 iPhone，在 Xcode 顶部选择你的 iPhone，点 ▶︎ 运行。
4. 第一次运行时，iPhone 上需要：
   - 打开 **设置 › 隐私与安全性 › 开发者模式**；
   - 在 **设置 › 通用 › VPN 与设备管理** 里信任你的开发者证书。

> 使用**免费 Apple ID** 安装的 App 每 **7 天**需要用 Xcode 重新运行一次（数据不会丢失）。

## 分发给弟兄姊妹 / 开启 iCloud 同步

以下都需要加入 **Apple Developer Program**（个人或教会机构，$99/年）：

- **TestFlight 分发**：在 Xcode 里 *Product › Archive*，上传到 App Store Connect，邀请弟兄姊妹通过 TestFlight 安装。
- **上架 App Store**：同上，并准备截图、隐私说明后提交审核。
- **iCloud 同步**：数据模型已经按 CloudKit 的要求设计，不需要改代码。只需在 ChristianDiary Target 的
  *Signing & Capabilities* 里：
  1. 添加 **iCloud**，勾选 **CloudKit**，新建一个容器（如 `iCloud.com.你的名字.ChristianDiary`）；
  2. 添加 **Background Modes**，勾选 **Remote notifications**。

  之后 SwiftData 会自动通过用户自己的 iCloud 账号在多台设备之间同步。

## 项目结构

```
ChristianDiary.xcodeproj        Xcode 项目（App + 小组件）
ChristianDiary/                 App 源代码
  App/                          入口、根视图、设置项
  Features/                     各页面：Today / Bible / Notes / Prayers / Settings
  Models/                       SwiftData 模型（笔记、代祷）
  Services/                     圣经加载、提醒、App 锁、备份
  Theme/                        配色与通用组件
  Resources/Bible/              内置经文（cuv.txt 和合本、kjv.txt）
DailyVerseWidget/               每日经文小组件
Packages/DevotionCore/          核心逻辑（与界面无关，有单元测试）
  Sources/DevotionCore/         日期、书卷、经文解析、模板、统计、备份格式、导出
  Tests/DevotionCoreTests/      单元测试
tools/build_bible.py            生成经文数据与每日经文
tools/AppIcon.svg               App 图标源文件
docs/需求说明.md                 需求说明
```

## 开发

```bash
# 运行核心逻辑的单元测试（macOS）
swift test --package-path Packages/DevotionCore

# 重新生成经文数据（修改每日经文列表后需要运行）
python3 tools/build_bible.py
```

每次推送代码，GitHub Actions（`.github/workflows/ios.yml`）会在 macOS 上运行单元测试并编译 App 与小组件。

## 经文来源与版权

- **和合本（1919，简体）** 与 **King James Version（1769 标准文本）** 均为公有领域文本，
  取自 [open-bibles](https://github.com/seven1m/open-bibles)。
- NIV 等现代译本受版权保护，不能内置在 App 中。

代码以 [MIT License](LICENSE) 发布。
