// NextDNSAPI.swift — AURA IPA VN
import Foundation

struct DomainStat: Identifiable, Hashable {
    var id: String { domain }
    let domain: String
    let queries: Int
}

struct BlockPreset: Identifiable {
    let id: String        // ID blocklist của NextDNS
    let title: String
    let subtitle: String
}

enum NextDNSError: LocalizedError {
    case notConfigured
    case http(Int)
    case badData

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Chưa cấu hình NextDNS profile ID / API key."
        case .http(let c): return c == 403 || c == 401 ? "API key không hợp lệ (HTTP \(c))." : "NextDNS trả lỗi HTTP \(c)."
        case .badData: return "Dữ liệu NextDNS không đọc được."
        }
    }
}

// Client REST: https://nextdns.github.io/api
struct NextDNSAPI {
    let profile: String
    let key: String

    static var current: NextDNSAPI? {
        guard !Config.nextDNSProfileID.isEmpty, !Config.nextDNSAPIKey.isEmpty else { return nil }
        return NextDNSAPI(profile: Config.nextDNSProfileID, key: Config.nextDNSAPIKey)
    }

    private func call(_ path: String, method: String = "GET", body: [String: Any]? = nil) async throws -> Data {
        guard let url = URL(string: "https://api.nextdns.io/profiles/\(profile)/\(path)") else { throw NextDNSError.badData }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = method
        req.setValue(key, forHTTPHeaderField: "X-Api-Key")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else { throw NextDNSError.http(code) }
        return data
    }

    private func rows(_ data: Data) throws -> [[String: Any]] {
        guard let o = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let a = o["data"] as? [[String: Any]] else { throw NextDNSError.badData }
        return a
    }

    // Tổng truy vấn: [status: số lượng] (default / blocked / allowed ...)
    func status() async throws -> [String: Int] {
        let r = try rows(try await call("analytics/status?from=-24h"))
        var out: [String: Int] = [:]
        for x in r { if let s = x["status"] as? String, let q = x["queries"] as? Int { out[s] = q } }
        return out
    }

    // Top domain 24h gần nhất; blockedOnly = chỉ domain bị chặn
    func topDomains(blockedOnly: Bool, limit: Int = 10) async throws -> [DomainStat] {
        let st = blockedOnly ? "&status=blocked" : ""
        let r = try rows(try await call("analytics/domains?from=-24h&limit=\(limit)\(st)"))
        return r.compactMap {
            guard let d = $0["domain"] as? String, let q = $0["queries"] as? Int else { return nil }
            return DomainStat(domain: d, queries: q)
        }
    }

    func activeBlocklists() async throws -> Set<String> {
        Set(try rows(try await call("privacy/blocklists")).compactMap { $0["id"] as? String })
    }

    func setBlocklist(_ id: String, on: Bool) async throws {
        if on { _ = try await call("privacy/blocklists", method: "POST", body: ["id": id]) }
        else { _ = try await call("privacy/blocklists/\(id)", method: "DELETE") }
    }

    func deny(_ domain: String) async throws {
        _ = try await call("denylist", method: "POST", body: ["id": domain, "active": true])
    }
}
