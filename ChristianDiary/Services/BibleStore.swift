import Foundation
import Observation
import DevotionCore

/// 负责从 App 包里加载内置圣经（Resources/Bible/*.txt），在后台线程解析，按需加载、只加载一次。
@Observable
@MainActor
final class BibleStore {
    private(set) var texts: [BibleTranslation: BibleText] = [:]
    private(set) var failed: Set<BibleTranslation> = []
    private var loading: Set<BibleTranslation> = []

    func text(_ translation: BibleTranslation) -> BibleText? {
        texts[translation]
    }

    func isReady(_ translations: [BibleTranslation]) -> Bool {
        translations.allSatisfy { texts[$0] != nil }
    }

    func load(_ translations: [BibleTranslation]) async {
        await withTaskGroup(of: Void.self) { group in
            for translation in translations {
                group.addTask { await self.load(translation) }
            }
        }
    }

    func load(_ translation: BibleTranslation) async {
        guard texts[translation] == nil, !loading.contains(translation) else { return }
        loading.insert(translation)
        defer { loading.remove(translation) }

        let result = await Task.detached(priority: .userInitiated) {
            Result { try BibleStore.readBundled(translation) }
        }.value

        switch result {
        case .success(let text):
            texts[translation] = text
            failed.remove(translation)
        case .failure(let error):
            print("加载圣经失败（\(translation.rawValue)）：\(error)")
            failed.insert(translation)
        }
    }

    enum StoreError: Error {
        case missingResource(String)
    }

    nonisolated static func readBundled(_ translation: BibleTranslation) throws -> BibleText {
        guard let url = Bundle.main.url(forResource: translation.resourceName, withExtension: "txt") else {
            throw StoreError.missingResource(translation.resourceName)
        }
        return try BibleText(translation: translation, tsv: String(contentsOf: url, encoding: .utf8))
    }
}
