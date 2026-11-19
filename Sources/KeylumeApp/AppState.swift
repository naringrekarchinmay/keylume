import Foundation
import IOKit
import KeylumeKit
import SwiftUI

/// Everything the app writes to the keyboard. Stored locally because the
/// keyboard has no way to read its settings back.
struct Profile: Codable, Equatable {
    var lighting = LightingSettings()
    var keyColors: [Int: RGB] = [:]
    var remaps: [Int: KeyAction] = [:]
}

@MainActor
final class AppState: ObservableObject {
    @Published var profile: Profile { didSet { save() } }
    @Published var status: String = ""
    @Published var isError = false
    @Published var connected = false
    @Published var needsPermission = false
    @Published var selectedKeys: Set<Int> = []
    @Published var autoApply = true

    private let storeURL: URL = {
        let fm = FileManager.default
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("Keylume", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("profile.json")
        // One-time move from the pre-rename "RK84" folder.
        let legacy = support.appendingPathComponent("RK84/profile.json")
        if !fm.fileExists(atPath: file.path), fm.fileExists(atPath: legacy.path) {
            try? fm.copyItem(at: legacy, to: file)
        }
        return file
    }()

    private var pendingApply: Task<Void, Never>?

    init() {
        if let data = try? Data(contentsOf: storeURL),
           let p = try? JSONDecoder().decode(Profile.self, from: data) {
            profile = p
        } else {
            profile = Profile()
        }
        refreshConnection()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(profile) { try? data.write(to: storeURL) }
    }

    func refreshConnection() {
        connected = !RKKeyboard.allInterfaces().isEmpty
        needsPermission = !connected && RKKeyboard.lastManagerOpenResult == kIOReturnNotPermitted
        if needsPermission {
            report("macOS is blocking keyboard access (Input Monitoring: \(RKKeyboard.accessDescription)).", error: true)
        } else if !connected {
            report("Keyboard not found. Connect the RK84 with the USB-C cable.", error: true)
        } else {
            report("RK84 connected.")
        }
    }

    func requestPermission() {
        RKKeyboard.requestAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    private func report(_ text: String, error: Bool = false) {
        status = text
        isError = error
    }

    /// Opens the keyboard and runs `body`. If the keyboard was briefly away (it
    /// reconnects after a key-map write), waits a moment and tries once more.
    private func withKeyboard(_ body: (RKKeyboard) throws -> Void) throws {
        do {
            try body(try RKKeyboard.open())
        } catch let e as RKError {
            if case let .openFailed(r) = e, r == kIOReturnNotPermitted { throw e }
            usleep(1_200_000)
            try body(try RKKeyboard.open())
        }
    }

    private func perform(_ label: String, _ body: (RKKeyboard) throws -> Void) {
        do {
            try withKeyboard(body)
            connected = true
            needsPermission = false
            report(label)
        } catch let e as RKError {
            if case let .openFailed(r) = e { needsPermission = r == kIOReturnNotPermitted }
            if case .notFound = e { connected = false }
            report(e.description, error: true)
        } catch {
            report("\(error)", error: true)
        }
    }

    // MARK: Lighting

    func lightingChanged() {
        guard autoApply else { return }
        pendingApply?.cancel()
        pendingApply = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            self?.applyLighting()
        }
    }

    func applyLighting() {
        let l = profile.lighting
        perform("Applied \(l.mode.title).") { try $0.apply(l) }
    }

    // MARK: Per-key colours

    func paint(_ color: RGB) {
        for i in selectedKeys { profile.keyColors[i] = color }
    }

    func paintAll(_ color: RGB) {
        for k in RK84Layout.keys { profile.keyColors[k.index] = color }
    }

    func applyKeyColors() {
        var l = profile.lighting
        l.mode = .custom
        profile.lighting = l
        let colors = profile.keyColors
        perform("Applied per-key colours.") { kb in
            try kb.apply(l)
            usleep(50_000)
            try kb.applyPerKey(colors)
        }
    }

    // MARK: Remapping

    func remap(_ index: Int, to action: KeyAction?) {
        profile.remaps[index] = action
    }

    func applyKeymap() {
        let r = profile.remaps
        perform(r.isEmpty ? "Restored the default layout." : "Applied \(r.count) remapped key(s).") { try $0.applyKeymap(r) }
    }

    func restoreDefaultKeymap() {
        profile.remaps = [:]
        applyKeymap()
    }
}
