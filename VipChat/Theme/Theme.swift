import SwiftUI

/// Colors mirror the Android app. Casino gold theme for the login screen; the
/// WhatsApp-style light palette for the chat.
extension Color {
    // Casino / login
    static let vipBgTop = Color(hex: 0x1F1A0D)
    static let vipBgBottom = Color(hex: 0x14110E)
    static let vipCardTop = Color(hex: 0x322710)
    static let vipCardBottom = Color(hex: 0x1D170C)
    static let vipCardBorder = Color(hex: 0x7A5F26)
    static let vipGold1 = Color(hex: 0xC89B2F)
    static let vipGold2 = Color(hex: 0xF7EF8A)
    static let vipGold3 = Color(hex: 0xE4BC52)
    static let vipTextHeading = Color(hex: 0xF7EFCE)
    static let vipTextSecondary = Color(hex: 0xB8A888)
    static let vipTextAccent = Color(hex: 0xF0CF6D)
    static let vipInputBg = Color(hex: 0x100D08)
    static let vipInputBorder = Color(hex: 0x4A3A18)
    static let vipError = Color(hex: 0xE85C5C)

    // WhatsApp-style chat
    static let waGreen = Color(hex: 0x25D366)
    static let waGreenDeep = Color(hex: 0x128C7E)
    static let waBlueRead = Color(hex: 0x53BDEB)
    static let waChatBg = Color(hex: 0xEFE7DC)
    static let waPanel = Color.white
    static let waText = Color(hex: 0x111B21)
    static let waMuted = Color(hex: 0x667781)
    static let waInput = Color(hex: 0xF0F2F5)
    static let waMine = Color(hex: 0xD9FDD3)
    static let waTickSent = Color(hex: 0x8696A0)
    static let brandGreen = Color(hex: 0x28D648)

    init(hex: UInt) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}
