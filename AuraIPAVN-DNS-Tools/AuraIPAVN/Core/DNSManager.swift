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

    // Đọc trạng thái thật từ hệ thống
    func refresh() async {
        let m = NEDNSSettingsManager.shared()
        do {
            try await m.loadFromPreferences()
            state = (m.dnsSettings != nil && m.isEnabled) ? .connected : .disconnected
        } catch {
            state = .error(error.localizedDescription)
        }
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
            // Thường do thiếu entitlement hoặc người dùng từ chối
            state = .error("Required entitlement unavailable hoặc bị từ chối: \(error.localizedDescription)")
            Haptic.error()
        }
    }

    func disable() async {
        hint = nil
        let m = NEDNSSettingsManager.shared()
        do {
            try await m.loadFromPreferences()
            try await m.removeFromPreferences()
            state = .disconnected
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
