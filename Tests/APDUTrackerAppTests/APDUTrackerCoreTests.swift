import XCTest
@testable import APDUTrackerCore

// MARK: - APDUParser Hex Conversion Tests

final class APDUParserHexTests: XCTestCase {

    func testHexToBytesClean() {
        let bytes = APDUParser.hexToBytes("00A40400")
        XCTAssertEqual(bytes, [0x00, 0xA4, 0x04, 0x00])
    }

    func testHexToBytesWithSpaces() {
        let bytes = APDUParser.hexToBytes("00 A4 04 00")
        XCTAssertEqual(bytes, [0x00, 0xA4, 0x04, 0x00])
    }

    func testHexToBytesWithColons() {
        let bytes = APDUParser.hexToBytes("00:A4:04:00")
        XCTAssertEqual(bytes, [0x00, 0xA4, 0x04, 0x00])
    }

    func testHexToBytesWithDashes() {
        let bytes = APDUParser.hexToBytes("00-A4-04-00")
        XCTAssertEqual(bytes, [0x00, 0xA4, 0x04, 0x00])
    }

    func testHexToBytesWithBrackets() {
        let bytes = APDUParser.hexToBytes("[00A40400]")
        XCTAssertEqual(bytes, [0x00, 0xA4, 0x04, 0x00])
    }

    func testHexToBytesWithAngleBrackets() {
        let bytes = APDUParser.hexToBytes("<00A40400>")
        XCTAssertEqual(bytes, [0x00, 0xA4, 0x04, 0x00])
    }

    func testHexToBytesWithOxPrefix() {
        let bytes = APDUParser.hexToBytes("0x00A40400")
        XCTAssertEqual(bytes, [0x00, 0xA4, 0x04, 0x00])
    }

    func testHexToBytesOddLengthReturnsEmpty() {
        let bytes = APDUParser.hexToBytes("00A")
        XCTAssertEqual(bytes, [])
    }

    func testHexToBytesInvalidCharsReturnsEmpty() {
        let bytes = APDUParser.hexToBytes("ZZZZ")
        XCTAssertEqual(bytes, [])
    }

    func testHexToBytesEmptyString() {
        let bytes = APDUParser.hexToBytes("")
        XCTAssertEqual(bytes, [])
    }

    func testBytesToHexFormatting() {
        let hex = APDUParser.bytesToHex([0x00, 0xA4, 0x04, 0x00])
        XCTAssertEqual(hex, "00 A4 04 00")
    }

    func testBytesToHexEmpty() {
        let hex = APDUParser.bytesToHex([])
        XCTAssertEqual(hex, "")
    }

    func testBytesToHexSingleByte() {
        let hex = APDUParser.bytesToHex([0xFF])
        XCTAssertEqual(hex, "FF")
    }

    func testRoundTrip() {
        let original = [UInt8]([0x00, 0xA4, 0x04, 0x00, 0x07, 0xD2, 0x76])
        let hex = APDUParser.bytesToHex(original)
        let back = APDUParser.hexToBytes(hex)
        XCTAssertEqual(original, back)
    }
}

// MARK: - Command APDU Parsing Tests

final class APDUParserCommandTests: XCTestCase {

    func testParseSelectCommand() {
        let bytes: [UInt8] = [0x00, 0xA4, 0x04, 0x00]
        let packet = APDUParser.parseCommandAPDU(bytes: bytes)
        XCTAssertNotNil(packet)
        XCTAssertEqual(packet?.direction, .command)
        XCTAssertEqual(packet?.header?.cla, 0x00)
        XCTAssertEqual(packet?.header?.ins, 0xA4)
        XCTAssertEqual(packet?.header?.p1, 0x04)
        XCTAssertEqual(packet?.header?.p2, 0x00)
        XCTAssertEqual(packet?.summary, "SELECT APPLICATION / FILE")
    }

    func testParseVerifyCommand() {
        let bytes: [UInt8] = [0x00, 0x20, 0x00, 0x80, 0x02, 0xAB, 0xCD]
        let packet = APDUParser.parseCommandAPDU(bytes: bytes)
        XCTAssertNotNil(packet)
        XCTAssertEqual(packet?.header?.ins, 0x20)
        XCTAssertTrue(packet?.summary.contains("BIOMETRIC VERIFY") ?? false)
        XCTAssertEqual(packet?.data, [0xAB, 0xCD])
    }

    func testParseBiometricOperationCommand() {
        let bytes: [UInt8] = [0x00, 0x2A, 0x90, 0xA0, 0x03, 0x01, 0x02, 0x03]
        let packet = APDUParser.parseCommandAPDU(bytes: bytes)
        XCTAssertNotNil(packet)
        XCTAssertTrue(packet?.summary.contains("PERFORM BIOMETRIC OPERATION") ?? false)
    }

