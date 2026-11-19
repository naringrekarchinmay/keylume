import Foundation
import IOKit
import IOKit.hid

public enum RKError: Error, CustomStringConvertible {
    case notFound
    case openFailed(IOReturn)
    case writeFailed(IOReturn, packet: Int)

    public var description: String {
        switch self {
        case .notFound:
            "No RK84 (USB 258A:00C8) found. Connect it with the USB-C cable."
        case let .openFailed(r) where r == kIOReturnNotPermitted:
            "macOS blocked access to the keyboard. Allow this app under System Settings → Privacy & Security → Input Monitoring, then try again."
        case let .openFailed(r):
            "Could not open the keyboard (IOReturn 0x\(String(UInt32(bitPattern: r), radix: 16)))."
        case let .writeFailed(r, packet):
            "Write failed on packet \(packet) (IOReturn 0x\(String(UInt32(bitPattern: r), radix: 16)))."
        }
    }
}

/// Information about one matching HID interface.
public struct RKDeviceInfo: Sendable {
    public let product: String
    public let usagePage: Int
    public let usage: Int
    public let maxFeatureReportSize: Int
    public let transport: String
}

/// Talks to the keyboard's configuration interface (the one with a 65-byte feature report).
/// The device is opened without seizing, so typing keeps working.
public final class RKKeyboard {
    private let device: IOHIDDevice
    /// The manager that produced `device`; kept alive while the device is open.
    private let manager: IOHIDManager
    public let info: RKDeviceInfo

    private init(device: IOHIDDevice, manager: IOHIDManager, info: RKDeviceInfo) {
        self.device = device
        self.manager = manager
        self.info = info
    }

    private static func prop<T>(_ d: IOHIDDevice, _ key: String) -> T? {
        IOHIDDeviceGetProperty(d, key as CFString) as? T
    }

    private static func info(_ d: IOHIDDevice) -> RKDeviceInfo {
        RKDeviceInfo(product: prop(d, kIOHIDProductKey) ?? "?",
                     usagePage: prop(d, kIOHIDPrimaryUsagePageKey) ?? 0,
                     usage: prop(d, kIOHIDPrimaryUsageKey) ?? 0,
                     maxFeatureReportSize: prop(d, kIOHIDMaxFeatureReportSizeKey) ?? 0,
                     transport: prop(d, kIOHIDTransportKey) ?? "?")
    }

    /// All HID interfaces the keyboard exposes.
    public static func allInterfaces() -> [RKDeviceInfo] {
        matchingDevices().devices.map(info)
    }

    /// Result of the last IOHIDManagerOpen; kIOReturnNotPermitted means Input Monitoring is missing.
    public private(set) static var lastManagerOpenResult: IOReturn = kIOReturnSuccess

    /// A fresh manager every time. The keyboard re-enumerates after some writes
    /// (e.g. a key-map write), and a long-lived manager that isn't scheduled on a
    /// run loop never learns about it, so it would keep handing out dead devices.
    private static func matchingDevices() -> (manager: IOHIDManager, devices: [IOHIDDevice]) {
        let m = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let match: [String: Any] = [kIOHIDVendorIDKey: RKProtocol.vendorID,
                                    kIOHIDProductIDKey: RKProtocol.productID]
        IOHIDManagerSetDeviceMatching(m, match as CFDictionary)
        lastManagerOpenResult = IOHIDManagerOpen(m, IOOptionBits(kIOHIDOptionsTypeNone))
        guard let cfSet = IOHIDManagerCopyDevices(m) else { return (m, []) }
        return (m, (cfSet as NSSet).allObjects.map { $0 as! IOHIDDevice })
    }

    /// What macOS reports for Input Monitoring: "granted", "denied" or "not decided".
    public static var accessDescription: String {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted: "granted"
        case kIOHIDAccessTypeDenied: "denied"
        default: "not decided"
        }
    }

    /// Whether macOS has granted Input Monitoring, which is needed to see the keyboard.
    public static var hasAccess: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    /// Shows the macOS Input Monitoring prompt if the user hasn't decided yet.
    @discardableResult
    public static func requestAccess() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    /// Finds and opens the configuration interface.
    public static func open() throws -> RKKeyboard {
        // Try first; only treat it as a permission problem if macOS actually refuses.
        let (manager, devices) = matchingDevices()
        guard let d = devices.first(where: {
            (prop($0, kIOHIDMaxFeatureReportSizeKey) ?? 0) >= RKProtocol.reportLength
        }) else {
            if lastManagerOpenResult == kIOReturnNotPermitted {
                requestAccess()
                throw RKError.openFailed(kIOReturnNotPermitted)
            }
            throw RKError.notFound
        }
        let r = IOHIDDeviceOpen(d, IOOptionBits(kIOHIDOptionsTypeNone))
        guard r == kIOReturnSuccess else { throw RKError.openFailed(r) }
        return RKKeyboard(device: d, manager: manager, info: info(d))
    }

    deinit {
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    /// Report descriptor bytes, if the driver publishes them.
    public var reportDescriptor: [UInt8]? {
        (RKKeyboard.prop(device, kIOHIDReportDescriptorKey) as Data?).map { [UInt8]($0) }
    }

    /// Sends a logical payload as consecutive feature reports, 8 ms apart (as the vendor app does).
    public func send(payload: [UInt8]) throws {
        for (i, frame) in RKProtocol.frames(for: payload).enumerated() {
            let r = frame.withUnsafeBufferPointer {
                IOHIDDeviceSetReport(device, kIOHIDReportTypeFeature, CFIndex(frame[0]),
                                     $0.baseAddress!, frame.count)
            }
            guard r == kIOReturnSuccess else { throw RKError.writeFailed(r, packet: i + 1) }
            usleep(8_000)
        }
    }

    public func apply(_ lighting: LightingSettings) throws {
        try send(payload: RKProtocol.lightingPayload(lighting))
    }

    public func applyPerKey(_ colors: [Int: RGB]) throws {
        try send(payload: RKProtocol.perKeyColorPayload(colors))
    }

    public func applyKeymap(_ overrides: [Int: KeyAction]) throws {
        try send(payload: RKProtocol.keymapPayload(overrides))
    }
}
