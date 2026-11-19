import KeylumeKit
import SwiftUI

extension RGB {
    var color: Color { Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255) }
    init(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .white
        self.init(UInt8(clamping: Int((ns.redComponent * 255).rounded())),
                  UInt8(clamping: Int((ns.greenComponent * 255).rounded())),
                  UInt8(clamping: Int((ns.blueComponent * 255).rounded())))
    }
}

private let swatches: [(RGB, String)] = [
    (RGB(255, 255, 255), "White"), (RGB(255, 0, 0), "Red"), (RGB(255, 128, 0), "Orange"),
    (RGB(255, 220, 0), "Yellow"), (RGB(0, 255, 0), "Green"), (RGB(0, 255, 200), "Teal"),
    (RGB(0, 120, 255), "Blue"), (RGB(140, 0, 255), "Purple"), (RGB(255, 0, 160), "Pink"),
]

/// Hero keyboard on top (content layer), floating glass controls below (functional layer).
struct Screen<Controls: View>: View {
    @EnvironmentObject var state: AppState
    var hint: String
    @ViewBuilder var keyboard: () -> KeyboardView
    @ViewBuilder var controls: () -> Controls

    var body: some View {
        VStack(spacing: 18) {
            if state.needsPermission {
                PermissionBanner()
                    .frame(maxWidth: 860)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
            }
            keyboard()
                .frame(minHeight: 160, idealHeight: 280, maxHeight: 340)
                .padding(.horizontal, 28)
                .padding(.top, 20)
            Text(hint)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
            controls()
                .padding(20)
                .frame(maxWidth: 860)
                .glassPanel()
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        .overlay(alignment: .top) {
            if state.isError && !state.needsPermission {
                Label(state.status, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .glassChip(selected: false)
                    .foregroundStyle(.orange)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: state.isError)
    }
}

struct SwatchRow: View {
    var selected: RGB?
    var pick: (RGB) -> Void
    var body: some View {
        HStack(spacing: 8) {
            ForEach(swatches, id: \.0) { c, name in
                Button { pick(c) } label: {
                    Circle().fill(c.color)
                        .frame(width: 24, height: 24)
                        .overlay(Circle().strokeBorder(.primary.opacity(0.25), lineWidth: 1))
                        .overlay {
                            if selected == c {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(c == .white || c.g > 200 ? .black : .white)
                            }
                        }
                }
                .buttonStyle(.plain)
                .help(name)
                .accessibilityLabel(name)
                .accessibilityAddTraits(selected == c ? .isSelected : [])
            }
        }
    }
}

struct LabeledSlider: View {
    var title: String
    @Binding var value: Int
    var range: ClosedRange<Int>
    var labels: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline.weight(.medium))
                Spacer()
                Text(labels[value - range.lowerBound]).font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
            }
            Slider(value: Binding(get: { Double(value) }, set: { value = Int($0.rounded()) }),
                   in: Double(range.lowerBound)...Double(range.upperBound), step: 1)
                .accessibilityLabel(title)
                .accessibilityValue(labels[value - range.lowerBound])
        }
    }
}

// MARK: - Lighting

struct LightingView: View {
    @EnvironmentObject var state: AppState

    private var lighting: Binding<LightingSettings> {
        Binding(get: { state.profile.lighting },
                set: { state.profile.lighting = $0; state.lightingChanged() })
    }

    private let modes = LightMode.allCases.filter { $0 != .custom && $0 != .ambilight }

