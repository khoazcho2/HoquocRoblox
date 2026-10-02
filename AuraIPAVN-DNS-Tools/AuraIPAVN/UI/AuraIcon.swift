// AuraIcon.swift — AURA IPA VN
import SwiftUI
import UIKit

enum AuraIcon {
    case key, settings, back, chevron, shield, dns, proxy, device, ios
    case check, error, warning, info, power, refresh, lock, online, offline
}

struct IconShape: Shape {
    let icon: AuraIcon

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        var p = Path()
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }
        func line(_ a: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat)) {
            p.move(to: pt(a.0, a.1)); p.addLine(to: pt(b.0, b.1))
        }
        func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
            p.addEllipse(in: CGRect(x: rect.minX + (cx - r) * s, y: rect.minY + (cy - r) * s,
                                    width: 2 * r * s, height: 2 * r * s))
        }
        // Cung tròn bằng polyline (góc tăng = chiều kim đồng hồ trên màn hình)
        func arc(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ a0: CGFloat, _ a1: CGFloat) {
            let n = 40
            for i in 0...n {
                let a = (a0 + (a1 - a0) * CGFloat(i) / CGFloat(n)) * .pi / 180
                let q = pt(cx + r * cos(a), cy + r * sin(a))
                i == 0 ? p.move(to: q) : p.addLine(to: q)
            }
        }
        func rrect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) {
            p.addRoundedRect(in: CGRect(x: rect.minX + x * s, y: rect.minY + y * s,
                                        width: w * s, height: h * s),
                             cornerSize: CGSize(width: r * s, height: r * s))
        }

        switch icon {
        case .key:
            circle(8, 15, 4); line((11, 12), (20, 3)); line((16, 7), (19, 10))
        case .settings:
            line((4, 6), (20, 6)); line((4, 12), (20, 12)); line((4, 18), (20, 18))
            circle(9, 6, 2); circle(15, 12, 2); circle(8, 18, 2)
        case .back:
            line((15, 5), (8, 12)); line((8, 12), (15, 19))
        case .chevron:
            line((9, 5), (16, 12)); line((16, 12), (9, 19))
        case .shield:
            p.move(to: pt(12, 3)); p.addLine(to: pt(19, 6)); p.addLine(to: pt(19, 12))
            p.addQuadCurve(to: pt(12, 21), control: pt(19, 18))
            p.addQuadCurve(to: pt(5, 12), control: pt(5, 18))
            p.addLine(to: pt(5, 6)); p.closeSubpath()
        case .dns:
            circle(12, 12, 9)
            p.addEllipse(in: CGRect(x: rect.minX + 8 * s, y: rect.minY + 3 * s, width: 8 * s, height: 18 * s))
            line((3, 12), (21, 12))
        case .proxy:
            line((4, 8), (20, 8)); line((16, 4), (20, 8)); line((20, 8), (16, 12))
            line((20, 16), (4, 16)); line((8, 12), (4, 16)); line((4, 16), (8, 20))
        case .device:
            rrect(7, 2, 10, 20, 2.5); line((10.5, 18.5), (13.5, 18.5))
        case .ios:
            rrect(5, 5, 14, 14, 3)
            line((9, 2), (9, 5)); line((15, 2), (15, 5)); line((9, 19), (9, 22)); line((15, 19), (15, 22))
        case .check:
            line((5, 12.5), (10, 17.5)); line((10, 17.5), (19, 7))
        case .error:
            circle(12, 12, 9); line((9, 9), (15, 15)); line((15, 9), (9, 15))
        case .warning:
            p.move(to: pt(12, 3.5)); p.addLine(to: pt(21, 19.5)); p.addLine(to: pt(3, 19.5)); p.closeSubpath()
            line((12, 10), (12, 14)); line((12, 17), (12, 17.01))
        case .info:
            circle(12, 12, 9); line((12, 11), (12, 16)); line((12, 8), (12, 8.01))
        case .power:
            arc(12, 13, 8, -60, 240); line((12, 3), (12, 11))
        case .refresh:
            arc(12, 12, 8, 0, 270); line((15, 1), (12, 4)); line((12, 4), (15, 7))
        case .lock:
            rrect(5, 11, 14, 10, 2.5); line((8, 11), (8, 8)); arc(12, 8, 4, 180, 360); line((16, 8), (16, 11))
        case .online:
            arc(12, 18, 5, 225, 315); arc(12, 18, 9, 225, 315); arc(12, 18, 13, 225, 315); line((12, 18), (12, 18.01))
        case .offline:
            arc(12, 18, 5, 225, 315); arc(12, 18, 9, 225, 315); line((4, 4), (20, 20))
        }
        return p
    }
}

struct IconView: View {
    let icon: AuraIcon
    var size: CGFloat = 22
    var color: Color = .white

    var body: some View {
        IconShape(icon: icon)
            .stroke(color, style: StrokeStyle(lineWidth: 1.6 * size / 24, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}
