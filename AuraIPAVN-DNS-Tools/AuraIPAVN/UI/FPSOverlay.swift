// FPSOverlay.swift — AURA IPA VN
// Module gộp: đếm FPS theo v-sync (CADisplayLink) + cấu hình ProMotion 120Hz
//            + giảm trễ cảm ứng (delaysContentTouches, Coalesced Touches)
//            + widget FPS nổi kéo thả được.
// Lưu ý: chỉ đo/tối ưu cho CHÍNH app này, không đọc được FPS của app khác.
import SwiftUI
import UIKit
import QuartzCore

// MARK: - 1. Bộ đếm FPS (CADisplayLink)

// CADisplayLink giữ mạnh (retain) target → dùng proxy + weak để không rò rỉ bộ nhớ
@MainActor
private final class DisplayLinkProxy: NSObject {
    weak var owner: FPSMonitor?

    @objc func tick(_ link: CADisplayLink) {
        // Owner đã bị huỷ → tự dừng link
        guard let owner else { link.invalidate(); return }
        owner.handle(link)
    }
}

// Toàn bộ chạy trên MainActor: CADisplayLink bắn ở main run loop, @Published cập nhật UI an toàn
@MainActor
final class FPSMonitor: ObservableObject {
    @Published private(set) var fps = 0          // FPS đo được (trung bình theo cửa sổ 0.5s)
    @Published private(set) var maxHz = 60       // Tần số quét tối đa của phần cứng

    private var link: CADisplayLink?
    private var windowStart: CFTimeInterval = 0  // timestamp frame đầu cửa sổ đo
    private var frames = 0                       // số frame trong cửa sổ đo
    private let window: CFTimeInterval = 0.5      // chu kỳ cập nhật số hiển thị (tránh render UI mỗi frame)
    private var observers: [NSObjectProtocol] = []

    // Bắt đầu đo (gọi lại nhiều lần vẫn an toàn)
    func start() {
        guard link == nil else { return }
        maxHz = Self.maxRefreshRate()

        let proxy = DisplayLinkProxy()
        proxy.owner = self
        let l = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.tick(_:)))
        // Dải tần số quét: tối thiểu 60Hz, tối đa 120Hz, ưu tiên 120Hz (ProMotion)
        l.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        l.add(to: .main, forMode: .common)   // .common: vẫn chạy khi đang cuộn
        link = l
        resetWindow()

        // Tạm dừng khi app không active để tiết kiệm pin
        let nc = NotificationCenter.default
        observers = [
            nc.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.setPaused(true) }
            },
            nc.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.setPaused(false) }
            }
        ]
    }

    func stop() {
        link?.invalidate()
        link = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        fps = 0
    }

    private func setPaused(_ paused: Bool) {
        link?.isPaused = paused
        if !paused { resetWindow() }   // tránh tính cả khoảng thời gian bị tạm dừng
    }

    private func resetWindow() { windowStart = 0; frames = 0 }

    // Gọi mỗi v-sync. Đo bằng khoảng cách timestamp giữa các frame, không dùng bộ đếm giây
    fileprivate func handle(_ link: CADisplayLink) {
        let t = link.timestamp
        if windowStart == 0 { windowStart = t; frames = 0; return }
        frames += 1
        let dt = t - windowStart
        if dt >= window {
            let value = Int((Double(frames) / dt).rounded())
            if value != fps { fps = value }
            frames = 0
            windowStart = t
        }
    }

    // Tần số quét tối đa của màn hình mà app đang hiển thị (ProMotion = 120)
    static func maxRefreshRate() -> Int {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        return scene?.screen.maximumFramesPerSecond ?? 60
    }
}

// MARK: - 2. Widget FPS nổi (SwiftUI)

struct FPSWidgetView: View {
    @ObservedObject var monitor: FPSMonitor
    @State private var offset: CGSize = .zero
    @GestureState private var drag: CGSize = .zero

    private static let size = CGSize(width: 96, height: 52)

    // Xanh ≥90% tần số tối đa, cam ≥60%, đỏ còn lại
    private var color: Color {
        let ratio = Double(monitor.fps) / Double(max(monitor.maxHz, 1))
        if ratio >= 0.9 { return Color(red: 0.2, green: 0.85, blue: 0.5) }
        if ratio >= 0.6 { return .orange }
        return Color(red: 1.0, green: 0.32, blue: 0.36)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(monitor.fps)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(color)
                Text("FPS").font(.system(size: 10, weight: .semibold)).foregroundColor(.white.opacity(0.6))
            }
            Text("Max \(monitor.maxHz) Hz")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Color.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .offset(x: offset.width + drag.width, y: offset.height + drag.height)
        .gesture(
            DragGesture()
                .updating($drag) { v, state, _ in state = v.translation }
                .onEnded { v in
                    // Kẹp lại trong màn hình để widget không bị kéo mất
                    let s = UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }.first?.screen.bounds.size ?? CGSize(width: 390, height: 844)
                    let x = min(max(offset.width + v.translation.width, -(s.width - Self.size.width - 16)), 0)
                    let y = min(max(offset.height + v.translation.height, -40), s.height - 200)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { offset = CGSize(width: x, height: y) }
                }
        )
        .animation(.easeOut(duration: 0.2), value: color)
        .accessibilityElement(children: .combine)
    }
}

