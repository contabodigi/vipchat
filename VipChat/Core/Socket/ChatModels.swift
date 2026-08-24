import Foundation

// Mirrors backend Message documents + socket payloads. `sender` is decoded
// leniently because live message:new sends it as an object while
// conversation:created/messages:initial send it as a raw id string.
struct ReplySnapshot: Codable, Hashable {
    var text: String?
    var senderRole: String?
    var type: String?
    var fileName: String?
}

struct Reaction: Codable, Hashable {
    let emoji: String
    let userId: String
    let role: String?
}

struct BotButton: Codable, Hashable {
    let text: String?
    let action: String?
    let value: String?
}

struct ChatMessage: Codable, Identifiable, Hashable {
    // All properties carry defaults so the memberwise init `ChatMessage(id:)` works
    // for building optimistic messages.
    var id: String
    var conversation: String? = nil
    var senderRole: String? = nil
    var text: String? = nil
    var type: String = "text"
    var fileUrl: String? = nil
    var fileName: String? = nil
    var fileSize: Int? = nil
    var mimeType: String? = nil
    var caption: String? = nil
    var replyTo: String? = nil
    var replyToSnapshot: ReplySnapshot? = nil
    var edited: Bool = false
    var deleted: Bool = false
    var reactions: [Reaction] = []
    var status: String? = nil
    var callType: String? = nil
    var buttons: [BotButton] = []
    var createdAt: String? = nil
    var clientId: String? = nil

    // client-only send state (not from server)
    var localId: String? = nil
    var pending: Bool = false
    var failed: Bool = false

    enum CodingKeys: String, CodingKey {
        case id = "_id", conversation, senderRole, text, type, fileUrl, fileName, fileSize
        case mimeType, caption, replyTo, replyToSnapshot, edited, deleted, reactions, status
        case callType, buttons, createdAt, clientId
    }

    init(id: String) { self.id = id }
}

// Lenient decoder in an extension (so the memberwise init above is preserved).
// Missing/absent fields fall back to defaults instead of throwing and dropping
// the whole message — payloads vary by message type (text/bot/system/media).
extension ChatMessage {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        conversation = try c.decodeIfPresent(String.self, forKey: .conversation)
        senderRole = try c.decodeIfPresent(String.self, forKey: .senderRole)
        text = try c.decodeIfPresent(String.self, forKey: .text)
        type = try c.decodeIfPresent(String.self, forKey: .type) ?? "text"
        fileUrl = try c.decodeIfPresent(String.self, forKey: .fileUrl)
        fileName = try c.decodeIfPresent(String.self, forKey: .fileName)
        fileSize = try c.decodeIfPresent(Int.self, forKey: .fileSize)
        mimeType = try c.decodeIfPresent(String.self, forKey: .mimeType)
        caption = try c.decodeIfPresent(String.self, forKey: .caption)
        replyTo = try c.decodeIfPresent(String.self, forKey: .replyTo)
        replyToSnapshot = try c.decodeIfPresent(ReplySnapshot.self, forKey: .replyToSnapshot)
        edited = (try? c.decode(Bool.self, forKey: .edited)) ?? false
        deleted = (try? c.decode(Bool.self, forKey: .deleted)) ?? false
        reactions = (try? c.decode([Reaction].self, forKey: .reactions)) ?? []
        status = try c.decodeIfPresent(String.self, forKey: .status)
        callType = try c.decodeIfPresent(String.self, forKey: .callType)
        buttons = (try? c.decode([BotButton].self, forKey: .buttons)) ?? []
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        clientId = try c.decodeIfPresent(String.self, forKey: .clientId)
    }
}

struct ConversationDto: Codable {
    let id: String
    let branch: String?
    let status: String?
    enum CodingKeys: String, CodingKey { case id = "_id", branch, status }
}
