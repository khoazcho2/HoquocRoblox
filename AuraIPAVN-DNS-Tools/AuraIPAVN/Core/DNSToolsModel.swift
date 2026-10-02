// DNSToolsModel.swift — AURA IPA VN
import SwiftUI
import Foundation

struct PingResult: Equatable {
    let min: Double, avg: Double, jitter: Double   // ms
    var label: String { avg < 40 ? "MƯỢT" : avg < 90 ? "ỔN" : "CHẬM" }
    var color: Color { avg < 40 ? Theme.ok : avg < 90 ? Theme.warn : Theme.bad }
}

@MainActor
final class DNSToolsModel: ObservableObject {
    enum Load: Equatable { case idle, loading, ok, notConfigured, error(String) }

    static let presets = [
        BlockPreset(id: "nextdns-recommended", title: "Chặn domain rác & theo dõi", subtitle: "Danh sách khuyến nghị của NextDNS"),
        BlockPreset(id: "oisd", title: "Quảng cáo & telemetry", subtitle: "OISD — chặn rộng hơn")
    ]

    @Published var load: Load = .idle
    @Published var total = 0
    @Published var blocked = 0
    @Published var topAll: [DomainStat] = []
    @Published var topBlocked: [DomainStat] = []
    @Published var active: Set<String> = []
    @Published var busy: Set<String> = []
    @Published var ping: PingResult?
    @Published var pinging = false
    @Published var note: String?

    var blockedPercent: Int { total > 0 ? Int((Double(blocked) / Double(total) * 100).rounded()) : 0 }

    func refresh() async {
        guard let api = NextDNSAPI.current else { load = .notConfigured; return }
        load = .loading
        do {
            async let st = api.status()
            async let all = api.topDomains(blockedOnly: false)
            async let bl = api.topDomains(blockedOnly: true)
            async let lists = api.activeBlocklists()
            let s = try await st
            total = s.values.reduce(0, +)
            blocked = s["blocked"] ?? 0
            topAll = try await all
            topBlocked = try await bl
            active = try await lists
            load = .ok
        } catch {
            load = .error(error.localizedDescription)
        }
    }

    func toggle(_ id: String) async {
        guard let api = NextDNSAPI.current, !busy.contains(id) else { return }
        let want = !active.contains(id)
        busy.insert(id); defer { busy.remove(id) }
        do {
            try await api.setBlocklist(id, on: want)
            if want { active.insert(id) } else { active.remove(id) }
            Haptic.success()
        } catch {
            note = error.localizedDescription
            Haptic.error()
        }
    }

    func deny(_ raw: String) async {
        let d = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard d.contains("."), !d.contains(" "), let api = NextDNSAPI.current else {
            note = "Domain không hợp lệ."; return
        }
        do {
            try await api.deny(d)
            note = "Đã chặn \(d)"
            Haptic.success()
        } catch {
            note = error.localizedDescription
            Haptic.error()
        }
    }

    // Đo độ trễ DoH thật: 6 truy vấn, bỏ mẫu đầu (bắt tay TLS)
    func measurePing() async {
        guard !pinging else { return }
        pinging = true; defer { pinging = false }
        let base = Config.nextDNSProfileID.isEmpty ? "https://dns.nextdns.io" : "https://dns.nextdns.io/\(Config.nextDNSProfileID)"
        guard let url = URL(string: "\(base)?dns=\(Self.query("apple.com"))") else { return }
        let cfg = URLSessionConfiguration.ephemeral
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: cfg)
        var req = URLRequest(url: url, timeoutInterval: 5)
        req.setValue("application/dns-message", forHTTPHeaderField: "Accept")
        var samples: [Double] = []
        for i in 0..<6 {
            let t0 = CFAbsoluteTimeGetCurrent()
            do {
                let (_, r) = try await session.data(for: req)
                guard (r as? HTTPURLResponse)?.statusCode == 200 else { continue }
                if i > 0 { samples.append((CFAbsoluteTimeGetCurrent() - t0) * 1000) }
            } catch { continue }
        }
        guard !samples.isEmpty else { ping = nil; note = "Không đo được DNS (mất mạng?)."; return }
        ping = PingResult(min: samples.min()!, avg: samples.reduce(0, +) / Double(samples.count),
                          jitter: samples.max()! - samples.min()!)
    }

    // Gói DNS wire-format (RFC 8484), base64url không padding
    private static func query(_ name: String) -> String {
        var d = Data([0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0])
        for l in name.split(separator: ".") { d.append(UInt8(l.utf8.count)); d.append(contentsOf: Array(l.utf8)) }
        d.append(contentsOf: [0, 0, 1, 0, 1])   // kết thúc QNAME, type A, class IN
        return d.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}