    func testParseReadBinaryCommand() {
        let bytes: [UInt8] = [0x00, 0xB0, 0x00, 0x00]
        let packet = APDUParser.parseCommandAPDU(bytes: bytes)
        XCTAssertNotNil(packet)
        XCTAssertEqual(packet?.summary, "READ BINARY")
    }

    func testParseGetChallengeCommand() {
        let bytes: [UInt8] = [0x00, 0x84, 0x00, 0x00]
        let packet = APDUParser.parseCommandAPDU(bytes: bytes)
        XCTAssertNotNil(packet)
        XCTAssertEqual(packet?.summary, "GET CHALLENGE")
    }

    func testParseCommandTooShortReturnsNil() {
        let bytes: [UInt8] = [0x00, 0xA4, 0x04]
        let packet = APDUParser.parseCommandAPDU(bytes: bytes)
        XCTAssertNil(packet)
    }

    func testParseCommandEmptyReturnsNil() {
        let packet = APDUParser.parseCommandAPDU(bytes: [])
        XCTAssertNil(packet)
    }

    func testCommandPacketRawHex() {
        let bytes: [UInt8] = [0x00, 0xA4, 0x04, 0x00]
        let packet = APDUParser.parseCommandAPDU(bytes: bytes)
        XCTAssertEqual(packet?.rawHex, "00 A4 04 00")
    }

    func testCommandPacketHasNoStatusWord() {
        let bytes: [UInt8] = [0x00, 0xA4, 0x04, 0x00]
        let packet = APDUParser.parseCommandAPDU(bytes: bytes)
        XCTAssertNil(packet?.statusWord)
    }
}

// MARK: - Response APDU Parsing Tests

final class APDUParserResponseTests: XCTestCase {

    func testParseSuccessResponse() {
        let bytes: [UInt8] = [0x90, 0x00]
        let packet = APDUParser.parseResponseAPDU(bytes: bytes)
        XCTAssertNotNil(packet)
        XCTAssertEqual(packet?.direction, .response)
        XCTAssertEqual(packet?.statusWord?.sw1, 0x90)
        XCTAssertEqual(packet?.statusWord?.sw2, 0x00)
        XCTAssertTrue(packet?.statusWord?.isSuccess ?? false)
    }

    func testParseResponseWithData() {
        let bytes: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF, 0x90, 0x00]
        let packet = APDUParser.parseResponseAPDU(bytes: bytes)
        XCTAssertNotNil(packet)
        XCTAssertEqual(packet?.data, [0xDE, 0xAD, 0xBE, 0xEF])
        XCTAssertTrue(packet?.statusWord?.isSuccess ?? false)
    }

    func testParseAuthBlockedResponse() {
        let bytes: [UInt8] = [0x69, 0x83]
        let packet = APDUParser.parseResponseAPDU(bytes: bytes)
        XCTAssertNotNil(packet)
        XCTAssertFalse(packet?.statusWord?.isSuccess ?? true)
        XCTAssertEqual(packet?.statusWord?.meaning, "Authentication method blocked (Biometric sensor or PIN locked)")
    }

    func testParseResponseTooShortReturnsNil() {
        let bytes: [UInt8] = [0x90]
        let packet = APDUParser.parseResponseAPDU(bytes: bytes)
        XCTAssertNil(packet)
    }

    func testParseResponseEmptyReturnsNil() {
        let packet = APDUParser.parseResponseAPDU(bytes: [])
        XCTAssertNil(packet)
    }

    func testResponsePacketHasNoHeader() {
        let bytes: [UInt8] = [0x90, 0x00]
        let packet = APDUParser.parseResponseAPDU(bytes: bytes)
        XCTAssertNil(packet?.header)
    }

    func testResponseSummaryContainsStatusWord() {
        let bytes: [UInt8] = [0x90, 0x00]
        let packet = APDUParser.parseResponseAPDU(bytes: bytes)
        XCTAssertTrue(packet?.summary.contains("90 00") ?? false)
    }
}

// MARK: - Log Line Parsing Tests

final class APDUParserLogLineTests: XCTestCase {

    func testParseLogLineWithTransmitKeyword() {
        let line = "APDU transmit: 00A40400"
        let packet = APDUParser.parseLogLine(line)
        XCTAssertNotNil(packet)
        XCTAssertEqual(packet?.direction, .command)
    }

    func testParseLogLineWithSendKeyword() {
        let line = "send: 00A40400"
        let packet = APDUParser.parseLogLine(line)
        XCTAssertNotNil(packet)
    }

    func testParseLogLineWithReceiveKeyword() {
        let line = "recv: 9000"
        let packet = APDUParser.parseLogLine(line)
        XCTAssertNotNil(packet)
        XCTAssertEqual(packet?.direction, .response)
    }

