import XCTest
@testable import BioCardCore

// MARK: - APDUPacket Tests

final class APDUPacketTests: XCTestCase {

    // MARK: APDUHeader

    func testAPDUHeaderFormattedString() {
        let header = APDUHeader(cla: 0x00, ins: 0xA4, p1: 0x04, p2: 0x00)
        XCTAssertEqual(header.formattedString, "CLA: 00 | INS: A4 | P1: 04 | P2: 00")
    }

    func testAPDUHeaderEquality() {
        let h1 = APDUHeader(cla: 0x00, ins: 0xA4, p1: 0x04, p2: 0x00)
        let h2 = APDUHeader(cla: 0x00, ins: 0xA4, p1: 0x04, p2: 0x00)
        XCTAssertEqual(h1, h2)
    }

    // MARK: StatusWord

    func testStatusWordSuccess() {
        let sw = StatusWord(sw1: 0x90, sw2: 0x00)
        XCTAssertTrue(sw.isSuccess)
        XCTAssertFalse(sw.isBiometricRetry)
        XCTAssertEqual(sw.hexString, "90 00")
        XCTAssertEqual(sw.code, 0x9000)
    }

    func testStatusWordBiometricRetry() {
        let sw = StatusWord(sw1: 0x63, sw2: 0xC3)
        XCTAssertTrue(sw.isBiometricRetry)
        XCTAssertFalse(sw.isSuccess)
        XCTAssertEqual(sw.remainingRetries, 3)
    }

    func testStatusWordBiometricRetryZero() {
        let sw = StatusWord(sw1: 0x63, sw2: 0xC0)
        XCTAssertTrue(sw.isBiometricRetry)
        XCTAssertEqual(sw.remainingRetries, 0)
    }

    func testStatusWordMeaningSuccess() {
        let sw = StatusWord(sw1: 0x90, sw2: 0x00)
        XCTAssertEqual(sw.meaning, "Success / Normal Execution (Match Confirmed)")
    }

    func testStatusWordMeaningAuthBlocked() {
        let sw = StatusWord(sw1: 0x69, sw2: 0x83)
        XCTAssertEqual(sw.meaning, "Authentication method blocked (Biometric sensor or PIN locked)")
    }

    func testStatusWordMeaningWrongLength() {
        let sw = StatusWord(sw1: 0x67, sw2: 0x00)
        XCTAssertEqual(sw.meaning, "Wrong length (Lc/Le incorrect)")
    }

    func testStatusWordMeaningWrongLe() {
        let sw = StatusWord(sw1: 0x6C, sw2: 0x08)
        XCTAssertTrue(sw.meaning.contains("re-issue with Le=08"))
    }

    func testStatusWordMeaningFileNotFound() {
        let sw = StatusWord(sw1: 0x6A, sw2: 0x82)
        XCTAssertEqual(sw.meaning, "File or application not found (Invalid AID)")
    }

    // MARK: APDUPacket

    func testAPDUPacketIsAPDUWithRawBytes() {
        let packet = APDUPacket(
            direction: .command,
            rawBytes: [0x00, 0xA4, 0x04, 0x00],
            rawHex: "00 A4 04 00",
            summary: "SELECT APPLICATION / FILE"
        )
        XCTAssertTrue(packet.isAPDU)
    }

    func testAPDUPacketIsAPDUWithStatusWord() {
        let sw = StatusWord(sw1: 0x90, sw2: 0x00)
        let packet = APDUPacket(
            direction: .response,
            rawHex: "90 00",
            statusWord: sw,
            summary: "Response"
        )
        XCTAssertTrue(packet.isAPDU)
    }

    func testAPDUPacketIsNotAPDUForEvent() {
        let packet = APDUPacket(
            direction: .event,
            rawHex: "",
            summary: "System event",
            fullMessage: "Card connected"
        )
        XCTAssertFalse(packet.isAPDU)
    }

    func testAPDUPacketPrimaryDisplayTextForAPDU() {
        let packet = APDUPacket(
            direction: .command,
            rawBytes: [0x00, 0xA4, 0x04, 0x00],
            rawHex: "00 A4 04 00",
            summary: "SELECT APPLICATION / FILE"
        )
        XCTAssertEqual(packet.primaryDisplayText, "00 A4 04 00")
    }

    func testAPDUPacketPrimaryDisplayTextForEvent() {
        let packet = APDUPacket(
            direction: .event,
            rawHex: "",
            summary: "Fallback summary",
            fullMessage: "Card inserted"
        )
        XCTAssertEqual(packet.primaryDisplayText, "Card inserted")
    }

    func testAPDUPacketPrimaryDisplayTextFallsBackToSummary() {
        let packet = APDUPacket(
            direction: .event,
            rawHex: "",
            summary: "Only summary"
        )
        XCTAssertEqual(packet.primaryDisplayText, "Only summary")
    }
}

// MARK: - TraceEntry Tests

final class TraceEntryTests: XCTestCase {

    func testTraceSourceSystemLogLabel() {
        let source = TraceSource.systemLog(subsystem: "com.apple.nfc", process: "nfcd")
        XCTAssertEqual(source.label, "[nfcd] com.apple.nfc")
    }

    func testTraceSourceDirectHardwareLabel() {
        let source = TraceSource.directHardware(readerName: "ACR122U")
        XCTAssertEqual(source.label, "[Reader] ACR122U")
    }

    func testTraceSourceSimulatedLabel() {
        let source = TraceSource.simulated(scenario: "PassportScan")
        XCTAssertEqual(source.label, "[Simulation] PassportScan")
    }

    func testTraceEntrySequenceNumber() {
        let packet = APDUPacket(direction: .command, rawHex: "00 A4 04 00", summary: "SELECT")
        let entry = TraceEntry(
            sequenceNumber: 42,
            source: .simulated(scenario: "Test"),
            packet: packet
        )
        XCTAssertEqual(entry.sequenceNumber, 42)
    }

    func testTraceEntryEquality() {
        let id = UUID()
        let ts = Date()
        let packet = APDUPacket(direction: .command, rawHex: "90 00", summary: "Test")
        let e1 = TraceEntry(id: id, sequenceNumber: 1, timestamp: ts, source: .simulated(scenario: "s"), packet: packet)
        let e2 = TraceEntry(id: id, sequenceNumber: 1, timestamp: ts, source: .simulated(scenario: "s"), packet: packet)
        XCTAssertEqual(e1, e2)
    }
}

// MARK: - LogCategoryFilter Tests

final class LogCategoryFilterTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(LogCategoryFilter.allCases.count, 5)
    }

    func testRawValues() {
        XCTAssertEqual(LogCategoryFilter.all.rawValue, "All")
        XCTAssertEqual(LogCategoryFilter.apduOnly.rawValue, "APDU Only")
        XCTAssertEqual(LogCategoryFilter.successOnly.rawValue, "Success (90 00)")
        XCTAssertEqual(LogCategoryFilter.errorsOnly.rawValue, "Errors & Retries")
    }

    func testIdentifiableId() {
        XCTAssertEqual(LogCategoryFilter.apduOnly.id, "APDU Only")
    }
}
