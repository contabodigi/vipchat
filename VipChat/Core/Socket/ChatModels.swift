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
    var id: String
    var conversation: String?
    var senderRole: String?
    var text: String?
    var type: String = "text"
    var fileUrl: String?
    var fileName: String?
    var fileSize: Int?
    var mimeType: String?
    var caption: String?
    var replyTo: String?
    var replyToSnapshot: ReplySnapshot?
    var edited: Bool = false
    var deleted: Bool = false
    var reactions: [Reaction] = []
    var status: String?
    var callType: String?
    var buttons: [BotButton] = []
    var createdAt: String?
    var clientId: String?

    // client-only send state (not from server)
    var localId: String?
    var pending: Bool = false
    var failed: Bool = false

    enum CodingKeys: String, CodingKey {
        case id = "_id", conversation, senderRole, text, type, fileUrl, fileName, fileSize
        case mimeType, caption, replyTo, replyToSnapshot, edited, deleted, reactions, status
        case callType, buttons, createdAt, clientId
    }
}

struct ConversationDto: Codable {
    let id: String
    let branch: String?
    let status: String?
    enum CodingKeys: String, CodingKey { case id = "_id", branch, status }
}