    func testParseLogLineRawHexFallback() {
        let line = "00A40400"
        let packet = APDUParser.parseLogLine(line)
        XCTAssertNotNil(packet)
        XCTAssertEqual(packet?.direction, .command)
    }

    func testParseLogLineUnrecognizedReturnsNil() {
        let packet = APDUParser.parseLogLine("This is a plain text log with no hex")
        XCTAssertNil(packet)
    }
}

// MARK: - TextExporter Tests

final class APDUTextExporterTests: XCTestCase {

    private func makeEntry(seq: Int, sw1: UInt8, sw2: UInt8) -> TraceEntry {
        let sw = StatusWord(sw1: sw1, sw2: sw2)
        let packet = APDUPacket(
            direction: .response,
            rawBytes: [sw1, sw2],
            rawHex: String(format: "%02X %02X", sw1, sw2),
            statusWord: sw,
            summary: sw.meaning
        )
        return TraceEntry(
            sequenceNumber: seq,
            source: .simulated(scenario: "UnitTest"),
            packet: packet
        )
    }

    func testGenerateReportContainsHeader() {
        let report = TextExporter.generateReport(from: [])
        XCTAssertTrue(report.contains("APDUTRACKER APDU TRACE AUDIT REPORT"))
    }

    func testGenerateReportEmptyEntries() {
        let report = TextExporter.generateReport(from: [])
        XCTAssertTrue(report.contains("No APDU packets captured"))
    }

    func testGenerateReportTotalCount() {
        let entries = [makeEntry(seq: 1, sw1: 0x90, sw2: 0x00)]
        let report = TextExporter.generateReport(from: entries)
        XCTAssertTrue(report.contains("Total Logs:  1 packet(s)"))
    }

    func testGenerateReportSuccessSummary() {
        let entries = [makeEntry(seq: 1, sw1: 0x90, sw2: 0x00)]
        let report = TextExporter.generateReport(from: entries)
        XCTAssertTrue(report.contains("1 Success"))
    }

    func testGenerateReportBiometricRetrySummary() {
        let entries = [makeEntry(seq: 1, sw1: 0x63, sw2: 0xC2)]
        let report = TextExporter.generateReport(from: entries)
        XCTAssertTrue(report.contains("1 Biometric Retries"))
    }

    func testGenerateReportContainsSequenceNumber() {
        let entries = [makeEntry(seq: 7, sw1: 0x90, sw2: 0x00)]
        let report = TextExporter.generateReport(from: entries)
        XCTAssertTrue(report.contains("[0007]"))
    }

    func testExportToFilePersistsContent() throws {
        let entries = [makeEntry(seq: 1, sw1: 0x90, sw2: 0x00)]
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("APDUTrackerTest_\(UUID().uuidString).txt")
        try TextExporter.exportToFile(entries: entries, at: tmpURL)
        let content = try String(contentsOf: tmpURL, encoding: .utf8)
        XCTAssertTrue(content.contains("APDUTRACKER APDU TRACE AUDIT REPORT"))
        try? FileManager.default.removeItem(at: tmpURL)
    }

    func testExportToFileIsReadable() throws {
        let entries = [makeEntry(seq: 1, sw1: 0x90, sw2: 0x00)]
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("APDUTrackerTest_\(UUID().uuidString).txt")
        try TextExporter.exportToFile(entries: entries, at: tmpURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmpURL.path))
        try? FileManager.default.removeItem(at: tmpURL)
    }
}

// MARK: - TraceStore Filter Tests

@MainActor
final class TraceStoreFilterTests: XCTestCase {

    private func makeStore(entries: [TraceEntry]) -> TraceStore {
        let store = TraceStore()
        store.clear()
        entries.forEach { store.append($0) }
        return store
    }

    private func makeCommandEntry(seq: Int) -> TraceEntry {
        let packet = APDUPacket(
            direction: .command,
            rawBytes: [0x00, 0xA4, 0x04, 0x00],
            rawHex: "00 A4 04 00",
            header: APDUHeader(cla: 0x00, ins: 0xA4, p1: 0x04, p2: 0x00),
            summary: "SELECT APPLICATION / FILE"
        )
        return TraceEntry(sequenceNumber: seq, source: .simulated(scenario: "FilterTest"), packet: packet)
    }

    private func makeResponseEntry(seq: Int, sw1: UInt8, sw2: UInt8) -> TraceEntry {
        let sw = StatusWord(sw1: sw1, sw2: sw2)
        let packet = APDUPacket(
            direction: .response,
            rawBytes: [sw1, sw2],
            rawHex: String(format: "%02X %02X", sw1, sw2),
            statusWord: sw,
            summary: sw.meaning
        )
        return TraceEntry(sequenceNumber: seq, source: .simulated(scenario: "FilterTest"), packet: packet)
    }

