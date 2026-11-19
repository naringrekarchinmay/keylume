import Foundation
import IOKit
import KeylumeKit

let usage = """
keylume - configure a Royal Kludge RK84 (USB 258A:00C8) from macOS

  keylume doctor                       check permission and connection
  keylume list                         show the keyboard's HID interfaces
  keylume modes                        list lighting modes
  keylume light [options]              set the lighting effect
      --mode <number|name>          e.g. 17 or steady (default steady)
      --color <rrggbb>              colour (default ffffff)
      --brightness <0-5>            default 5
      --speed <1-5>                 default 3
      --rainbow                     cycle colours instead of --color
      --sleep <1-5>                 default 1
      --dry-run                     print the reports instead of sending
"""

func value(_ args: [String], _ name: String) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    return args[i + 1]
}

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
    exit(1)
}

func hex(_ bytes: [UInt8]) -> String { bytes.map { String(format: "%02x", $0) }.joined(separator: " ") }

let args = Array(CommandLine.arguments.dropFirst())
guard let cmd = args.first else { print(usage); exit(0) }

switch cmd {
case "doctor":
    let all = RKKeyboard.allInterfaces()
    let open = RKKeyboard.lastManagerOpenResult
    print("Input Monitoring for this program: \(RKKeyboard.accessDescription)")
    print("HID manager open: 0x\(String(UInt32(bitPattern: open), radix: 16))\(open == kIOReturnNotPermitted ? " (not permitted)" : "")")
    print("RK84 interfaces visible: \(all.count)")
    do { _ = try RKKeyboard.open(); print("Config interface: opened OK") }
    catch { print("Config interface: \(error)") }

case "list":
    let all = RKKeyboard.allInterfaces()
    if all.isEmpty { fail(RKError.notFound.description) }
    for i in all {
        print("\(i.product)  usage \(i.usagePage):\(i.usage)  feature \(i.maxFeatureReportSize) bytes  via \(i.transport)")
    }
    if let kb = try? RKKeyboard.open(), let d = kb.reportDescriptor {
        print("config interface descriptor: \(hex(d))")
    }

case "modes":
    for m in LightMode.allCases { print(String(format: "%2d  %@", m.rawValue, m.title)) }

case "light":
    var s = LightingSettings()
    if let m = value(args, "--mode") {
        if let n = Int(m), let mode = LightMode(rawValue: n) { s.mode = mode }
        else if let mode = LightMode.allCases.first(where: {
            $0.title.lowercased().replacingOccurrences(of: " ", with: "") == m.lowercased().replacingOccurrences(of: " ", with: "")
        }) { s.mode = mode }
        else { fail("Unknown mode '\(m)'. Run `keylume modes`.") }
    }
    if let c = value(args, "--color") { guard let rgb = RGB(hex: c) else { fail("Bad colour '\(c)'") }; s.color = rgb }
    if let b = value(args, "--brightness").flatMap(Int.init) { s.brightness = b }
    if let sp = value(args, "--speed").flatMap(Int.init) { s.speed = sp }
    if let sl = value(args, "--sleep").flatMap(Int.init) { s.sleep = sl }
    s.rainbow = args.contains("--rainbow")
    let payload = RKProtocol.lightingPayload(s)
    if args.contains("--dry-run") {
        for f in RKProtocol.frames(for: payload) { print(hex(f)) }
        exit(0)
    }
    do {
        let kb = try RKKeyboard.open()
        try kb.apply(s)
        print("Set \(s.mode.title), colour \(s.rainbow ? "rainbow" : s.color.hex), brightness \(s.brightness), speed \(s.speed).")
    } catch { fail("\(error)") }

default:
    print(usage)
}
