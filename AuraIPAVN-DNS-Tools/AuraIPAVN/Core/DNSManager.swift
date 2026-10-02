// DNSManager.swift — AURA IPA VN
import SwiftUI
import UIKit
import NetworkExtension

enum DNSState: Equatable {
    case disconnected, connecting, connected
    case error(String)
    case unsupported(String)

    var text: String {
        switch self {
        case .disconnected: return "DISCONNECTED"
        case .connecting: return "CONNECTING"
        case .connected: return "CONNECTED"
        case .error: return "ERROR"
        case .unsupported: return "UNSUPPORTED"
        }
    }
    var color: Color {
        switch self {
        case .connected: return Theme.ok
        case .connecting: return Theme.accent
        case .disconnected: return Theme.dim
        case .error: return Theme.bad
        case .unsupported: return Theme.warn
        }
    }
}

@MainActor
final class DNSManager: ObservableObject {
    @Published var state: DNSState = .disconnected
    @Published var hint: String?
    private let server = ProfileServer()

    // Đọc trạng thái thật từ hệ thống
    func refresh() async {
        let m = NEDNSSettingsManager.shared()
        do {
            try await m.loadFromPreferences()
            state = (m.dnsSettings != nil && m.isEnabled) ? .connected : .disconnected
        } catch {
            state = .disconnected   // thiếu entitlement cũng lỗi ở bước đọc → coi như chưa bật
        }
        if state != .connected, await verify() { state = .connected }
    }

    // Kiểm tra thật: máy có đang dùng đúng profile NextDNS không (test.nextdns.io)
    func verify() async -> Bool {
        guard let url = URL(string: "https://test.nextdns.io") else { return false }
        var req = URLRequest(url: url, timeoutInterval: 5)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let (data, _) = try? await URLSession(configuration: .ephemeral).data(for: req),
              let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              o["status"] as? String == "ok" else { return false }
        if let p = o["profile"] as? String, !Config.nextDNSProfileID.isEmpty { return p == Config.nextDNSProfileID }
        return true
    }

    // Cài DNS bằng hồ sơ .mobileconfig: mở Safari tới server cục bộ của app
    func installProfile() async -> Bool {
        guard !Config.nextDNSProfileID.isEmpty else { return false }
        let body = AuraProfile.data(profileID: Config.nextDNSProfileID)
        let url: URL? = await withCheckedContinuation { cont in
            server.start(body: body) { cont.resume(returning: $0) }
        }
        guard let url else { return false }
        return await UIApplication.shared.open(url, options: [:])
    }

    func enable(compat: CompatibilityManager, device: DeviceInfo) async {
        hint = nil
        guard compat.status(.dns, device) == .supported else {
            state = .unsupported("DNS không được hỗ trợ trên thiết bị/build này.")
            return
        }
        guard !Config.nextDNSProfileID.isEmpty,
              let url = URL(string: "https://dns.nextdns.io/\(Config.nextDNSProfileID)") else {
            state = .error("Chưa cấu hình NextDNS profile.")
            return
        }
        state = .connecting
        let m = NEDNSSettingsManager.shared()
        do {
            try await m.loadFromPreferences()
            let s = NEDNSOverHTTPSSettings(servers: [])
            s.serverURL = url
            m.dnsSettings = s
            m.localizedDescription = "AURA DNS"
            try await m.saveToPreferences()
            try await m.loadFromPreferences()
            if m.isEnabled {
                state = .connected
                Haptic.success()
            } else {
                // iOS yêu cầu người dùng tự kích hoạt trong Cài đặt
                state = .disconnected
                hint = "Cấu hình đã lưu. Vào Cài đặt → Cài đặt chung → VPN & Quản lý thiết bị → DNS để kích hoạt."
            }
        } catch {
            // Thiếu entitlement (Apple ID miễn phí) → chuyển sang cài hồ sơ DNS qua Safari
            state = .disconnected
            hint = "Không cài DNS trực tiếp được. Đang mở trang cài hồ sơ: bấm Cho phép → Cài đặt → Đã tải về hồ sơ → Cài đặt."
            if !(await installProfile()) {
                state = .error("Không mở được trang cài hồ sơ DNS.")
                Haptic.error()
            }
        }
    }

    func disable() async {
        hint = nil
        let m = NEDNSSettingsManager.shared()
        try? await m.loadFromPreferences()
        try? await m.removeFromPreferences()
        state = .disconnected
        // Hồ sơ cài bằng file thì app không có quyền gỡ — iOS bắt người dùng tự xoá
        if await verify() {
            state = .connected
            hint = "DNS đang chạy bằng hồ sơ cài từ file. iOS không cho app tự gỡ: vào Cài đặt → Cài đặt chung → VPN & Quản lý thiết bị → AURA DNS → Xóa hồ sơ."
        }
    }
}
