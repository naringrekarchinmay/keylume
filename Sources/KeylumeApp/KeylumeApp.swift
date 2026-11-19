import KeylumeKit
import SwiftUI

@main
struct KeylumeApp: App {
    @StateObject private var state = AppState()

    init() {
        // Lets the app come to the front when launched straight from `swift run`.
        NSApplication.shared.setActivationPolicy(.regular)
        DebugSnapshot.runIfRequested()
    }

    var body: some Scene {
        WindowGroup("Keylume") {
            ContentView()
                .environmentObject(state)
                .frame(minWidth: 900, minHeight: 640)
        }
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified)
    }
}

enum Section: String, CaseIterable, Identifiable {
    case lighting = "Lighting"
    case keyColors = "Per-key colours"
    case remap = "Remap keys"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .lighting: "light.max"
        case .keyColors: "paintpalette"
        case .remap: "keyboard"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var section: Section? = Section(rawValue: ProcessInfo.processInfo.environment["KEYLUME_SECTION"] ?? "") ?? .lighting
    @State private var confirmKeymap = false

    var body: some View {
        NavigationSplitView {
            List(Section.allCases, selection: $section) { s in
                Label(s.rawValue, systemImage: s.icon).tag(s)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .safeAreaInset(edge: .bottom) { ConnectionBadge().padding(12) }
        } detail: {
            ZStack {
                Backdrop()
                switch section ?? .lighting {
                case .lighting: LightingView()
                case .keyColors: KeyColorsView()
                case .remap: RemapView()
                }
            }
            .navigationTitle(section?.rawValue ?? "Keylume")
            .navigationSubtitle(state.status)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { apply() } label: { Label(applyTitle, systemImage: "arrow.down.to.line").labelStyle(.titleAndIcon) }
                        .primaryGlassButton()
                        .keyboardShortcut(.return, modifiers: .command)
                        .help("Write these settings to the keyboard (⌘↩)")
                }
            }
            .onChange(of: section) { state.selectedKeys = [] }
        }
        .confirmationDialog("Write the new key layout to the keyboard?", isPresented: $confirmKeymap) {
            Button("Apply") { state.applyKeymap() }
        } message: {
            Text("This replaces the whole layout stored on the keyboard. You can undo it with Restore defaults.")
        }
    }

    private var applyTitle: String {
        "Apply to keyboard"
    }

    private func apply() {
        switch section ?? .lighting {
        case .lighting: state.applyLighting()
        case .keyColors: state.applyKeyColors()
        case .remap: confirmKeymap = true
        }
    }
}

/// Content-layer backdrop: a soft wash of the current lighting colour, so the
/// glass panels have something to refract.
struct Backdrop: View {
    @EnvironmentObject var state: AppState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let l = state.profile.lighting
        let tint = l.rainbow || !l.mode.usesColor ? Color.purple : l.color.color
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            RadialGradient(colors: [tint.opacity(scheme == .dark ? 0.35 : 0.22), .clear],
                           center: .init(x: 0.5, y: 0.32), startRadius: 20, endRadius: 520)
            if l.rainbow || !l.mode.usesColor {
                RadialGradient(colors: [Color.cyan.opacity(0.18), .clear],
                               center: .init(x: 0.15, y: 0.75), startRadius: 10, endRadius: 380)
                RadialGradient(colors: [Color.orange.opacity(0.16), .clear],
                               center: .init(x: 0.9, y: 0.7), startRadius: 10, endRadius: 380)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.4), value: l)
        .accessibilityHidden(true)
    }
}

struct ConnectionBadge: View {
    @EnvironmentObject var state: AppState
    var ok: Bool { state.connected && !state.needsPermission }
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(ok ? .green : .orange)
            Text(ok ? "RK84 connected" : "Not connected").font(.callout)
            Spacer()
            Button { state.refreshConnection() } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.borderless)
                .help("Check the connection again")
                .accessibilityLabel("Check the connection again")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .glassPanel(cornerRadius: 12)
    }
}

struct PermissionBanner: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield").font(.title2).foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Allow Input Monitoring").font(.headline)
                Text("macOS only lets apps talk to keyboards after you allow Input Monitoring. Keylume uses it to send settings, and doesn't read your typing. Turn Keylume on in the list, then quit and reopen the app.")
                    .font(.callout).foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Open Settings") { state.requestPermission() }.secondaryGlassButton()
        }
        .padding(16)
        .glassPanel(cornerRadius: 18)
    }
}
