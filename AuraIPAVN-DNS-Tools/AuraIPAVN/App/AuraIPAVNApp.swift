// AuraIPAVNApp.swift — AURA IPA VN
import SwiftUI
import UIKit

@main
struct AuraIPAVNApp: App {
    @StateObject private var app = AppState()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            ZStack {
                Theme.bg.ignoresSafeArea()
                HomeView()
            }
            .environmentObject(app)
            .preferredColorScheme(.dark)
            // Đọc lại trạng thái DNS thật mỗi khi quay lại app
            .onChange(of: phase) { p in
                if p == .active { Task { await app.dns.refresh() } }
            }
        }
    }
}
