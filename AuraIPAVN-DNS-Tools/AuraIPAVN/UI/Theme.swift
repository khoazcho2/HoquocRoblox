// Theme.swift — AURA IPA VN
import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

enum Theme {
    static let bg = Color(hex: 0x080B10)
    static let card = Color(hex: 0x11161D)
    static let border = Color.white.opacity(0.06)
    static let accent = Color(red: 0.25, green: 0.78, blue: 1.0)
    static let ok = Color(red: 0.2, green: 0.85, blue: 0.5)
    static let bad = Color(red: 1.0, green: 0.32, blue: 0.36)
    static let warn = Color.orange
    static let dim = Color.white.opacity(0.55)
    static let r: CGFloat = 20
}

enum Haptic {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}
