import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage
    let onReply: (ChatMessage) -> Void
    let onReact: (String, String) -> Void
    let onRetry: (ChatMessage) -> Void
    let onBotButton: (BotButton) -> Void

    private let quickEmojis = ["👍", "❤️", "😂", "😮", "🙏", "🔥"]

    private var isMine: Bool { message.senderRole == "customer" }
    private var isBot: Bool { message.senderRole == "bot" }
    private var isSystem: Bool { message.senderRole == "system" || message.type == "call" }
    private var actionable: Bool { !message.deleted && !message.pending && !message.failed && message.localId == nil }

    var body: some View {
        if isSystem {
            Text(message.text ?? "")
                .font(.system(size: 12)).italic().foregroundColor(.waMuted)
                .frame(maxWidth: .infinity).padding(.vertical, 6)
        } else {
            HStack {
                if isMine { Spacer(minLength: 40) }
                VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
                    bubble
                    if !message.reactions.isEmpty { reactionsRow }
                }
                if !isMine { Spacer(minLength: 40) }
            }
            .padding(.vertical, 3)
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            if message.deleted {
                Text("This message was deleted").font(.system(size: 13)).italic().foregroundColor(.waMuted)
            } else {
                if let snap = message.replyToSnapshot { replyQuote(snap) }
                content
                if let cap = message.caption, !cap.isEmpty, message.type != "text" {
                    Text(cap).font(.system(size: 13)).foregroundColor(.waText)
                }
                if isBot, !message.buttons.isEmpty { botButtons }
            }
            metaRow
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(isMine ? Color.waMine : Color.waPanel)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contextMenu { if actionable { menu } }
        .onTapGesture { if message.failed { onRetry(message) } }
    }

    @ViewBuilder private var content: some View {
        switch message.type {
        case "image":
            AsyncImage(url: mediaURL()) { $0.resizable().scaledToFit() } placeholder: { Color.waInput.frame(height: 140) }
                .frame(maxWidth: 240).cornerRadius(8)
        case "voice", "audio":
            Label("Voice message", systemImage: "play.circle.fill").foregroundColor(.waText).font(.system(size: 14))
        case "video":
            Label("Video", systemImage: "video.fill").foregroundColor(.waText).font(.system(size: 14))
        case "file":
            Label(message.fileName ?? "File", systemImage: "doc.fill").foregroundColor(.waText).font(.system(size: 14))
        default:
            if let t = message.text, !t.isEmpty { Text(t).font(.system(size: 15)).foregroundColor(.waText) }
        }
    }

    private func replyQuote(_ snap: ReplySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text((snap.senderRole ?? "Reply").capitalized).font(.system(size: 11, weight: .bold)).foregroundColor(.waGreen)
            Text(snap.text ?? snap.fileName ?? "media").font(.system(size: 12)).foregroundColor(.waMuted).lineLimit(1)
        }
        .padding(6).background(Color.black.opacity(0.06)).cornerRadius(6)
    }

    private var botButtons: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(message.buttons.enumerated()), id: \.offset) { _, b in
                Button { onBotButton(b) } label: {
                    Text(b.text ?? "").font(.system(size: 12, weight: .bold)).foregroundColor(.waText)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.waGreen.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.waGreen.opacity(0.45)))
                        .cornerRadius(15)
                }
            }
        }.padding(.top, 4)
    }

    private var metaRow: some View {
        HStack(spacing: 3) {
            Text(time()).font(.system(size: 10)).foregroundColor(.waMuted)
            if message.edited { Text("· edited").font(.system(size: 10)).foregroundColor(.waMuted) }
            if isMine {
                if message.failed { Text("failed — tap to retry").font(.system(size: 10, weight: .bold)).foregroundColor(.vipError) }
                else if message.pending { Image(systemName: "clock").font(.system(size: 9)).foregroundColor(.waMuted) }
                else { Text(message.status == "read" ? "✓✓" : "✓").font(.system(size: 11, weight: .bold)).foregroundColor(message.status == "read" ? .waBlueRead : .waTickSent) }
            }
        }.frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var reactionsRow: some View {
        HStack(spacing: 3) {
            ForEach(groupedReactions(), id: \.0) { emoji, count in
                HStack(spacing: 2) {
                    Text(emoji).font(.system(size: 12))
                    if count > 1 { Text("\(count)").font(.system(size: 11)).foregroundColor(.waMuted) }
                }
                .padding(.horizontal, 6).padding(.vertical, 2).background(Color.waInput).cornerRadius(12)
            }
        }
    }

    private var menu: some View {
        Group {
            Button { onReply(message) } label: { Label("Reply", systemImage: "arrowshape.turn.up.left") }
            ForEach(quickEmojis, id: \.self) { e in
                Button { onReact(message.id, e) } label: { Text("\(e)  React") }
            }
        }
    }

    private func groupedReactions() -> [(String, Int)] {
        Dictionary(grouping: message.reactions, by: \.emoji).map { ($0.key, $0.value.count) }.sorted { $0.0 < $1.0 }
    }
    private func mediaURL() -> URL? {
        guard let p = message.fileUrl else { return nil }
        return URL(string: p.hasPrefix("http") ? p : AppEnv.apiBase + p)
    }
    private func time() -> String {
        guard let s = message.createdAt, let d = ISO8601DateFormatter().date(from: s) else { return "" }
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f.string(from: d)
    }
}