// Gắn widget lên mọi màn hình; đo chỉ chạy khi bật
private struct FPSOverlayModifier: ViewModifier {
    let enabled: Bool
    @StateObject private var monitor = FPSMonitor()

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                if enabled {
                    FPSWidgetView(monitor: monitor)
                        .padding(.top, 52)       // nằm dưới thanh điều hướng
                        .padding(.trailing, 8)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: enabled)
            .onAppear { if enabled { monitor.start() } }
            .onChange(of: enabled) { on in on ? monitor.start() : monitor.stop() }
    }
}

extension View {
    // Dùng: ContentView().fpsOverlay(enabled: true)
    func fpsOverlay(enabled: Bool = true) -> some View { modifier(FPSOverlayModifier(enabled: enabled)) }
}

// MARK: - 3. Giảm trễ cảm ứng cho ScrollView: delaysContentTouches = false

// SwiftUI ScrollView chạy trên UIScrollView ẩn bên dưới. View này nằm trong nội dung cuộn,
// leo ngược cây view để tìm UIScrollView rồi tắt việc hoãn nhận lệnh chạm.
private struct ScrollTouchTuner: UIViewRepresentable {
    final class TunerView: UIView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            backgroundColor = .clear
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) chưa được hỗ trợ") }

        override func didMoveToWindow() { super.didMoveToWindow(); apply() }
        override func layoutSubviews() { super.layoutSubviews(); apply() }

        func apply() {
            var v: UIView? = superview
            while let cur = v {
                if let scroll = cur as? UIScrollView {
                    scroll.delaysContentTouches = false   // nút phản hồi ngay khi chạm
                    scroll.canCancelContentTouches = true // vẫn cho phép cuộn khi đang chạm vào nút
                    return
                }
                v = cur.superview
            }
        }
    }

    func makeUIView(context: Context) -> TunerView { TunerView() }
    func updateUIView(_ uiView: TunerView, context: Context) { uiView.apply() }
}

extension View {
    // Gắn vào nội dung BÊN TRONG ScrollView/List: ScrollView { VStack { ... }.instantTouch() }
    func instantTouch() -> some View {
        background(ScrollTouchTuner().frame(width: 1, height: 1))
    }
}

// MARK: - 4. Coalesced Touches (nhiều điểm chạm hơn trên mỗi frame)

struct TouchSample: Equatable {
    let point: CGPoint            // toạ độ trong hệ của view
    let timestamp: TimeInterval   // thời điểm hệ thống ghi nhận điểm chạm
    let force: CGFloat            // lực nhấn (0 nếu thiết bị không hỗ trợ)
    let isCoalesced: Bool         // true = điểm trung gian được gom thêm
}

enum TouchStage { case began, moved, ended }

// Bề mặt nhận cảm ứng UIKit. onTouch luôn gọi trên main thread
struct CoalescedTouchSurface: UIViewRepresentable {
    var onTouch: (TouchStage, [TouchSample]) -> Void

    final class SurfaceView: UIView {
        var onTouch: ((TouchStage, [TouchSample]) -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            isMultipleTouchEnabled = false
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) chưa được hỗ trợ") }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { emit(.began, touches, event) }
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { emit(.moved, touches, event) }
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { emit(.ended, touches, event) }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { emit(.ended, touches, event) }

        private func emit(_ stage: TouchStage, _ touches: Set<UITouch>, _ event: UIEvent?) {
            guard let touch = touches.first else { return }
            // coalescedTouches: toàn bộ điểm chạm phát sinh giữa 2 nhịp quét; phần tử cuối là điểm hiện tại
            let list = (stage == .moved ? event?.coalescedTouches(for: touch) : nil) ?? [touch]
            let last = list.count - 1
            let samples = list.enumerated().map { i, t in
                TouchSample(point: t.location(in: self), timestamp: t.timestamp, force: t.force, isCoalesced: i < last)
            }
            onTouch?(stage, samples)
        }
    }

    func makeUIView(context: Context) -> SurfaceView {
        let v = SurfaceView()
        v.onTouch = onTouch
        return v
    }
    func updateUIView(_ uiView: SurfaceView, context: Context) { uiView.onTouch = onTouch }
}

// Demo: vuốt/vẽ mượt, hiện số điểm nhận được trên mỗi lần cập nhật
struct TouchTrailDemo: View {
    @State private var strokes: [[CGPoint]] = []
    @State private var lastCount = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            CoalescedTouchSurface { stage, samples in
                let pts = samples.map(\.point)
                switch stage {
                case .began: strokes.append(pts)
                case .moved:
                    if strokes.isEmpty { strokes.append(pts) } else { strokes[strokes.count - 1].append(contentsOf: pts) }
                case .ended: break
                }
                lastCount = samples.count
            }
            Canvas { ctx, _ in
                for s in strokes {
                    guard let first = s.first else { continue }
                    var path = Path()
                    path.move(to: first)
                    s.dropFirst().forEach { path.addLine(to: $0) }
                    ctx.stroke(path, with: .color(.cyan), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
            }
            .allowsHitTesting(false)
            Text("Điểm/lần cập nhật: \(lastCount)")
                .font(.system(size: 11, design: .monospaced)).foregroundColor(.white.opacity(0.6)).padding(10)
                .allowsHitTesting(false)
        }
    }
}