    var body: some View {
        let l = lighting.wrappedValue
        Screen(hint: "Preview of \(l.mode.title). The keyboard plays the animation.") {
            KeyboardView(style: .lighting)
        } controls: {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Effect").font(.headline)
                    ScrollView(.horizontal, showsIndicators: false) {
                        GlassGroup(spacing: 6) {
                            HStack(spacing: 6) {
                                ForEach(modes) { m in
                                    let on = l.mode == m
                                    Button { lighting.wrappedValue.mode = m } label: {
                                        HStack(spacing: 5) {
                                            if on { Image(systemName: "checkmark").font(.caption.weight(.bold)) }
                                            Text(m.title)
                                        }
                                        .font(.callout.weight(on ? .semibold : .regular))
                                        .foregroundStyle(on ? Color.accentColor : .primary)
                                        .padding(.horizontal, 2)
                                    }
                                    .secondaryGlassButton()
                                    .controlSize(.large)
                                    .accessibilityAddTraits(on ? .isSelected : [])
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                HStack(alignment: .top, spacing: 28) {
                    VStack(spacing: 14) {
                        LabeledSlider(title: "Brightness", value: lighting.brightness, range: 0...5,
                                      labels: ["Off", "Very low", "Low", "Medium", "High", "Full"])
                        if l.mode.usesSpeed {
                            LabeledSlider(title: "Speed", value: lighting.speed, range: 1...5,
                                          labels: ["Very slow", "Slow", "Normal", "Fast", "Very fast"])
                        }
                    }
                    .frame(maxWidth: 300)

                    VStack(alignment: .leading, spacing: 12) {
                        if l.mode.usesColor {
                            HStack {
                                Text("Colour").font(.subheadline.weight(.medium))
                                Spacer()
                                Toggle("Rainbow", isOn: lighting.rainbow).toggleStyle(.switch).controlSize(.small)
                            }
                            if !l.rainbow {
                                HStack(spacing: 10) {
                                    SwatchRow(selected: l.color) { lighting.wrappedValue.color = $0 }
                                    ColorPicker("Custom colour", selection: Binding(
                                        get: { lighting.wrappedValue.color.color },
                                        set: { lighting.wrappedValue.color = RGB($0) }), supportsOpacity: false)
                                        .labelsHidden()
                                        .help("Custom colour")
                                }
                            }
                        } else {
                            Text("This effect picks its own colours.").font(.callout).foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Lights sleep").font(.subheadline.weight(.medium))
                            Spacer()
                            Picker("Lights sleep", selection: lighting.sleep) {
                                ForEach(Array(["After 5 min", "After 10 min", "After 20 min", "After 30 min", "Never"].enumerated()),
                                        id: \.offset) { Text($0.element).tag($0.offset + 1) }
                            }
                            .labelsHidden().frame(width: 150)
                        }
                        Toggle("Apply changes instantly", isOn: $state.autoApply)
                            .toggleStyle(.checkbox).font(.callout)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

// MARK: - Per-key colours

struct KeyColorsView: View {
    @EnvironmentObject var state: AppState
    @State private var brush = RGB(0, 120, 255)

    var body: some View {
        Screen(hint: "Click a key to select it. Shift-click to select more, then pick a colour.") {
            KeyboardView(style: .colors)
        } controls: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Paint").font(.headline)
                    Text(state.selectedKeys.isEmpty ? "No keys selected" : "\(state.selectedKeys.count) selected")
                        .font(.callout).foregroundStyle(.secondary)
                    Spacer()
                }
                HStack(spacing: 12) {
                    SwatchRow(selected: brush) { brush = $0; state.paint($0) }
                    ColorPicker("Custom colour", selection: Binding(get: { brush.color },
                                                                    set: { brush = RGB($0); state.paint(brush) }),
                                supportsOpacity: false)
                        .labelsHidden().help("Custom colour")
                    Spacer()
                }
                HStack(spacing: 8) {
                    Button("Select all") { state.selectedKeys = Set(RK84Layout.keys.map(\.index)) }
                    Button("Fill all with colour") { state.paintAll(brush) }
                    Button("Turn selected off") { state.paint(.off) }.disabled(state.selectedKeys.isEmpty)
                    Spacer()
                }
                .secondaryGlassButton()
                Text("Applying switches the keyboard to its Custom lighting mode. Unpainted keys stay dark.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Remap

struct RemapView: View {
    @EnvironmentObject var state: AppState
    @State private var confirmReset = false
    @State private var filter = ""

    private var selectedKey: KeyDefinition? {
        guard state.selectedKeys.count == 1, let i = state.selectedKeys.first else { return nil }
        return RK84Layout.keys.first { $0.index == i }
    }

    var body: some View {
        Screen(hint: "Select a key, then pick what it should send. Changed keys show a dot.") {
            KeyboardView(style: .remap, allowsMultiSelect: false)
        } controls: {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    if let key = selectedKey {
                        Text("\(key.name) sends").font(.subheadline).foregroundStyle(.secondary)
                        Text(state.profile.remaps[key.index].map(KeyCatalog.title) ?? "\(key.name)")
                            .font(.title2.weight(.semibold))
                        if state.profile.remaps[key.index] != nil {
                            Button("Reset this key") { state.remap(key.index, to: nil) }.secondaryGlassButton()
                        }
                        if key.isFn {
                            Label("Remapping Fn turns off the Fn shortcuts (lighting, media, Bluetooth) until you restore it.",
                                  systemImage: "exclamationmark.triangle")
                                .font(.footnote).foregroundStyle(.orange)
                        }
                    } else {
                        Text("No key selected").font(.title3).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Text("\(state.profile.remaps.count) key(s) changed").font(.callout).foregroundStyle(.secondary)
                    Button("Restore defaults…") { confirmReset = true }.secondaryGlassButton()
                }
                .frame(width: 240, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    TextField("Search keys", text: $filter).textFieldStyle(.roundedBorder)
                    List {
                        ForEach(groups, id: \.self) { g in
                            SwiftUI.Section(g) {
                                ForEach(choices(in: g)) { c in
                                    Button(c.title) {
                                        if let key = selectedKey { state.remap(key.index, to: c.action) }
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(selectedKey == nil)
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.inset)
                }
            }
            .frame(height: 230)
        }
        .confirmationDialog("Restore the factory key layout?", isPresented: $confirmReset) {
            Button("Restore defaults", role: .destructive) { state.restoreDefaultKeymap() }
        } message: {
            Text("This clears every remap and writes the standard RK84 layout to the keyboard.")
        }
    }

    private var filtered: [KeyChoice] {
        filter.isEmpty ? KeyCatalog.choices
            : KeyCatalog.choices.filter { $0.title.localizedCaseInsensitiveContains(filter) }
    }
    private var groups: [String] {
        var seen: [String] = []
        for c in filtered where !seen.contains(c.group) { seen.append(c.group) }
        return seen
    }
    private func choices(in g: String) -> [KeyChoice] { filtered.filter { $0.group == g } }
}
