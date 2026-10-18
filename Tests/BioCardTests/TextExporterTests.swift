import XCTest
@testable import BioCardCore

final class TextExporterTests: XCTestCase {
    
    func testGenerateReport() {
        let cmdBytes = APDUParser.hexToBytes("00 A4 04 00 07 A0 00 00 00 04 10 10")
        let cmdPacket = APDUParser.parseCommandAPDU(bytes: cmdBytes)!
        let entry1 = TraceEntry(
            sequenceNumber: 1,
            source: .directHardware(readerName: "Test Reader"),
            packet: cmdPacket
        )
        
        let respBytes = APDUParser.hexToBytes("90 00")
        let respPacket = APDUParser.parseResponseAPDU(bytes: respBytes)!
        let entry2 = TraceEntry(
            sequenceNumber: 2,
            source: .directHardware(readerName: "Test Reader"),
            packet: respPacket
        )
        
        let report = TextExporter.generateReport(from: [entry1, entry2], deviceDescription: "Unit Test Environment")
        
        XCTAssertTrue(report.contains("BIO CARD APDU TRACE AUDIT REPORT"))
        XCTAssertTrue(report.contains("Total Logs:  2 packet(s)"))
        XCTAssertTrue(report.contains("1 Success"))
        XCTAssertTrue(report.contains("[0001]"))
        XCTAssertTrue(report.contains("C-APDU: 00 A4 04 00 07 A0 00 00 00 04 10 10"))
        XCTAssertTrue(report.contains("R-APDU: 90 00"))
        XCTAssertTrue(report.contains("Success / Normal Execution"))
    }
}
