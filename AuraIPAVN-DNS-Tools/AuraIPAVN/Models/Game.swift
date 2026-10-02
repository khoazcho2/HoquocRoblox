// Game.swift — AURA IPA VN
import SwiftUI
import UIKit

struct Game: Identifiable, Hashable {
    let id: String          // bundle ID
    let name: String
    let urlScheme: String?

    var iconAssetName: String? {
        id == "com.dts.freefireth" ? "FreeFireIcon" : nil
    }
}

enum InstallState { case installed, notInstalled, unknown }

extension Game {
    @MainActor var installState: InstallState {
        guard let s = urlScheme, let url = URL(string: "\(s)://") else { return .unknown }
        return UIApplication.shared.canOpenURL(url) ? .installed : .notInstalled
    }

    @MainActor func readiness(
        _ c: CompatibilityManager,
        _ d: DeviceInfo,
        installState: InstallState? = nil
    ) -> (String, Color) {
        guard c.overall(d) == .supported else { return ("NOT SUPPORTED", Theme.bad) }
        switch installState ?? self.installState {
        case .installed: return ("READY", Theme.ok)
        case .notInstalled: return ("NOT INSTALLED", Theme.warn)
        case .unknown: return ("UNKNOWN", Theme.dim)
        }
    }

    // Mở game qua URL scheme; done(false) nếu không mở được (chưa cài / scheme sai)
    @MainActor func open(_ done: @escaping (Bool) -> Void) {
        guard let s = urlScheme, let url = URL(string: "\(s)://") else { done(false); return }
        UIApplication.shared.open(url) { done($0) }
    }
}
