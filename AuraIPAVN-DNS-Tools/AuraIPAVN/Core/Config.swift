// Config.swift — AURA IPA VN
import SwiftUI
import UIKit

enum Config {
    static let appVersion = "v1.5.3"
    // Profile ID NextDNS (dạng "abc123")
    static let nextDNSProfileID = "514db8"
    // API key NextDNS (my.nextdns.io/account) — dùng cho chặn domain & thống kê.
    // Lưu ý: key nhúng trong IPA có thể bị trích xuất → nên cấp qua backend của bạn.
    static let nextDNSAPIKey = "24b0fe2dcf135e99cb5524b1cefca73918e525bb"
    // urlScheme = nil → không thể kiểm tra cài đặt → trạng thái UNKNOWN
    static let games: [Game] = [
        Game(id: "com.dts.freefiremax", name: "FREE FIRE MAX", urlScheme: "freefiremax"),
        Game(id: "com.dts.freefireth", name: "FREE FIRE", urlScheme: "freefireth")
    ]
}
