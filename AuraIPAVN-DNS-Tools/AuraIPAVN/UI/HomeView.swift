// HomeView.swift — AURA IPA VN
import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSettings = false
    @State private var installStates: [String: InstallState] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Card {
                        VStack(spacing: 14) {
                            InfoRow(icon: .device, title: "THIẾT BỊ", value: app.device.model)
                            InfoRow(icon: .ios, title: "HỆ ĐIỀU HÀNH", value: "iOS \(app.device.osVersion)")
                            InfoRow(icon: .info, title: "BUILD", value: app.device.build)
                            HStack {
                                IconView(icon: .shield, size: 20, color: Theme.accent)
                                Text("TƯƠNG THÍCH").font(.system(size: 12, weight: .medium)).foregroundColor(Theme.dim)
                                Spacer()
                                let c = app.compat.overall(app.device)
                                StatusPill(text: c == .supported ? "CÓ HỖ TRỢ" : (c == .unknown ? "UNKNOWN" : "KHÔNG HỖ TRỢ"),
                                           color: c.color)
                            }
                        }
                    }
                    .appear(0)
                    HStack {
                        Text("ỨNG DỤNG (\(Config.games.count))")
                            .font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.dim)
                        Spacer()
                    }
                    ForEach(Array(Config.games.enumerated()), id: \.element.id) { i, g in
                        NavigationLink(value: g) {
                            let installState = installStates[g.id] ?? .unknown
                            let r = g.readiness(app.compat, app.device, installState: installState)
                            Card {
                                HStack(spacing: 12) {
                                    GameIconView(game: g)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(g.name).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                                        Text(g.id).font(.system(size: 12, design: .monospaced)).foregroundColor(Theme.dim)
                                    }
                                    Spacer()
                                    StatusPill(text: r.0, color: r.1)
                                    IconView(icon: .chevron, size: 16, color: Theme.dim)
                                }
                            }
                        }
                        .buttonStyle(PressStyle())
                        .simultaneousGesture(TapGesture().onEnded { Haptic.tap() })
                        .appear(0.15 + 0.1 * Double(i))
                    }
                }
                .padding(20)
            .instantTouch()
            }
            .background(Theme.bg)
            .navigationDestination(for: Game.self) { GameDetailView(game: $0) }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("AURA IPA VN").font(.system(size: 16, weight: .bold, design: .rounded))
                        Text(Config.appVersion).font(.system(size: 10)).foregroundColor(Theme.dim)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Haptic.tap(); showSettings = true } label: { IconView(icon: .settings, size: 22) }
                }
            }
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .onAppear(perform: refreshInstallStates)
        .onChange(of: scenePhase) { phase in
            if phase == .active { refreshInstallStates() }
        }
    }

    @MainActor
    private func refreshInstallStates() {
        installStates = Dictionary(
            uniqueKeysWithValues: Config.games.map { ($0.id, $0.installState) }
        )
    }
}
