// CompatibilityManager.swift — AURA IPA VN
import SwiftUI
import UIKit

enum FeatureStatus {
    case supported, unsupported, unknown
    var text: String {
        switch self {
        case .supported: return "SUPPORTED"
        case .unsupported: return "UNSUPPORTED"
        case .unknown: return "UNKNOWN"
        }
    }
    var color: Color {
        switch self {
        case .supported: return Theme.ok
        case .unsupported: return Theme.bad
        case .unknown: return Theme.dim
        }
    }
}

enum Feature: String, CaseIterable {
    case dns = "DNS", appData = "APP DATA", proxy = "PROXY", gameLaunch = "GAME LAUNCH"
}

struct CompatibilityManager {
    struct VerifiedRange { let from: [Int]; let to: [Int] }

    // Chỉ những khoảng đã xác minh mới là Supported
    static let verifiedRanges: [VerifiedRange] = [
        VerifiedRange(from: [17, 0], to: [17, 7, 99]),   // iOS 17.0 – 17.7.x
        VerifiedRange(from: [18, 0], to: [18, 7, 1]),    // iOS 18.0 – 18.7.1
        VerifiedRange(from: [26, 0], to: [26, 6, 1])     // iOS 26.0 – 26.6.1
    ]
    // iOS 27+: chỉ build đã xác minh (kern.osversion) mới được thêm vào đây
    static let verifiedBuilds: Set<String> = []

    private func parse(_ s: String) -> [Int] { s.split(separator: ".").compactMap { Int($0) } }

    private func compare(_ a: [Int], _ b: [Int]) -> Int {
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x < y ? -1 : 1 }
        }
        return 0
    }

    func overall(_ d: DeviceInfo) -> FeatureStatus {
        if Self.verifiedBuilds.contains(d.build) { return .supported }
        let v = parse(d.osVersion)
        guard !v.isEmpty else { return .unknown }
        let ok = Self.verifiedRanges.contains { compare(v, $0.from) >= 0 && compare(v, $0.to) <= 0 }
        return ok ? .supported : .unsupported
    }

    func status(_ f: Feature, _ d: DeviceInfo) -> FeatureStatus {
        guard overall(d) == .supported else { return .unsupported }
        switch f {
        case .dns: return .supported          // còn phụ thuộc entitlement lúc bật
        case .appData: return .unsupported    // sandbox iOS không cho truy cập dữ liệu app khác
        case .proxy: return .unknown          // chưa có backend proxy
        case .gameLaunch: return .supported
        }
    }
}
