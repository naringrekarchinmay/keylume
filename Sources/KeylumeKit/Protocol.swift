import Foundation

/// One physical key on the RK84.
public struct KeyDefinition: Hashable, Sendable {
    public let name: String
    /// Matrix slot and LED index (the same number on the RK84).
    public let index: Int
    /// HID keyboard usage the key sends by default (0xB0 = the Fn key).
    public let defaultUsage: UInt8
    public let x: Int, y: Int, width: Int, height: Int

    public init(name: String, index: Int, defaultUsage: UInt8, x: Int, y: Int, width: Int, height: Int) {
        self.name = name; self.index = index; self.defaultUsage = defaultUsage
        self.x = x; self.y = y; self.width = width; self.height = height
    }

    public var isFn: Bool { defaultUsage == 0xB0 }
}

public struct RGB: Hashable, Codable, Sendable {
    public var r: UInt8, g: UInt8, b: UInt8
    public init(_ r: UInt8, _ g: UInt8, _ b: UInt8) { self.r = r; self.g = g; self.b = b }

    public static let white = RGB(255, 255, 255)
    public static let off = RGB(0, 0, 0)

    /// Parses "ff8800" or "#FF8800".
    public init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(UInt8(v >> 16 & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF))
    }

    public var hex: String { String(format: "%02X%02X%02X", r, g, b) }
}

/// Lighting effects, numbered as the keyboard expects (vendor `tc_led_mode1...21`).
public enum LightMode: Int, CaseIterable, Codable, Sendable, Identifiable {
    case neonStream = 1, ripplesShining, rotatingWindmill, sineWave, rainbowRoulette,
         starsTwinkle, layerUponLayer, richAndHonored, marqueeEffect, rotatingStorm,
         serpentineHorseRace, retroSnake, diagonalTransformation, custom, ambilight,
         streamer, steady, breathing, neon, shadowDisappear, flashAway

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .neonStream: "Neon Stream"
        case .ripplesShining: "Ripples Shining"
        case .rotatingWindmill: "Rotating Windmill"
        case .sineWave: "Sine Wave"
        case .rainbowRoulette: "Rainbow Roulette"
        case .starsTwinkle: "Stars Twinkle"
        case .layerUponLayer: "Layer Upon Layer"
        case .richAndHonored: "Rich and Honored"
        case .marqueeEffect: "Marquee"
        case .rotatingStorm: "Rotating Storm"
        case .serpentineHorseRace: "Serpentine Horse Race"
        case .retroSnake: "Retro Snake"
        case .diagonalTransformation: "Diagonal Transformation"
        case .custom: "Custom (per-key)"
        case .ambilight: "Ambilight"
        case .streamer: "Streamer"
        case .steady: "Steady"
        case .breathing: "Breathing"
        case .neon: "Neon"
        case .shadowDisappear: "Shadow Disappear"
        case .flashAway: "Flash Away"
        }
    }

    /// Vendor `LedOpt` row for 00C8: which controls the mode uses.
    /// Order in KB.ini: animation, speed, light, direct, random, colornum.
    private var options: [Int] {
        switch self {
        case .rotatingWindmill, .rainbowRoulette, .streamer, .neon: [0, 1, 1, 0, 0, 0]
        case .steady: [0, 0, 1, 0, 1, 1]
        default: [0, 1, 1, 0, 1, 1]
        }
    }

    public var usesSpeed: Bool { options[1] == 1 }
    public var usesBrightness: Bool { options[2] == 1 }
    public var usesColor: Bool { options[5] == 1 }
}

/// Lighting settings sent in one packet.
public struct LightingSettings: Hashable, Codable, Sendable {
    public var mode: LightMode
    /// 1 (slow) ... 5 (fast)
    public var speed: Int
    /// 0 (off) ... 5 (brightest)
    public var brightness: Int
    public var color: RGB
    /// Cycle through colours instead of using `color`.
    public var rainbow: Bool
    /// Vendor sleep setting 1...5.
    public var sleep: Int

    public init(mode: LightMode = .steady, speed: Int = 3, brightness: Int = 5,
                color: RGB = .white, rainbow: Bool = false, sleep: Int = 1) {
        self.mode = mode; self.speed = speed; self.brightness = brightness
        self.color = color; self.rainbow = rainbow; self.sleep = sleep
    }
}

