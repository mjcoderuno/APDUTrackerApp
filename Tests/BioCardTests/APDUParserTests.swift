import XCTest
@testable import BioCardCore

final class APDUParserTests: XCTestCase {
    
    func testHexToBytesConversion() {
        let hex = "00 A4 04 00 07 A0 00 00 00 04 10 10"
        let bytes = APDUParser.hexToBytes(hex)
        XCTAssertEqual(bytes.count, 12)
        XCTAssertEqual(bytes[0], 0x00)
        XCTAssertEqual(bytes[1], 0xA4)
        XCTAssertEqual(bytes[2], 0x04)
        XCTAssertEqual(bytes[3], 0x00)
    }
    
    func testSelectCommandParsing() {
        let hex = "00 A4 04 00 07 A0 00 00 00 04 10 10"
        let bytes = APDUParser.hexToBytes(hex)
        let packet = APDUParser.parseCommandAPDU(bytes: bytes)
        
        XCTAssertNotNil(packet)
        XCTAssertEqual(packet?.direction, .command)
        XCTAssertEqual(packet?.header?.cla, 0x00)
        XCTAssertEqual(packet?.header?.ins, 0xA4)
        XCTAssertEqual(packet?.data.count, 7)
    }
    
    func testBiometricVerifyCommandParsing() {
        let hex = "00 20 00 81 04 11 22 33 44"
        let bytes = APDUParser.hexToBytes(hex)
        let packet = APDUParser.parseCommandAPDU(bytes: bytes)
        
        XCTAssertNotNil(packet)
        XCTAssertEqual(packet?.direction, .command)
        XCTAssertEqual(packet?.header?.ins, 0x20)
        XCTAssertTrue(packet?.summary.contains("BIOMETRIC VERIFY") == true)
    }
    
    func testResponseStatusWords() {
        // Success 90 00
        let successBytes = APDUParser.hexToBytes("90 00")
        let successPacket = APDUParser.parseResponseAPDU(bytes: successBytes)
        XCTAssertEqual(successPacket?.statusWord?.isSuccess, true)
        
        // Biometric retry 63 C2
        let retryBytes = APDUParser.hexToBytes("63 C2")
        let retryPacket = APDUParser.parseResponseAPDU(bytes: retryBytes)
        XCTAssertEqual(retryPacket?.statusWord?.isBiometricRetry, true)
        XCTAssertEqual(retryPacket?.statusWord?.remainingRetries, 2)
        
        // Security status not satisfied 69 82
        let secBytes = APDUParser.hexToBytes("69 82")
        let secPacket = APDUParser.parseResponseAPDU(bytes: secBytes)
        XCTAssertEqual(secPacket?.statusWord?.code, 0x6982)
        XCTAssertTrue(secPacket?.statusWord?.meaning.contains("Security status not satisfied") == true)
    }
}
