import Foundation

public enum APDUDirection: String, Codable, Sendable {
    case command = "C-APDU"
    case response = "R-APDU"
    case event = "EVENT"
}

public struct APDUHeader: Codable, Sendable, Equatable {
    public let cla: UInt8
    public let ins: UInt8
    public let p1: UInt8
    public let p2: UInt8
    
    public init(cla: UInt8, ins: UInt8, p1: UInt8, p2: UInt8) {
        self.cla = cla
        self.ins = ins
        self.p1 = p1
        self.p2 = p2
    }
    
    public var formattedString: String {
        String(format: "CLA: %02X | INS: %02X | P1: %02X | P2: %02X", cla, ins, p1, p2)
    }
}

public struct StatusWord: Codable, Sendable, Equatable {
    public let sw1: UInt8
    public let sw2: UInt8
    
    public init(sw1: UInt8, sw2: UInt8) {
        self.sw1 = sw1
        self.sw2 = sw2
    }
    
    public var code: UInt16 {
        (UInt16(sw1) << 8) | UInt16(sw2)
    }
    
    public var hexString: String {
        String(format: "%02X %02X", sw1, sw2)
    }
    
    public var isSuccess: Bool {
        sw1 == 0x90 && sw2 == 0x00
    }
    
    public var isBiometricRetry: Bool {
        sw1 == 0x63 && (sw2 & 0xF0) == 0xC0
    }
    
    public var remainingRetries: Int? {
        guard isBiometricRetry else { return nil }
        return Int(sw2 & 0x0F)
    }
    
    public var meaning: String {
        switch code {
        case 0x9000:
            return "Success / Normal Execution (Match Confirmed)"
        case 0x6281:
            return "Warning: Part of returned data may be corrupted"
        case 0x6300:
            return "Biometric verification failed (No retry info)"
        case 0x63C0...0x63CF:
            if let retries = remainingRetries {
                return "Biometric match failed! (\(retries) retries remaining before lockout)"
            }
            return "Biometric match failed"
        case 0x6700:
            return "Wrong length (Lc/Le incorrect)"
        case 0x6982:
            return "Security status not satisfied (Biometric verification required)"
        case 0x6983:
            return "Authentication method blocked (Biometric sensor or PIN locked)"
        case 0x6984:
            return "Reference data invalidated"
        case 0x6985:
            return "Conditions of use not satisfied"
        case 0x6A80:
            return "Incorrect data field parameters (Malformed template)"
        case 0x6A81:
            return "Function not supported"
        case 0x6A82:
            return "File or application not found (Invalid AID)"
        case 0x6A88:
            return "Referenced data (template) not found"
        case 0x6D00:
            return "Instruction (INS) not supported or invalid"
        case 0x6E00:
            return "Class (CLA) not supported"
        default:
            if sw1 == 0x6C {
                return String(format: "Wrong Le length; re-issue with Le=%02X", sw2)
            }
            return String(format: "Status Word: %02X %02X", sw1, sw2)
        }
    }
}

public struct APDUPacket: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let direction: APDUDirection
    public let rawBytes: [UInt8]
    public let rawHex: String
    public let header: APDUHeader?
    public let data: [UInt8]
    public let statusWord: StatusWord?
    public let summary: String
    public let fullMessage: String?
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        direction: APDUDirection,
        rawBytes: [UInt8] = [],
        rawHex: String,
        header: APDUHeader? = nil,
        data: [UInt8] = [],
        statusWord: StatusWord? = nil,
        summary: String,
        fullMessage: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.direction = direction
        self.rawBytes = rawBytes
        self.rawHex = rawHex
        self.header = header
        self.data = data
        self.statusWord = statusWord
        self.summary = summary
        self.fullMessage = fullMessage
    }
    
    public var isAPDU: Bool {
        !rawBytes.isEmpty || header != nil || statusWord != nil
    }
    
    public var primaryDisplayText: String {
        if isAPDU {
            return rawHex
        }
        return fullMessage ?? summary
    }
}
