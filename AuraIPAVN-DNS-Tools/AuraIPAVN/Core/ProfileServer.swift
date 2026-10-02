// ProfileServer.swift — AURA IPA VN
// Phục vụ file .mobileconfig qua 127.0.0.1 để Safari tải về → iOS hỏi cài hồ sơ DNS.
import Foundation
import Network
import UIKit

enum AuraProfile {
    // UUID cố định: cài lại sẽ cập nhật hồ sơ cũ thay vì tạo bản trùng
    static func data(profileID: String) -> Data {
        let inner: [String: Any] = [
            "DNSSettings": ["DNSProtocol": "HTTPS", "ServerURL": "https://dns.nextdns.io/\(profileID)"],
            "PayloadDescription": "Dùng DNS NextDNS của AURA",
            "PayloadDisplayName": "AURA DNS",
            "PayloadIdentifier": "com.aura.ipavn.dns",
            "PayloadType": "com.apple.dnsSettings.managed",
            "PayloadUUID": "6F1B6E52-2C2D-4B7A-9D55-0A1E3C7F4A10",
            "PayloadVersion": 1
        ]
        let root: [String: Any] = [
            "PayloadContent": [inner],
            "PayloadDescription": "Cấu hình DNS-over-HTTPS AURA (NextDNS)",
            "PayloadDisplayName": "AURA DNS",
            "PayloadIdentifier": "com.aura.ipavn.profile",
            "PayloadRemovalDisallowed": false,
            "PayloadType": "Configuration",
            "PayloadUUID": "B2D0A9E4-7C51-4E38-8F6A-5D9C1E2B7A33",
            "PayloadVersion": 1
        ]
        return (try? PropertyListSerialization.data(fromPropertyList: root, format: .xml, options: 0)) ?? Data()
    }
}

final class ProfileServer {
    private let q = DispatchQueue(label: "aura.profile.server")
    private var listener: NWListener?
    private var bg: UIBackgroundTaskIdentifier = .invalid

    // Khởi động server, trả về URL cục bộ (nil nếu lỗi)
    func start(body: Data, ready: @escaping (URL?) -> Void) {
        stop()
        var fired = false
        let finish: (URL?) -> Void = { url in
            guard !fired else { return }
            fired = true
            DispatchQueue.main.async { ready(url) }
        }
        do {
            let l = try NWListener(using: .tcp)
            l.stateUpdateHandler = { st in
                switch st {
                case .ready:
                    if let p = l.port { finish(URL(string: "http://127.0.0.1:\(p.rawValue)/AURA-DNS.mobileconfig")) }
                    else { finish(nil) }
                case .failed: finish(nil)
                default: break
                }
            }
            l.newConnectionHandler = { c in
                c.start(queue: self.q)
                c.receive(minimumIncompleteLength: 1, maximumLength: 8192) { _, _, _, _ in
                    let head = "HTTP/1.1 200 OK\r\nContent-Type: application/x-apple-aspen-config\r\n"
                        + "Content-Disposition: attachment; filename=\"AURA-DNS.mobileconfig\"\r\n"
                        + "Content-Length: \(body.count)\r\nConnection: close\r\n\r\n"
                    var d = Data(head.utf8); d.append(body)
                    c.send(content: d, completion: .contentProcessed { _ in c.cancel() })
                }
            }
            listener = l
            l.start(queue: q)
            // Giữ app sống ngắn hạn khi Safari đang tải file; tự tắt sau 2 phút
            DispatchQueue.main.async {
                self.bg = UIApplication.shared.beginBackgroundTask(withName: "aura-profile") { [weak self] in self?.stop() }
            }
            q.asyncAfter(deadline: .now() + 120) { [weak self] in self?.stop() }
        } catch {
            finish(nil)
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        DispatchQueue.main.async {
            if self.bg != .invalid { UIApplication.shared.endBackgroundTask(self.bg); self.bg = .invalid }
        }
    }
}
