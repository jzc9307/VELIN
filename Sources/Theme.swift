import SwiftUI
import AppKit

typealias ViewState<Value> = SwiftUI.State<Value>

enum Ink {
    static let background = Color(hex: 0x0C1014)
    static let sidebar = Color(hex: 0x10161B)
    static let surface = Color(hex: 0x171E25)
    static let muted = Color(hex: 0x93A0AE)
    static let mint = Color(hex: 0xA2ECD5)
    static let lilac = Color(hex: 0xB8A4FF)
    static let line = Color.white.opacity(0.075)
}
extension Color {
    init(hex: UInt32) { self.init(.sRGB, red: Double((hex >> 16) & 255)/255, green: Double((hex >> 8) & 255)/255, blue: Double(hex & 255)/255, opacity: 1) }
}
struct VelinMark: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Path { p in p.move(to: CGPoint(x: w*0.13, y: h*0.22)); p.addCurve(to: CGPoint(x: w*0.5, y: h*0.83), control1: CGPoint(x: w*0.18, y: h*0.56), control2: CGPoint(x: w*0.35, y: h*0.73)) }
                    .stroke(LinearGradient(colors: [Ink.mint, Ink.mint.opacity(0.55)], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: w*0.15, lineCap: .round))
                Path { p in p.move(to: CGPoint(x: w*0.5, y: h*0.83)); p.addCurve(to: CGPoint(x: w*0.87, y: h*0.18), control1: CGPoint(x: w*0.57, y: h*0.56), control2: CGPoint(x: w*0.76, y: h*0.23)) }
                    .stroke(LinearGradient(colors: [Ink.lilac, .white.opacity(0.95)], startPoint: .bottom, endPoint: .topTrailing), style: StrokeStyle(lineWidth: w*0.15, lineCap: .round))
                Circle().fill(Ink.mint).frame(width: w*0.11, height: w*0.11).position(x: w*0.52, y: h*0.19)
            }
        }.aspectRatio(1, contentMode: .fit).accessibilityLabel("VELIN signal emblem")
    }
}
struct Press: ButtonStyle {
    var primary = false
    func makeBody(configuration: ButtonStyleConfiguration) -> some View { PressBody(configuration: configuration, primary: primary, compact: false) }
}
struct IconPress: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View { PressBody(configuration: configuration, primary: false, compact: true) }
}
private struct PressBody: View {
    let configuration: ButtonStyleConfiguration
    var primary: Bool
    var compact: Bool
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.isEnabled) var enabled
    @ViewState private var hover = false
    var body: some View {
        configuration.label
            .font(.system(size: compact ? 11 : 13, weight: .semibold))
            .padding(.horizontal, compact ? 7 : 15).frame(minWidth: compact ? 32 : 0, minHeight: compact ? 32 : 36)
            .foregroundStyle(primary ? Ink.background : hover ? Ink.mint : .white.opacity(0.88))
            .background(primary ? Ink.mint.opacity(configuration.isPressed ? 0.72 : 1) : .white.opacity(configuration.isPressed ? 0.26 : hover ? 0.13 : compact ? 0.025 : 0.045), in: RoundedRectangle(cornerRadius: compact ? 8 : 10))
            .overlay(RoundedRectangle(cornerRadius: compact ? 8 : 10).strokeBorder(primary ? Ink.mint.opacity(0.5) : configuration.isPressed ? Ink.mint.opacity(0.65) : hover ? Ink.mint.opacity(0.35) : compact ? .white.opacity(0.055) : Ink.line))
            .shadow(color: primary && hover ? Ink.mint.opacity(0.16) : .clear, radius: 10, y: 2)
            .scaleEffect(configuration.isPressed && !reduceMotion ? (compact ? 0.90 : 0.95) : 1)
            .opacity(enabled ? 1 : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: 9))
            .animation(reduceMotion ? nil : .spring(response: 0.16, dampingFraction: 0.65), value: configuration.isPressed)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hover)
            .onHover { hover = $0 }
            .onChange(of: configuration.isPressed) { _, pressed in if pressed && enabled { NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now) } }
    }
}

struct Pill: View {
    var text: String
    var color: Color = Ink.mint
    var body: some View { HStack(spacing: 6) { Circle().fill(color).frame(width: 5, height: 5); Text(text).font(.system(size: 10, weight: .semibold)).tracking(0.4) }.foregroundStyle(color).padding(.horizontal, 9).padding(.vertical, 6).background(color.opacity(0.075), in: Capsule()).overlay(Capsule().strokeBorder(color.opacity(0.15))) }
}
struct Card<Content: View>: View {
    var padding: CGFloat = 22
    @ViewBuilder var content: Content
    var body: some View { content.frame(maxWidth: .infinity, alignment: .leading).padding(padding).background(Ink.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Ink.line)) }
}
struct FieldStyle: ViewModifier {
    func body(content: Content) -> some View { content.textFieldStyle(.plain).font(.system(size: 13)).padding(12).background(Ink.background, in: RoundedRectangle(cornerRadius: 9)).overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Ink.line)) }
}
extension View { func velinField() -> some View { modifier(FieldStyle()) } }
struct SectionHeading: View {
    var title: String
    var subtitle: String
    var body: some View { VStack(alignment: .leading, spacing: 7) { Text(title).font(.system(size: 29, weight: .semibold)).tracking(-0.8); Text(subtitle).font(.system(size: 13)).foregroundStyle(Ink.muted).fixedSize(horizontal: false, vertical: true) }.frame(maxWidth: .infinity, alignment: .leading) }
}
struct EmptyState: View {
    let icon: String
    let title: String
    let detail: String
    var body: some View { VStack(spacing: 14) { Image(systemName: icon).font(.system(size: 28, weight: .light)).foregroundStyle(Ink.mint); Text(title).font(.system(size: 18, weight: .medium)); Text(detail).font(.system(size: 13)).foregroundStyle(Ink.muted).multilineTextAlignment(.center).frame(maxWidth: 350) }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(30) }
}
func clockText(_ seconds: Double) -> String { let s = max(0, Int(seconds)); return String(format: "%02d:%02d", s/60, s%60) }

struct NavigationPress: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.65 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.18, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in if pressed { NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now) } }
    }
}

// Sheets use a separate hosting root; apply the same native scroller policy there.
struct HideNativeScrollbars: NSViewRepresentable {
    final class Probe: NSView {
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); refresh() }
        override func layout() { super.layout(); refresh() }
        func refresh() { DispatchQueue.main.async { [weak self] in guard let root = self?.window?.contentView else { return }; self?.hide(in: root) } }
        private func hide(in view: NSView) { if let scroll = view as? NSScrollView { scroll.hasVerticalScroller = false; scroll.hasHorizontalScroller = false; scroll.autohidesScrollers = true }; for child in view.subviews { hide(in: child) } }
    }
    func makeNSView(context: Context) -> Probe { Probe() }
    func updateNSView(_ view: Probe, context: Context) { view.refresh() }
}
