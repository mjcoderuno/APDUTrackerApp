import Foundation

public final class APDUParser: Sendable {
    
    public init() {}
    
    /// Parses a raw hex string into byte array, ignoring whitespace, punctuation, and markers.
    public static func hexToBytes(_ hex: String) -> [UInt8] {
        let cleanHex = hex
            .replacingOccurrences(of: "0x", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard cleanHex.count % 2 == 0 else { return [] }
        
        var bytes = [UInt8]()
        bytes.reserveCapacity(cleanHex.count / 2)
        
        var index = cleanHex.startIndex
        while index < cleanHex.endIndex {
            let nextIndex = cleanHex.index(index, offsetBy: 2)
            if let byte = UInt8(cleanHex[index..<nextIndex], radix: 16) {
                bytes.append(byte)
            } else {
                return []
            }
            index = nextIndex
        }
        return bytes
    }
    
    /// Formats a byte array into a standard space-separated uppercase hex string.
    public static func bytesToHex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
    
    /// Parses a Command APDU from raw bytes.
    public static func parseCommandAPDU(bytes: [UInt8], timestamp: Date = Date()) -> APDUPacket? {
        guard bytes.count >= 4 else { return nil }
        
        let cla = bytes[0]
        let ins = bytes[1]
        let p1 = bytes[2]
        let p2 = bytes[3]
        let header = APDUHeader(cla: cla, ins: ins, p1: p1, p2: p2)
        
        var dataBytes: [UInt8] = []
        var summary = instructionName(for: ins, cla: cla)
        
        if bytes.count > 4 {
            let lc = Int(bytes[4])
            if bytes.count >= 5 + lc && lc > 0 {
                dataBytes = Array(bytes[5..<(5 + lc)])
            }
        }
        
        if ins == 0x20 {
            summary = "BIOMETRIC VERIFY (Match-on-Card) [\(dataBytes.count) bytes template]"
        } else if ins == 0x2A {
            summary = "PERFORM BIOMETRIC OPERATION [\(dataBytes.count) bytes]"
        } else if ins == 0xA4 {
            summary = "SELECT APPLICATION / FILE"
        }
        
        return APDUPacket(
            timestamp: timestamp,
            direction: .command,
            rawBytes: bytes,
            rawHex: bytesToHex(bytes),
            header: header,
            data: dataBytes,
            statusWord: nil,
            summary: summary
        )
    }
    
    /// Parses a Response APDU from raw bytes.
    public static func parseResponseAPDU(bytes: [UInt8], timestamp: Date = Date()) -> APDUPacket? {
        guard bytes.count >= 2 else { return nil }
        
        let sw1 = bytes[bytes.count - 2]
        let sw2 = bytes[bytes.count - 1]
        let statusWord = StatusWord(sw1: sw1, sw2: sw2)
        let dataBytes = Array(bytes.prefix(bytes.count - 2))
        
        let summary = "Response: [\(statusWord.hexString)] \(statusWord.meaning)"
        
        return APDUPacket(
            timestamp: timestamp,
            direction: .response,
            rawBytes: bytes,
            rawHex: bytesToHex(bytes),
            header: nil,
            data: dataBytes,
            statusWord: statusWord,
            summary: summary
        )
    }
    
    /// Attempts to parse an APDU or CTAP trace line from system unified logs.
    public static func parseLogLine(_ line: String, timestamp: Date = Date()) -> APDUPacket? {
        // Pattern 1: Hex trace like "APDU transmit: 00 a4 04 00 07 ..." or "send: 0020..."
        let lower = line.lowercased()
        
        if lower.contains("send") || lower.contains("transmit") || lower.contains("c-apdu") || lower.contains("-->") {
            if let hexRange = extractHexCandidate(from: line) {
                let bytes = hexToBytes(hexRange)
                if bytes.count >= 4 {
                    return parseCommandAPDU(bytes: bytes, timestamp: timestamp)
                }
            }
        }
        
        if lower.contains("recv") || lower.contains("receive") || lower.contains("r-apdu") || lower.contains("sw=") || lower.contains("<--") {
            if let hexRange = extractHexCandidate(from: line) {
                let bytes = hexToBytes(hexRange)
                if bytes.count >= 2 {
                    return parseResponseAPDU(bytes: bytes, timestamp: timestamp)
                }
            }
        }
        
        // Generic fallback: check if the string directly looks like hex
        let candidateBytes = hexToBytes(line)
        if candidateBytes.count >= 4 {
            return parseCommandAPDU(bytes: candidateBytes, timestamp: timestamp)
        } else if candidateBytes.count == 2 {
            return parseResponseAPDU(bytes: candidateBytes, timestamp: timestamp)
        }
        
        return nil
    }
    
    private static func extractHexCandidate(from text: String) -> String? {
        // Extract substring matching hex patterns (e.g. after colon or bracket)
        let components = text.components(separatedBy: CharacterSet(charactersIn: ":<>]"))
        for comp in components.reversed() {
            let trimmed = comp.trimmingCharacters(in: .whitespaces)
            let bytes = hexToBytes(trimmed)
            if bytes.count >= 2 {
                return trimmed
            }
        }
        return nil
    }
    
    private static func instructionName(for ins: UInt8, cla: UInt8) -> String {
        switch ins {
        case 0xA4: return "SELECT APPLICATION / FILE"
        case 0x20: return "VERIFY (APDUTracker Match-on-Card / PIN)"
        case 0x2A: return "PERFORM BIOMETRIC OPERATION"
        case 0xB0: return "READ BINARY"
        case 0xD6: return "UPDATE BINARY"
        case 0x84: return "GET CHALLENGE"
        case 0x82: return "EXTERNAL AUTHENTICATE"
        case 0x88: return "INTERNAL AUTHENTICATE"
        case 0xCA: return "GET DATA"
        case 0xDA: return "PUT DATA"
        case 0xC0: return "GET RESPONSE"
        case 0x10: return "FIDO CTAP2 (Authenticator Make Credential)"
        case 0x11: return "FIDO CTAP2 (Authenticator Get Assertion)"
        case 0x12: return "FIDO CTAP2 (Authenticator Get Info)"
        default:
            return String(format: "Instruction 0x%02X (CLA: 0x%02X)", ins, cla)
        }
    }
}

