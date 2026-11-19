import Foundation

/// Actions offered in the remap picker.
public struct KeyChoice: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let group: String
    public let action: KeyAction
}

public enum KeyCatalog {
    public static let modifierNames: [(UInt8, String)] = [
        (0x01, "⌃"), (0x02, "⇧"), (0x04, "⌥"), (0x08, "⌘"),
    ]

    public static let choices: [KeyChoice] = {
        var c: [KeyChoice] = []
        func add(_ group: String, _ title: String, _ a: KeyAction) {
            c.append(KeyChoice(id: "\(group)-\(title)", title: title, group: group, action: a))
        }
        for (i, ch) in "ABCDEFGHIJKLMNOPQRSTUVWXYZ".enumerated() { add("Letters", String(ch), .key(usage: UInt8(0x04 + i))) }
        for (i, ch) in "1234567890".enumerated() { add("Numbers", String(ch), .key(usage: UInt8(0x1E + i))) }
        for i in 1...12 { add("Function", "F\(i)", .key(usage: UInt8(0x39 + i))) }
        for i in 13...24 { add("Function", "F\(i)", .key(usage: UInt8(0x68 + i - 13))) }
        let named: [(String, UInt8)] = [
            ("Esc", 0x29), ("Tab", 0x2B), ("Caps Lock", 0x39), ("Space", 0x2C), ("Return", 0x28),
            ("Backspace", 0x2A), ("Delete (fwd)", 0x4C), ("Insert", 0x49), ("Home", 0x4A), ("End", 0x4D),
            ("Page Up", 0x4B), ("Page Down", 0x4E), ("←", 0x50), ("→", 0x4F), ("↑", 0x52), ("↓", 0x51),
            ("Print Screen", 0x46), ("Scroll Lock", 0x47), ("Pause", 0x48), ("Menu", 0x65),
            ("-", 0x2D), ("=", 0x2E), ("[", 0x2F), ("]", 0x30), ("\\", 0x31), (";", 0x33), ("'", 0x34),
            ("`", 0x35), (",", 0x36), (".", 0x37), ("/", 0x38),
        ]
        for (t, u) in named { add("Navigation & symbols", t, .key(usage: u)) }
        let mods: [(String, UInt8)] = [
            ("Left Control", 0xE0), ("Left Shift", 0xE1), ("Left Option", 0xE2), ("Left Command", 0xE3),
            ("Right Control", 0xE4), ("Right Shift", 0xE5), ("Right Option", 0xE6), ("Right Command", 0xE7),
        ]
        for (t, u) in mods { add("Modifiers", t, .key(usage: u)) }
        let media: [(String, UInt16)] = [
            ("Play / Pause", 0x00CD), ("Next Track", 0x00B5), ("Previous Track", 0x00B6), ("Stop", 0x00B7),
            ("Mute", 0x00E2), ("Volume Up", 0x00E9), ("Volume Down", 0x00EA),
            ("Brightness Up", 0x006F), ("Brightness Down", 0x0070),
        ]
        for (t, u) in media { add("Media", t, .consumer(u)) }
        add("Special", "Fn", .fn)
        add("Special", "Disabled", .disabled)
        return c
    }()

    public static func title(for action: KeyAction) -> String {
        switch action {
        case let .key(u, mods) where mods != 0:
            let m = modifierNames.filter { mods & $0.0 != 0 }.map(\.1).joined()
            return m + (choices.first { $0.action == .key(usage: u) }?.title ?? String(format: "0x%02X", u))
        default:
            return choices.first { $0.action == action }?.title ?? "?"
        }
    }
}
