// DeviceInfo.swift — AURA IPA VN
import SwiftUI
import UIKit

struct DeviceInfo {
    let model: String
    let osVersion: String
    let build: String

    private static func sysctlString(_ name: String) -> String {
        var size = 0
        sysctlbyname(name, nil, &size, nil, 0)
        guard size > 0 else { return "Unknown" }
        var buf = [CChar](repeating: 0, count: size)
        sysctlbyname(name, &buf, &size, nil, 0)
        return String(cString: buf)
    }

    static func current() -> DeviceInfo {
        var model = sysctlString("hw.machine")
        // Trình giả lập: lấy identifier của máy được giả lập
        if let sim = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { model = sim }
        return DeviceInfo(model: model,
                          osVersion: UIDevice.current.systemVersion,
                          build: sysctlString("kern.osversion"))
    }
}
