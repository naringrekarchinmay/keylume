import XCTest
@testable import KeylumeKit

final class ProtocolTests: XCTestCase {
    func testLightingFrameMatchesVendorLayout() {
        let s = LightingSettings(mode: .steady, speed: 3, brightness: 5, color: RGB(255, 0, 0), rainbow: false, sleep: 1)
        let frames = RKProtocol.frames(for: RKProtocol.lightingPayload(s))
        XCTAssertEqual(frames.count, 1)
        let f = frames[0]
        XCTAssertEqual(f.count, 65)
        XCTAssertEqual(Array(f.prefix(14)), [0x0A, 0x01, 0x01, 0x02, 0x29, 17, 0x01, 3, 5, 0xFF, 0x00, 0x00, 0x00, 0x01])
        XCTAssertTrue(f[14...].allSatisfy { $0 == 0 })
    }

    func testLightingClampsRanges() {
        let p = RKProtocol.lightingPayload(LightingSettings(speed: 99, brightness: -4, sleep: 0))
        XCTAssertEqual(p[4], 5)
        XCTAssertEqual(p[5], 0)
        XCTAssertEqual(p[10], 1)
    }

    func testFramingSplitsIn62ByteChunks() {
        let payload = (0..<130).map { UInt8($0 & 0xFF) }
        let frames = RKProtocol.frames(for: payload)
        XCTAssertEqual(frames.count, 3)
        XCTAssertEqual(frames.map { $0[1] }, [3, 3, 3])
        XCTAssertEqual(frames.map { $0[2] }, [1, 2, 3])
        XCTAssertEqual(frames[1][3], 62)
        XCTAssertEqual(frames[2][3], 124)
        XCTAssertEqual(frames[2][3 + 5], 129)
        XCTAssertEqual(frames[2][3 + 6], 0)
    }

    func testPerKeyColourPayload() {
        let p = RKProtocol.perKeyColorPayload([0: RGB(1, 2, 3), 95: RGB(9, 8, 7)])
        XCTAssertEqual(p.count, 381)
        XCTAssertEqual(Array(p.prefix(6)), [0x03, 0x7E, 0x01, 1, 2, 3])
        XCTAssertEqual(Array(p[(3 + 95 * 3)..<(6 + 95 * 3)]), [9, 8, 7])
        XCTAssertEqual(RKProtocol.frames(for: p).count, 7)
    }

    func testKeymapStartsFromDefaultsAndKeepsFn() {
        let p = RKProtocol.keymapPayload([:])
        XCTAssertEqual(p.count, 505)
        XCTAssertEqual(Array(p.prefix(2)), [0x01, 0xF8])
        // Esc, index 0 -> usage 0x29
        XCTAssertEqual(Array(p[2..<6]), [0x00, 0x00, 0x29, 0x00])
        // Fn, index 59
        XCTAssertEqual(Array(p[(2 + 59 * 4)..<(6 + 59 * 4)]), [0x00, 0x00, 0xB0, 0x00])
        // every RK84 key has a non-zero slot
        for k in RK84Layout.keys {
            XCTAssertNotEqual(Array(p[(2 + k.index * 4)..<(6 + k.index * 4)]), [0, 0, 0, 0], k.name)
        }
        XCTAssertEqual(RKProtocol.frames(for: p).count, 9)
    }

    func testKeyActionEncodings() {
        XCTAssertEqual(KeyAction.key(usage: 0x06, modifiers: 0x01).slotBytes, [0x00, 0x01, 0x06, 0x00])
        XCTAssertEqual(KeyAction.consumer(0x00E9).slotBytes, [0x01, 0x00, 0x00, 0xE9])
        XCTAssertEqual(KeyAction.consumer(0x0183).slotBytes, [0x01, 0x00, 0x01, 0x83])
    }

    func testLayoutHas84UniqueIndices() {
        XCTAssertEqual(RK84Layout.keys.count, 84)
        XCTAssertEqual(Set(RK84Layout.keys.map(\.index)).count, 84)
    }
}
