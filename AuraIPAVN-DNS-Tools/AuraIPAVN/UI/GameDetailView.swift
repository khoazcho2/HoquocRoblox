// GameDetailView.swift — AURA IPA VN
import SwiftUI
import UIKit

struct GameDetailView: View {
    enum Tab: String, CaseIterable { case proxy = "PROXY MENU", dns = "DNS" }
    @EnvironmentObject var app: AppState
    @Namespace private var tabNS
    let game: Game
    @State private var tab: Tab = .proxy
    @State private var glow = false
    @State private var openFailed = false

    var body: some View {
        let r = game.readiness(app.compat, app.device)
        let canOpen = r.0 != "NOT SUPPORTED"
        ScrollView {
            VStack(spacing: 16) {
                header(r).appear(0)
                tabBar.appear(0.08)

                // Nội dung tab đổi mượt (mờ + thu phóng nhẹ)
                Group {
                    if tab == .proxy {
                        ProxyMenuView()
                    } else {
                        VStack(spacing: 16) {
                            DNSView(dns: app.dns)
                            DNSToolsView(model: app.dnsTools)
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.97)))

                openButton(canOpen: canOpen).appear(0.16)
                if openFailed {
                    Text("Không mở được game. Kiểm tra game đã cài chưa (nếu đã cài mà vẫn lỗi, URL scheme có thể chưa đúng).")
                        .font(.system(size: 12)).foregroundColor(Theme.warn)
                        .multilineTextAlignment(.center)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(20)
            .instantTouch()
        }
        .background(Theme.bg)
        .navigationTitle(game.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(_ r: (String, Color)) -> some View {
        Card {
            HStack(spacing: 12) {
                GameIconView(game: game)
                VStack(alignment: .leading, spacing: 4) {
                    Text(game.name).font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                    Text(game.id).font(.system(size: 12, design: .monospaced)).foregroundColor(Theme.dim)
                }
                Spacer()
                StatusPill(text: r.0, color: r.1)
            }
        }
    }

    // Thanh tab có nền trượt theo tab đang chọn
    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button {
                    Haptic.tap()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { tab = t }
                } label: {
                    Text(t.rawValue)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .foregroundColor(tab == t ? Theme.accent : Theme.dim)
                        .background {
                            if tab == t {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Theme.accent.opacity(0.18))
                                    .matchedGeometryEffect(id: "tab", in: tabNS)
                            }
                        }
                }
            }
        }
        .padding(4)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    // Nút MỞ GAME NGAY: phát sáng nhịp thở, nhún khi chạm
    private func openButton(canOpen: Bool) -> some View {
        Button {
            Haptic.tap()
            game.open { ok in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { openFailed = !ok }
                if ok { Haptic.success() } else { Haptic.error() }
            }
        } label: {
            Text("MỞ GAME NGAY")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.r))
                .foregroundColor(Theme.bg)
                .shadow(color: Theme.accent.opacity(canOpen ? (glow ? 0.55 : 0.15) : 0),
                        radius: glow ? 18 : 6, y: 4)
        }
        .buttonStyle(PressStyle())
        .disabled(!canOpen)
        .opacity(canOpen ? 1 : 0.4)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { glow = true }
        }
    }
}
