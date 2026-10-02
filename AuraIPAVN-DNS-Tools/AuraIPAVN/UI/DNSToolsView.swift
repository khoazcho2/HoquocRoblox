// DNSToolsView.swift — AURA IPA VN
import SwiftUI

struct DNSToolsView: View {
    @ObservedObject var model: DNSToolsModel
    @State private var custom = ""

    var body: some View {
        VStack(spacing: 16) {
            pingCard
            blockCard
            statsCard
        }
        .task { await model.refresh(); await model.measurePing() }
    }

    // MARK: DNS mượt — đo độ trễ thật
    private var pingCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    IconView(icon: .dns, size: 22, color: Theme.accent)
                    Text("DNS MƯỢT").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    Spacer()
                    if let p = model.ping { StatusPill(text: p.label, color: p.color) }
                }
                if let p = model.ping {
                    InfoRow(icon: .dns, title: "Trung bình", value: String(format: "%.0f ms", p.avg))
                    InfoRow(icon: .dns, title: "Thấp nhất", value: String(format: "%.0f ms", p.min))
                    InfoRow(icon: .dns, title: "Dao động", value: String(format: "%.0f ms", p.jitter))
                }
                Button { Haptic.tap(); Task { await model.measurePing() } } label: {
                    Text(model.pinging ? "ĐANG ĐO..." : "ĐO LẠI")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Theme.accent.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
                        .foregroundColor(Theme.accent)
                }.disabled(model.pinging)
            }
        }
    }

    // MARK: Chặn domain rác
    private var blockCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("CHẶN DOMAIN RÁC").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                if model.load == .notConfigured {
                    Text("Cần cấu hình nextDNSProfileID và nextDNSAPIKey trong Config.swift.")
                        .font(.system(size: 12)).foregroundColor(Theme.dim)
                } else {
                    ForEach(DNSToolsModel.presets) { p in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.title).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                                Text(p.subtitle).font(.system(size: 11)).foregroundColor(Theme.dim)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(get: { model.active.contains(p.id) },
                                                     set: { _ in Task { await model.toggle(p.id) } }))
                                .labelsHidden().disabled(model.busy.contains(p.id) || model.load == .loading)
                        }
                    }
                    HStack(spacing: 8) {
                        TextField("domain cần chặn", text: $custom)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .font(.system(size: 13, design: .monospaced)).foregroundColor(.white)
                            .padding(10).background(Theme.bg, in: RoundedRectangle(cornerRadius: 12))
                        Button { Haptic.tap(); let d = custom; custom = ""; Task { await model.deny(d); await model.refresh() } } label: {
                            Text("CHẶN").font(.system(size: 12, weight: .bold, design: .rounded))
                                .padding(.horizontal, 14).padding(.vertical, 11)
                                .background(Theme.bad.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
                                .foregroundColor(Theme.bad)
                        }
                    }
                }
                if let n = model.note { Text(n).font(.system(size: 12)).foregroundColor(Theme.dim) }
            }
        }
    }

    // MARK: Thống kê domain (24 giờ)
    private var statsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("THỐNG KÊ DOMAIN · 24H").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    Spacer()
                    Button { Haptic.tap(); Task { await model.refresh() } } label: {
                        Text("LÀM MỚI").font(.system(size: 11, weight: .bold)).foregroundColor(Theme.accent)
                    }
                }
                switch model.load {
                case .loading: ProgressView().tint(Theme.accent)
                case .error(let m): Text(m).font(.system(size: 12)).foregroundColor(Theme.bad)
                case .ok:
                    InfoRow(icon: .dns, title: "Tổng truy vấn", value: "\(model.total)")
                    InfoRow(icon: .dns, title: "Đã chặn", value: "\(model.blocked) (\(model.blockedPercent)%)")
                    list("TOP BỊ CHẶN", model.topBlocked, Theme.bad)
                    list("TOP TRUY VẤN", model.topAll, Theme.accent)
                default: EmptyView()
                }
            }
        }
    }

    @ViewBuilder
    private func list(_ title: String, _ items: [DomainStat], _ color: Color) -> some View {
        if !items.isEmpty {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.dim).padding(.top, 4)
            ForEach(items) { s in
                HStack {
                    Text(s.domain).font(.system(size: 12, design: .monospaced)).foregroundColor(.white)
                        .lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Text("\(s.queries)").font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(color)
                }
            }
        }
    }
}
