/// 灵修笔记模板。每个模板决定编辑器里显示哪些栏目；
/// 切换模板不会丢失已写的内容（所有栏目都保存在笔记里）。
public enum NoteTemplate: String, CaseIterable, Codable, Sendable, Identifiable {
    case soap
    case free
    case gratitude
    case acts

    public var id: String { rawValue }

    public var fields: [NoteField] {
        switch self {
        case .soap: return [.observation, .application, .prayer]
        case .free: return [.body]
        case .gratitude: return [.gratitude, .prayer]
        case .acts: return [.adoration, .confession, .gratitude, .supplication]
        }
    }

    public func name(_ language: Language) -> String {
        switch self {
        case .soap: return language.pick("SOAP 灵修", "SOAP Devotion")
        case .free: return language.pick("自由书写", "Free Journal")
        case .gratitude: return language.pick("感恩日记", "Gratitude Journal")
        case .acts: return language.pick("ACTS 祷告", "ACTS Prayer")
        }
    }

    public func summary(_ language: Language) -> String {
        switch self {
        case .soap: return language.pick("经文 · 观察 · 应用 · 祷告", "Scripture · Observation · Application · Prayer")
        case .free: return language.pick("像日记一样，自由写下默想与领受", "Write freely, like a journal")
        case .gratitude: return language.pick("数算主恩，记下今天感谢神的事", "Count your blessings and give thanks")
        case .acts: return language.pick("赞美 · 认罪 · 感恩 · 祈求", "Adoration · Confession · Thanksgiving · Supplication")
        }
    }

    /// SF Symbols 图标名
    public var systemImage: String {
        switch self {
        case .soap: return "book.pages"
        case .free: return "square.and.pencil"
        case .gratitude: return "heart.text.square"
        case .acts: return "hands.and.sparkles"
        }
    }
}

/// 笔记里可写的栏目（经文出处与经文内容另外单独存放）。
public enum NoteField: String, CaseIterable, Codable, Sendable, Identifiable {
    case body
    case observation
    case application
    case prayer
    case gratitude
    case adoration
    case confession
    case supplication

    public var id: String { rawValue }

    public func label(_ language: Language, in template: NoteTemplate) -> String {
        switch self {
        case .body: return language.pick("默想", "Reflection")
        case .observation: return language.pick("观察", "Observation")
        case .application: return language.pick("应用", "Application")
        case .prayer: return language.pick("祷告", "Prayer")
        case .gratitude:
            return template == .acts ? language.pick("感恩", "Thanksgiving") : language.pick("感恩", "Gratitude")
        case .adoration: return language.pick("赞美", "Adoration")
        case .confession: return language.pick("认罪", "Confession")
        case .supplication: return language.pick("祈求", "Supplication")
        }
    }

    public func hint(_ language: Language, in template: NoteTemplate) -> String {
        switch self {
        case .body: return language.pick("写下今天的领受", "What did you receive today?")
        case .observation: return language.pick("神借着经文在说什么？", "What is God saying through this passage?")
        case .application: return language.pick("我当如何回应？", "How will I respond?")
        case .prayer: return language.pick("把领受化为祷告", "Turn it into prayer")
        case .gratitude:
            return template == .acts
                ? language.pick("为神所做的献上感谢", "Thank God for what He has done")
                : language.pick("数算主恩", "Count your blessings")
        case .adoration: return language.pick("赞美神是怎样的神", "Praise God for who He is")
        case .confession: return language.pick("在神面前省察己心", "Examine your heart before God")
        case .supplication: return language.pick("为自己和他人祈求", "Ask for yourself and for others")
        }
    }

    public func placeholder(_ language: Language, in template: NoteTemplate) -> String {
        switch self {
        case .body:
            return language.pick("写下今天读经的默想、感动和神对你说的话……",
                                 "Write down your reflections and what God is speaking to you…")
        case .observation:
            return language.pick("这段经文说了什么？让我看见神是怎样的神？哪一句特别触动我？",
                                 "What does the passage say? What does it show you about God? Which words stand out?")
        case .application:
            return language.pick("有什么要顺服、要悔改、要持守的？今天可以怎样具体活出来？",
                                 "Is there something to obey, confess or hold on to? How can you live it out today?")
        case .prayer:
            return language.pick("亲爱的天父……", "Dear Father…")
        case .gratitude:
            return template == .acts
                ? language.pick("感谢神今天的供应、保守和带领……", "Thank You, Lord, for Your provision and guidance…")
                : language.pick("今天想要感谢神的事：\n1.\n2.\n3.", "Today I thank God for:\n1.\n2.\n3.")
        case .adoration:
            return language.pick("主啊，你是信实的、慈爱的……", "Lord, You are faithful and loving…")
        case .confession:
            return language.pick("主啊，求你鉴察我……", "Lord, search my heart…")
        case .supplication:
            return language.pick("为家人、教会、朋友和世界祈求……", "For my family, church, friends and the world…")
        }
    }
}