    private func makeEventEntry(seq: Int) -> TraceEntry {
        let packet = APDUPacket(direction: .event, rawHex: "", summary: "Card connected", fullMessage: "Card inserted into reader")
        return TraceEntry(sequenceNumber: seq, source: .simulated(scenario: "FilterTest"), packet: packet)
    }

    func testStoreAppendsEntry() {
        let store = makeStore(entries: [makeCommandEntry(seq: 1)])
        XCTAssertEqual(store.entries.count, 1)
    }

    func testStoreClear() {
        let store = makeStore(entries: [makeCommandEntry(seq: 1), makeCommandEntry(seq: 2)])
        store.clear()
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertEqual(store.statusMessage, "Log cleared.")
    }

    func testFilterCategoryAll() {
        let store = makeStore(entries: [makeCommandEntry(seq: 1), makeResponseEntry(seq: 2, sw1: 0x90, sw2: 0x00)])
        store.selectedCategory = .all
        XCTAssertEqual(store.filteredEntries.count, 2)
    }

    func testFilterCategoryAPDUOnly() {
        let store = makeStore(entries: [makeCommandEntry(seq: 1), makeEventEntry(seq: 2)])
        store.selectedCategory = .apduOnly
        XCTAssertEqual(store.filteredEntries.count, 1)
        XCTAssertTrue(store.filteredEntries.first?.packet.isAPDU ?? false)
    }

    func testFilterCategorySystemEvents() {
        let store = makeStore(entries: [makeCommandEntry(seq: 1), makeEventEntry(seq: 2)])
        store.selectedCategory = .systemEvents
        XCTAssertEqual(store.filteredEntries.count, 1)
        XCTAssertFalse(store.filteredEntries.first?.packet.isAPDU ?? true)
    }

    func testFilterCategorySuccessOnly() {
        let store = makeStore(entries: [
            makeResponseEntry(seq: 1, sw1: 0x90, sw2: 0x00),
            makeResponseEntry(seq: 2, sw1: 0x69, sw2: 0x83)
        ])
        store.selectedCategory = .successOnly
        XCTAssertEqual(store.filteredEntries.count, 1)
        XCTAssertTrue(store.filteredEntries.first?.packet.statusWord?.isSuccess ?? false)
    }

    func testFilterCategoryErrorsOnly() {
        let store = makeStore(entries: [
            makeResponseEntry(seq: 1, sw1: 0x90, sw2: 0x00),
            makeResponseEntry(seq: 2, sw1: 0x69, sw2: 0x83)
        ])
        store.selectedCategory = .errorsOnly
        XCTAssertEqual(store.filteredEntries.count, 1)
        XCTAssertFalse(store.filteredEntries.first?.packet.statusWord?.isSuccess ?? true)
    }

    func testFilterTextMatchesSummary() {
        let store = makeStore(entries: [makeCommandEntry(seq: 1), makeEventEntry(seq: 2)])
        store.filterText = "SELECT"
        XCTAssertEqual(store.filteredEntries.count, 1)
    }

    func testFilterTextMatchesRawHex() {
        let store = makeStore(entries: [makeCommandEntry(seq: 1)])
        store.filterText = "00 A4"
        XCTAssertEqual(store.filteredEntries.count, 1)
    }

    func testFilterTextNoMatch() {
        let store = makeStore(entries: [makeCommandEntry(seq: 1)])
        store.filterText = "ZZZZZZZZ"
        XCTAssertEqual(store.filteredEntries.count, 0)
    }

    func testHasActiveFiltersDefault() {
        let store = makeStore(entries: [])
        XCTAssertFalse(store.hasActiveFilters)
    }

    func testHasActiveFiltersWithText() {
        let store = makeStore(entries: [])
        store.filterText = "test"
        XCTAssertTrue(store.hasActiveFilters)
    }

    func testHasActiveFiltersWithCategory() {
        let store = makeStore(entries: [])
        store.selectedCategory = .apduOnly
        XCTAssertTrue(store.hasActiveFilters)
    }

    func testResetFilters() {
        let store = makeStore(entries: [])
        store.filterText = "hello"
        store.selectedCategory = .errorsOnly
        store.selectedSubsystemFilter = "com.apple.nfc"
        store.resetFilters()
        XCTAssertFalse(store.hasActiveFilters)
        XCTAssertEqual(store.filterText, "")
        XCTAssertEqual(store.selectedCategory, .all)
        XCTAssertEqual(store.selectedSubsystemFilter, "All")
    }

    func testAvailableSubsystemsIncludesAll() {
        let store = makeStore(entries: [makeCommandEntry(seq: 1)])
        XCTAssertTrue(store.availableSubsystems.contains("All"))
    }
}