/// What a key sends after remapping.
public enum KeyAction: Hashable, Codable, Sendable {
    /// HID keyboard usage plus optional modifier bits (0x01 LCtrl, 0x02 LShift, 0x04 LAlt, 0x08 LGui, 0x10..0x80 right side).
    case key(usage: UInt8, modifiers: UInt8 = 0)
    /// HID consumer-page usage (media keys), e.g. 0x00E9 volume up.
    case consumer(UInt16)
    /// The Fn key.
    case fn
    /// Key does nothing.
    case disabled

    /// 4-byte matrix slot code (`keyinfo_to_hardware_code`, 0x413420 in the vendor app).
    public var slotBytes: [UInt8] {
        switch self {
        case let .key(usage, mods): [0x00, mods, usage, 0x00]
        case let .consumer(u): [0x01, 0x00, UInt8(u >> 8), UInt8(u & 0xFF)]
        case .fn: [0x00, 0x00, 0xB0, 0x00]
        case .disabled: [0x00, 0x00, 0x00, 0x00]
        }
    }
}

/// Builds the exact byte sequences the vendor app sends. Pure, no I/O.
public enum RKProtocol {
    public static let vendorID = 0x258A
    public static let productID = 0x00C8
    public static let reportID: UInt8 = 0x0A
    public static let reportLength = 65
    public static let chunkSize = 62
    public static let slotCount = 126

    /// Splits a logical payload into 65-byte feature reports:
    /// `0A [count] [index 1-based] [62 payload bytes]`.
    public static func frames(for payload: [UInt8]) -> [[UInt8]] {
        let count = max(1, (payload.count + chunkSize - 1) / chunkSize)
        precondition(count <= 255, "payload too large")
        return (0..<count).map { i in
            var report = [UInt8](repeating: 0, count: reportLength)
            report[0] = reportID
            report[1] = UInt8(count)
            report[2] = UInt8(i + 1)
            let start = i * chunkSize
            let end = min(start + chunkSize, payload.count)
            if start < end { report.replaceSubrange(3..<(3 + end - start), with: payload[start..<end]) }
            return report
        }
    }

    /// Lighting effect payload (60 bytes).
    public static func lightingPayload(_ s: LightingSettings) -> [UInt8] {
        var p = [UInt8](repeating: 0, count: 60)
        p[0] = 0x02
        p[1] = 0x29
        p[2] = UInt8(s.mode.rawValue)
        p[3] = 0x01
        p[4] = UInt8(clamping: min(max(s.speed, 1), 5))
        p[5] = UInt8(clamping: min(max(s.brightness, 0), 5))
        p[6] = s.color.r
        p[7] = s.color.g
        p[8] = s.color.b
        p[9] = s.rainbow ? 1 : 0
        p[10] = UInt8(clamping: min(max(s.sleep, 1), 5))
        return p
    }

    /// Per-key colour payload (381 bytes). Keys not in `colors` are off.
    public static func perKeyColorPayload(_ colors: [Int: RGB], slot: Int = 1) -> [UInt8] {
        var p = [UInt8](repeating: 0, count: 3 + slotCount * 3)
        p[0] = 0x03
        p[1] = 0x7E
        p[2] = UInt8(slot)
        for (led, c) in colors where (0..<slotCount).contains(led) {
            p[3 + led * 3] = c.r
            p[4 + led * 3] = c.g
            p[5 + led * 3] = c.b
        }
        return p
    }

    /// Default action for every RK84 key.
    public static func defaultKeymap(_ keys: [KeyDefinition] = RK84Layout.keys) -> [Int: KeyAction] {
        var m: [Int: KeyAction] = [:]
        for k in keys { m[k.index] = k.isFn ? .fn : .key(usage: k.defaultUsage) }
        return m
    }

    /// Key matrix payload. Starts from the defaults so no key is left empty.
    /// The vendor app sends this with length 505 (504 data bytes + 2 header − 1),
    /// so the final byte is dropped here too.
    public static func keymapPayload(_ overrides: [Int: KeyAction], fnLayer: Bool = false,
                                     keys: [KeyDefinition] = RK84Layout.keys) -> [UInt8] {
        var map = defaultKeymap(keys)
        for (i, a) in overrides { map[i] = a }
        var p = [UInt8](repeating: 0, count: 2 + slotCount * 4)
        p[0] = fnLayer ? 0x10 : 0x01
        p[1] = 0xF8
        for (i, a) in map where (0..<slotCount).contains(i) {
            p.replaceSubrange((2 + i * 4)..<(6 + i * 4), with: a.slotBytes)
        }
        return Array(p.prefix(505))
    }
}
