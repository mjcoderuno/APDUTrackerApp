import Foundation

public enum TraceSource: Codable, Sendable, Equatable {
    case systemLog(subsystem: String, process: String)
    case directHardware(readerName: String)
    case simulated(scenario: String)
    
    public var label: String {
        switch self {
        case .systemLog(let subsystem, let process):
            return "[\(process)] \(subsystem)"
        case .directHardware(let readerName):
            return "[Reader] \(readerName)"
        case .simulated(let scenario):
            return "[Simulation] \(scenario)"
        }
    }
}

public struct TraceEntry: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let sequenceNumber: Int
    public let timestamp: Date
    public let source: TraceSource
    public let packet: APDUPacket
    public let rawLogMessage: String?
    
    public init(
        id: UUID = UUID(),
        sequenceNumber: Int,
        timestamp: Date = Date(),
        source: TraceSource,
        packet: APDUPacket,
        rawLogMessage: String? = nil
    ) {
        self.id = id
        self.sequenceNumber = sequenceNumber
        self.timestamp = timestamp
        self.source = source
        self.packet = packet
        self.rawLogMessage = rawLogMessage
    }
}
