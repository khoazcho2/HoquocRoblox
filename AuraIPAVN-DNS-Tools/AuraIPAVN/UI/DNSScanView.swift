// DNSScanView.swift — AURA IPA VN
// Màn "Quét & chặn domain": mọi số liệu lấy thật từ NextDNS, không có số giả.
import SwiftUI

@MainActor
final class DNSScanModel: ObservableObject {
    enum Step: Equatable { case pending, running, done, skipped(String), failed(String) }

    @Published var connect: Step = .running
    @Published var filter: Step = .pending
    @Published var total = 0
    @Published var blocked = 0
    @Published var recent: [DomainStat] = []
    private var task: Task<Void, Never>?

    var live: Bool { connect == .done }

    func start(dns: DNSManager) {
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            // 1. Chờ máy thực sự dùng DNS NextDNS (tối đa ~2 phút)
            self.connect = .running
            var ok = false
            for _ in 0..<60 {
                if Task.isCancelled { return }
                if await dns.verify() { ok = true; break }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
            guard ok else {
                self.connect = .failed("Chưa thấy DNS NextDNS hoạt động. Cài hồ sơ DNS xong rồi mở lại màn này.")
                return
            }
            self.connect = .done

            // 2. Bật các bộ lọc quảng cáo/theo dõi trên profile
            self.filter = .running
            if let api = NextDNSAPI.current {
                do {
                    let active = try await api.activeBlocklists()
                    for p in DNSToolsModel.presets where !active.contains(p.id) {
                        try await api.setBlocklist(p.id, on: true)
                    }
                    self.filter = .done
                } catch {
                    self.filter = .failed(error.localizedDescription)
                }
            } else {
                self.filter = .skipped("Chưa có API key — dùng bộ lọc sẵn trong profile NextDNS.")
            }

            // 3. Cập nhật số liệu thật mỗi 3 giây
            while !Task.isCancelled {
                if let api = NextDNSAPI.current, let s = try? await api.status() {
                    self.total = s.values.reduce(0, +)
                    self.blocked = s["blocked"] ?? 0
                    if let r = try? await api.topDomains(blockedOnly: true, limit: 6) { self.recent = r }
                }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    func stop() { task?.cancel() }
}

struct DNSScanView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = DNSScanModel()
    @State private var spin = false
    @State private var pulse = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("QUÉT & CHẶN DOMAIN")
                    .font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                    .padding(.top, 8)
                radar
                Card {
                    VStack(spacing: 14) {
                        stepRow("Kết nối NextDNS", model.connect)
                        stepRow("Bật bộ lọc quảng cáo & theo dõi", model.filter)
                    }
                }
                if model.live {
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                counter("TRUY VẤN 24H", model.total, Theme.accent)
                                Spacer()
                                counter("ĐÃ CHẶN 24H", model.blocked, Theme.bad)
                            }
                            if !model.recent.isEmpty {
                                Text("DOMAIN BỊ CHẶN NHIỀU NHẤT")
                                    .font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.dim)
                                ForEach(model.recent) { d in
                                    HStack {
                                        Text(d.domain).font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(.white).lineLimit(1).truncationMode(.middle)
                                        Spacer()
                                        Text("\(d.queries)").font(.system(size: 12, weight: .semibold, design: .monospaced))
                                            .foregroundColor(Theme.bad)
                                    }
                                    .transition(.opacity.combined(with: .move(edge: .leading)))
                                }
                            }
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: model.recent)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
                Text("Chặn theo domain nên không loại hết mọi quảng cáo (ví dụ quảng cáo phát chung domain với nội dung).")
                    .font(.system(size: 11)).foregroundColor(Theme.dim).multilineTextAlignment(.center)
                Button { Haptic.tap(); dismiss() } label: {
                    Text("ĐÓNG").font(.system(size: 14, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Theme.accent.opacity(0.18), in: RoundedRectangle(cornerRadius: 16))
                        .foregroundColor(Theme.accent)
                }
                .buttonStyle(PressStyle())
            }
            .padding(20)
            .instantTouch()
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: model.live)
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear {
            model.start(dns: app.dns)
            withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) { spin = true }
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { pulse = true }
        }
        .onDisappear { model.stop() }
    }

    // Radar quét: xoay liên tục, sáng khi đã kết nối NextDNS
    private var radar: some View {
        let c = model.live ? Theme.ok : Theme.accent
        return ZStack {
            Circle().stroke(c.opacity(0.15), lineWidth: 1).frame(width: 190, height: 190)
            Circle().stroke(c.opacity(0.25), lineWidth: 1).frame(width: 130, height: 130)
            Circle().fill(c.opacity(pulse ? 0.22 : 0.08)).frame(width: 90, height: 90)
            Circle().trim(from: 0, to: 0.28)
                .stroke(c, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 190, height: 190)
                .rotationEffect(.degrees(spin ? 360 : 0))
                .opacity(model.live ? 1 : 0.6)
            IconView(icon: .shield, size: 34, color: c)
        }
        .frame(height: 210)
    }

    private func counter(_ title: String, _ value: Int, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.dim)
            Text("\(value)").font(.system(size: 26, weight: .bold, design: .rounded)).foregroundColor(color)
                .contentTransition(.numericText())
                .animation(.default, value: value)
        }
    }

    private func stepRow(_ title: String, _ step: DNSScanModel.Step) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Group {
                    switch step {
                    case .pending: IconView(icon: .info, size: 18, color: Theme.dim)
                    case .running: ProgressView().tint(Theme.accent)
                    case .done: IconView(icon: .check, size: 18, color: Theme.ok)
                    case .skipped: IconView(icon: .info, size: 18, color: Theme.warn)
                    case .failed: IconView(icon: .error, size: 18, color: Theme.bad)
                    }
                }
                .frame(width: 22, height: 22)
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                Spacer()
            }
            switch step {
            case .skipped(let m), .failed(let m):
                Text(m).font(.system(size: 11)).foregroundColor(Theme.dim).padding(.leading, 32)
            default: EmptyView()
            }
        }
    }
}
