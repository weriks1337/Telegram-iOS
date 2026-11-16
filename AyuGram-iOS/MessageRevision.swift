import Foundation

public enum HistoryEventKind: String, Codable, Sendable {
    case edited
    case deleted
}

/// Snapshot of a message that the client legitimately received while it was available.
/// This model intentionally excludes secret-chat and self-destructing media payloads.
public struct MessageRevision: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let accountID: Int64
    public let peerID: Int64
    public let messageID: Int32
    public let event: HistoryEventKind
    public let text: String
    public let capturedAt: Date

    public init(
        id: UUID = UUID(),
        accountID: Int64,
        peerID: Int64,
        messageID: Int32,
        event: HistoryEventKind,
        text: String,
        capturedAt: Date = Date()
    ) {
        self.id = id
        self.accountID = accountID
        self.peerID = peerID
        self.messageID = messageID
        self.event = event
        self.text = text
        self.capturedAt = capturedAt
    }
}

public protocol MessageHistoryStore: Sendable {
    func append(_ revision: MessageRevision) async throws
    func revisions(accountID: Int64, peerID: Int64, messageID: Int32) async throws -> [MessageRevision]
    func allRevisions(accountID: Int64) async throws -> [MessageRevision]
    func removeAll(accountID: Int64) async throws
}
