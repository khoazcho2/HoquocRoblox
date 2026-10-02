// SettingsView.swift — AURA IPA VN
import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Card {
                        VStack(spacing: 14) {
                            InfoRow(icon: .info, title: "APP", value: Config.appVersion)
                            InfoRow(icon: .device, title: "MODEL", value: app.device.model)
                            InfoRow(icon: .ios, title: "iOS", value: app.device.osVersion)
                            InfoRow(icon: .info, title: "BUILD", value: app.device.build)
                        }
                    }
                    Card {
                        VStack(spacing: 14) {
                            ForEach(Feature.allCases, id: \.self) { f in
                                let s = app.compat.status(f, app.device)
                                HStack {
                                    Text(f.rawValue).font(.system(size: 13, weight: .medium)).foregroundColor(.white)
                                    Spacer()
                                    StatusPill(text: s.text, color: s.color)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.bg)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}
