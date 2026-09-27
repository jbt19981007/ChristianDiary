import Foundation

/// 备份文件（JSON）。
public struct BackupFile: Codable, Sendable {
    public static let appIdentifier = "christian-diary"
    public static let currentVersion = 1

    public var app: String
    public var version: Int
    public var exportedAt: Date
    public var notes: [NoteRecord]
    public var prayers: [PrayerRecord]

    public init(notes: [NoteRecord], prayers: [PrayerRecord], exportedAt: Date = Date()) {
        self.app = BackupFile.appIdentifier
        self.version = BackupFile.currentVersion
        self.exportedAt = exportedAt
        self.notes = notes
        self.prayers = prayers
    }

    private enum CodingKeys: String, CodingKey {
        case app, version, exportedAt, notes, prayers
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        app = try c.decode(String.self, forKey: .app)
        version = try c.decode(Int.self, forKey: .version)
        exportedAt = try c.decodeIfPresent(Date.self, forKey: .exportedAt) ?? Date()
        notes = try c.decodeIfPresent([NoteRecord].self, forKey: .notes) ?? []
        prayers = try c.decodeIfPresent([PrayerRecord].self, forKey: .prayers) ?? []
    }
}

public enum BackupError: Error, Equatable {
    case unreadable
    case notABackup
    case newerVersion(Int)

    public func message(_ language: Language) -> String {
        switch self {
        case .unreadable:
            return language.pick("无法读取这个文件，它可能已损坏。", "This file can't be read. It may be damaged.")
        case .notABackup:
            return language.pick("这不是灵修笔记的备份文件。", "This isn't a Devotion Journal backup file.")
        case .newerVersion:
            return language.pick("这个备份来自更新版本的 App，请先更新 App 再恢复。",
                                 "This backup was made by a newer version of the app. Please update first.")
        }
    }
}

public enum BackupCodec {
    public static func encode(_ file: BackupFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(isoFormatter(fractional: true).string(from: date))
        }
        return try encoder.encode(file)
    }

    public static func decode(_ data: Data) throws -> BackupFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = isoFormatter(fractional: true).date(from: raw) ?? isoFormatter(fractional: false).date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "无效时间：\(raw)")
        }

        // 先确认是本 App 的备份，再完整解析，这样能给出更准确的错误提示
        struct Header: Decodable {
            let app: String?
            let version: Int?
        }
        guard let header = try? JSONDecoder().decode(Header.self, from: data) else { throw BackupError.unreadable }
        guard header.app == BackupFile.appIdentifier, let version = header.version else { throw BackupError.notABackup }
        guard version <= BackupFile.currentVersion else { throw BackupError.newerVersion(version) }

        do {
            return try decoder.decode(BackupFile.self, from: data)
        } catch {
            throw BackupError.unreadable
        }
    }

    private static func isoFormatter(fractional: Bool) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = fractional ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        return formatter
    }
}

/// 可合并的记录（按 id 对应，按 updatedAt 判断新旧）。
public protocol MergeableRecord: Identifiable where ID == UUID {
    var updatedAt: Date { get }
}

extension NoteRecord: MergeableRecord {}
extension PrayerRecord: MergeableRecord {}

public struct MergePlan<Record: MergeableRecord> {
    /// 本机没有的记录
    public var inserts: [Record] = []
    /// 本机有、但备份里的版本更新的记录
    public var updates: [Record] = []
    /// 本机版本相同或更新，跳过
    public var skipped = 0

    /// - Parameter existing: 本机已有记录的 id → 最后修改时间
    public init(incoming: [Record], existing: [UUID: Date]) {
        var seen = Set<UUID>()
        for record in incoming where seen.insert(record.id).inserted {
            if let localDate = existing[record.id] {
                if record.updatedAt > localDate {
                    updates.append(record)
                } else {
                    skipped += 1
                }
            } else {
                inserts.append(record)
            }
        }
    }
}
