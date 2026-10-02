// Components.swift — AURA IPA VN
import SwiftUI
import UIKit

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.r))
            .overlay(RoundedRectangle(cornerRadius: Theme.r).stroke(Theme.border, lineWidth: 1))
    }
}

struct StatusPill: View {
    let text: String
    let color: Color
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(color)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule())
    }
}

struct InfoRow: View {
    let icon: AuraIcon, title: String, value: String
    var body: some View {
        HStack(spacing: 12) {
            IconView(icon: icon, size: 20, color: Theme.accent)
            Text(title).font(.system(size: 12, weight: .medium)).foregroundColor(Theme.dim)
            Spacer()
            Text(value).font(.system(size: 14, weight: .semibold, design: .monospaced)).foregroundColor(.white)
        }
    }
}

struct GameIconView: View {
    let game: Game

    var body: some View {
        Group {
            if let assetName = game.iconAssetName {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Theme.accent.opacity(0.12))
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 23, weight: .medium))
                        .foregroundColor(Theme.accent)
                }
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .accessibilityHidden(true)
    }
}

// Nút nhún nhẹ khi chạm
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// Hiện dần + trượt lên khi xuất hiện, có thể trễ để tạo hiệu ứng lần lượt
struct Appear: ViewModifier {
    let delay: Double
    @State private var on = false
    func body(content: Content) -> some View {
        content
            .opacity(on ? 1 : 0)
            .offset(y: on ? 0 : 18)
            .scaleEffect(on ? 1 : 0.97)
            .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.82).delay(delay)) { on = true } }
    }
}

extension View {
    func appear(_ delay: Double = 0) -> some View { modifier(Appear(delay: delay)) }
}
