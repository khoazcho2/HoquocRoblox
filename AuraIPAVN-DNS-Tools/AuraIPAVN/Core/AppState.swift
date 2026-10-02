// AppState.swift — AURA IPA VN
import SwiftUI
import UIKit

@MainActor
final class AppState: ObservableObject {
    let device = DeviceInfo.current()
    let compat = CompatibilityManager()
    let dns = DNSManager()
    let dnsTools = DNSToolsModel()
}
