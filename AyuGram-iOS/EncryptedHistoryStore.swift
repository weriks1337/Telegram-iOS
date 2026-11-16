import Foundation
import CryptoKit

public enum HistoryStoreError: Error {
    case malformedCiphertext
}

/// Local encrypted history. The encryption key never leaves the device Keychain.
public actor EncryptedHistoryStore: MessageHistoryStore {
    private let fileURL: URL
    private let keyStore: KeychainKeyStore
    private var cache: [MessageRevision]?

    public init(fileURL: URL, keyStore: KeychainKeyStore = KeychainKeyStore()) {
        self.fileURL = fileURL
        self.keyStore = keyStore
    }

    public func append(_ revision: MessageRevision) async throws {
        var records = try await loadRecords()
        records.append(revision)
        try persist(records)
        cache = records
    }

    public func revisions(accountID: Int64, peerID: Int64, messageID: Int32) async throws -> [MessageRevision] {
        let records = try await loadRecords()
        return records.filter {
            $0.accountID == accountID && $0.peerID == peerID && $0.messageID == messageID
        }.sorted { $0.capturedAt < $1.capturedAt }
    }

    public func allRevisions(accountID: Int64) async throws -> [MessageRevision] {
        let records = try await loadRecords()
        return records.filter { $0.accountID == accountID }.sorted { $0.capturedAt < $1.capturedAt }
    }

    public func removeAll(accountID: Int64) async throws {
        let remaining = try await loadRecords().filter { $0.accountID != accountID }
        try persist(remaining)
        cache = remaining
    }

    private func loadRecords() async throws -> [MessageRevision] {
        if let cache { return cache }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            cache = []
            return []
        }
        let encrypted = try Data(contentsOf: fileURL)
        guard let box = try? AES.GCM.SealedBox(combined: encrypted) else { throw HistoryStoreError.malformedCiphertext }
        let key = try keyStore.loadOrCreateKey()
        let clear = try AES.GCM.open(box, using: key)
        let decoded = try JSONDecoder().decode([MessageRevision].self, from: clear)
        cache = decoded
        return decoded
    }

    private func persist(_ records: [MessageRevision]) throws {
        let key = try keyStore.loadOrCreateKey()
        let clear = try JSONEncoder().encode(records)
        let box = try AES.GCM.seal(clear, using: key)
        guard let combined = box.combined else { throw HistoryStoreError.malformedCiphertext }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try combined.write(to: fileURL, options: .atomic)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: fileURL.path)
        #endif
    }
}
