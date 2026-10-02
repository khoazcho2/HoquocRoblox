// DNSView.swift — AURA IPA VN
import SwiftUI
import UIKit

struct DNSView: View {
    @EnvironmentObject var app: AppState
    @ObservedObject var dns: DNSManager

    private var message: String? {
        switch dns.state {
        case .error(let m), .unsupported(let m): return m
        default: return dns.hint
        }
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    IconView(icon: .dns, size: 24, color: Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DNS NextDNS").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                        Text("DNS-OVER-HTTPS").font(.system(size: 11)).foregroundColor(Theme.dim)
                    }
                    Spacer()
                    StatusPill(text: dns.state.text, color: dns.state.color)
                }
                if let m = message {
                    HStack(alignment: .top, spacing: 8) {
                        IconView(icon: .warning, size: 16, color: Theme.warn)
                        Text(m).font(.system(size: 12)).foregroundColor(Theme.dim)
                    }
                }
                HStack(spacing: 12) {
                    Button {
                        Haptic.tap()
                        Task { await dns.enable(compat: app.compat, device: app.device) }
                    } label: {
                        HStack(spacing: 8) {
                            IconView(icon: .power, size: 18, color: Theme.bg)
                            Text("BẬT DNS")
                        }
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundColor(Theme.bg)
                    }
                    .disabled(dns.state == .connecting)

                    Button {
                        Haptic.tap()
                        Task { await dns.disable() }
                    } label: {
                        HStack(spacing: 8) {
                            IconView(icon: .power, size: 18, color: Theme.bad)
                            Text("TẮT DNS")
                        }
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Theme.bad.opacity(0.14), in: RoundedRectangle(cornerRadius: 16))
                        .foregroundColor(Theme.bad)
                    }
                    .disabled(dns.state == .connecting)
                }
            }
        }
        .task { await dns.refresh() }
    }
}
