import KeylumeKit
import SwiftUI

/// The RK84 drawn from the vendor's key rectangles (720 × 290 layout space).
/// This is the content layer, so it's solid: no glass.
struct KeyboardView: View {
    enum Style { case lighting, colors, remap }

    @EnvironmentObject var state: AppState
    var style: Style
    var allowsMultiSelect = true

    private let layout = CGSize(width: 724, height: 288)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Only the lighting preview animates; it pauses with Reduce Motion.
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: style != .lighting || reduceMotion)) { tl in
            board(time: reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("RK84 keyboard")
    }

    private func board(time: Double) -> some View {
        GeometryReader { geo in
            let s = min(geo.size.width / layout.width, geo.size.height / layout.height)
            ZStack(alignment: .topLeading) {
                // Case
                RoundedRectangle(cornerRadius: 18 * s, style: .continuous)
                    .fill(LinearGradient(colors: [Color(white: 0.17), Color(white: 0.09)], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 18 * s, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.18), .white.opacity(0.03)],
                                                     startPoint: .top, endPoint: .bottom), lineWidth: 1))
                    .shadow(color: .black.opacity(0.35), radius: 24 * s, y: 14 * s)
                    .frame(width: layout.width * s, height: layout.height * s)

                ForEach(RK84Layout.keys, id: \.index) { key in
                    KeyCap(key: key, style: style, scale: s, allowsMultiSelect: allowsMultiSelect, time: time)
                        .frame(width: CGFloat(key.width) * s, height: CGFloat(key.height) * s)
                        .offset(x: CGFloat(key.x - 6) * s, y: CGFloat(key.y - 6) * s)
                }
            }
            .frame(width: layout.width * s, height: layout.height * s)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct KeyCap: View {
    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let key: KeyDefinition
    let style: KeyboardView.Style
    let scale: CGFloat
    let allowsMultiSelect: Bool
    let time: Double

    private var selected: Bool { state.selectedKeys.contains(key.index) }
    private var remap: KeyAction? { state.profile.remaps[key.index] }

    /// Light coming out of the key, or nil when the key is dark.
    private var glow: Color? {
        switch style {
        case .lighting:
            let l = state.profile.lighting
            guard l.brightness > 0 else { return nil }
            let (hueShift, level) = LightPreview.sample(mode: l.mode, key: key, time: time * (0.4 + 0.3 * Double(l.speed)))
            guard level > 0.02 else { return nil }
            let base: Color = l.rainbow || !l.mode.usesColor
                ? Color(hue: (Double(key.x) / 720 + hueShift).truncatingRemainder(dividingBy: 1), saturation: 0.85, brightness: 1)
                : l.color.color
            return base.opacity((0.35 + 0.13 * Double(l.brightness)) * level)
        case .colors:
            guard let c = state.profile.keyColors[key.index], c != .off else { return nil }
            return c.color
        case .remap:
            return nil
        }
    }

    var body: some View {
        let r = 5 * scale
        let label = (style == .remap && remap != nil) ? KeyCatalog.title(for: remap!) : key.name
        ZStack {
            // Under-glow
            if let glow {
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .fill(glow)
                    .blur(radius: 6 * scale)
                    .opacity(0.9)
            }
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.26), Color(white: 0.19)], startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: r, style: .continuous)
                        .fill(glow?.opacity(0.55) ?? .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: r, style: .continuous)
                        .strokeBorder(selected ? Color.accentColor : .white.opacity(0.1), lineWidth: selected ? 2.5 : 1)
                )
                .padding(1.5 * scale)
            Text(label)
                .font(.system(size: max(8, 10 * scale), weight: remap != nil && style == .remap ? .bold : .medium,
                              design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(3 * scale)
                .foregroundStyle(style == .remap && remap != nil ? Color.accentColor : .white.opacity(0.92))
                .shadow(color: .black.opacity(0.6), radius: 1)
            if style == .remap && remap != nil {
                // Remapped keys are marked with a dot as well as colour.
                Circle().fill(Color.accentColor).frame(width: 4 * scale, height: 4 * scale)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(4 * scale)
            }
        }
        .scaleEffect(selected && !reduceMotion ? 0.96 : 1)
        .animation(reduceMotion ? nil : .snappy(duration: 0.15), value: selected)
        .contentShape(Rectangle())
        .onTapGesture { toggle() }
        .help(key.name)
        .accessibilityElement()
        .accessibilityLabel(key.name)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private var accessibilityValue: String {
        switch style {
        case .remap: remap.map { "sends \(KeyCatalog.title(for: $0))" } ?? "default"
        case .colors: state.profile.keyColors[key.index].map { "colour #\($0.hex)" } ?? "off"
        case .lighting: ""
        }
    }

    private func toggle() {
        guard style != .lighting else { return }
        let mods = NSEvent.modifierFlags
        if allowsMultiSelect && (mods.contains(.shift) || mods.contains(.command)) {
            if selected { state.selectedKeys.remove(key.index) } else { state.selectedKeys.insert(key.index) }
        } else {
            state.selectedKeys = state.selectedKeys == [key.index] ? [] : [key.index]
        }
    }
}

/// Rough, on-screen approximation of each effect so modes look different in the
/// preview. The keyboard's own animation is the real thing.
enum LightPreview {
    /// Returns (hue shift 0...1, light level 0...1) for a key at time `t`.
    static func sample(mode: LightMode, key: KeyDefinition, time: Double) -> (Double, Double) {
        // Negative time: the keyboard's effects flow the opposite way to a naive left-to-right sweep.
        let t = -time
        func wrap(_ v: Double, _ m: Double = 1) -> Double { let r = v.truncatingRemainder(dividingBy: m); return r < 0 ? r + m : r }
        let x = Double(key.x) / 720, y = Double(key.y) / 290
        let noise = Double((key.index &* 2654435761) % 1000) / 1000
        func band(_ pos: Double, width: Double = 0.18) -> Double {
            let d = abs((pos - wrap(t * 0.25, 1.4) + 0.2))
            return max(0, 1 - d / width)
        }
        switch mode {
        case .steady, .custom:
            return (0, 1)
        case .breathing:
            return (0, 0.15 + 0.85 * (0.5 + 0.5 * sin(t * 2)))
        case .neonStream, .neon, .rainbowRoulette, .streamer, .sineWave:
            let wave = mode == .sineWave ? 0.5 + 0.5 * sin(x * 10 - t * 3 + y * 3) : 1
            return (wrap(t * 0.15), wave)
        case .rotatingWindmill, .rotatingStorm:
            let angle = atan2(y - 0.5, x - 0.5) / (2 * .pi) + 0.5
            return (wrap(angle + t * 0.2),
                    mode == .rotatingStorm ? 0.4 + 0.6 * band(angle) : 1)
        case .starsTwinkle, .ripplesShining, .flashAway, .shadowDisappear, .ambilight:
            let phase = sin(t * 2.5 + noise * 40)
            return (noise * 0.3, max(0, phase) * (mode == .ripplesShining ? 0.5 + 0.5 * band(x) : 1))
        case .marqueeEffect, .serpentineHorseRace, .retroSnake:
            return (0, band(x))
        case .layerUponLayer:
            return (0, band(1 - y, width: 0.3))
        case .diagonalTransformation:
            return (0, band((x + y) / 2, width: 0.25))
        case .richAndHonored:
            return (0.08, 0.6 + 0.4 * sin(t * 1.5 + x * 4))
        }
    }
}
