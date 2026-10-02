// ProxyMenuView.swift — AURA IPA VN
import SwiftUI
import UIKit

struct ProxyMenuView: View {
    private let items = ["Proxy 01", "Proxy 02", "Proxy 03", "Proxy 04"]
    var body: some View {
        VStack(spacing: 12) {
            ForEach(items, id: \.self) { name in
                Card {
                    HStack(spacing: 12) {
                        IconView(icon: .proxy, size: 22, color: Theme.accent)
                        Text(name).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                        Spacer()
                        StatusPill(text: "NOT CONFIGURED", color: Theme.dim)
                        Toggle("", isOn: .constant(false)).labelsHidden().disabled(true)
                    }
                }
            }
        }
    }
}
