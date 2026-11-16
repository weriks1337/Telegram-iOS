import Foundation

/// Settings for the compliant, local-first AyuGram iOS feature layer.
/// Features that tamper with Telegram read/online state or bypass privacy controls are intentionally absent.
public struct AyuSettings: Codable, Equatable, Sendable {
    public var saveEditedHistory: Bool
    public var saveDeletedHistory: Bool
    public var filtersEnabled: Bool
    public var filtersCaseInsensitive: Bool
    public var filterPatterns: [String]
    public var editedMark: String
    public var deletedMark: String
    public var hidePromotedMessages: Bool

    public init(
        saveEditedHistory: Bool = true,
        saveDeletedHistory: Bool = true,
        filtersEnabled: Bool = false,
        filtersCaseInsensitive: Bool = true,
        filterPatterns: [String] = [],
        editedMark: String = "Edited",
        deletedMark: String = "Deleted",
        hidePromotedMessages: Bool = false
    ) {
        self.saveEditedHistory = saveEditedHistory
        self.saveDeletedHistory = saveDeletedHistory
        self.filtersEnabled = filtersEnabled
        self.filtersCaseInsensitive = filtersCaseInsensitive
        self.filterPatterns = filterPatterns
        self.editedMark = editedMark
        self.deletedMark = deletedMark
        self.hidePromotedMessages = hidePromotedMessages
    }
}

public protocol AyuSettingsStore: Sendable {
    func load() throws -> AyuSettings
    func save(_ settings: AyuSettings) throws
}

public final class JSONAyuSettingsStore: AyuSettingsStore, @unchecked Sendable {
    private let url: URL
    private let lock = NSLock()

    public init(url: URL) { self.url = url }

    public func load() throws -> AyuSettings {
        lock.lock(); defer { lock.unlock() }
        guard FileManager.default.fileExists(atPath: url.path) else { return AyuSettings() }
        return try JSONDecoder().decode(AyuSettings.self, from: Data(contentsOf: url))
    }

    public func save(_ settings: AyuSettings) throws {
        lock.lock(); defer { lock.unlock() }
        let data = try JSONEncoder().encode(settings)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        #endif
    }
}
