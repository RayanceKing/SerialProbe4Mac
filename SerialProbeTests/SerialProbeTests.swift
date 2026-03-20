//
//  SerialProbeTests.swift
//  SerialProbe
//
//  Created by rayanceking on 2026/3/20.
//

import Testing
@testable import SerialProbe

struct SerialProbeTests {
    @Test func parseSpacedHexPayload() throws {
        let data = try SerialPayloadCodec.parseHex("55 AA 10 0D")
        #expect(Array(data) == [0x55, 0xAA, 0x10, 0x0D])
    }

    @Test func parseContinuousHexPayload() throws {
        let data = try SerialPayloadCodec.parseHex("55AA100D")
        #expect(Array(data) == [0x55, 0xAA, 0x10, 0x0D])
    }

    @Test func encodeTextPayloadWithLineEnding() throws {
        let data = try SerialPayloadCodec.encode("help", mode: .text, lineEnding: .crlf)
        #expect(Array(data.suffix(2)) == [0x0D, 0x0A])
    }
}
