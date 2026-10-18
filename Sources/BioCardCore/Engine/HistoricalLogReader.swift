import Foundation

public final class HistoricalLogReader: Sendable {
    
    public init() {}
    
    public struct LogEventJSON: Decodable {
        public let timestamp: String?
        public let eventMessage: String?
        public let subsystem: String?
        public let processImagePath: String?
        public let processID: Int?
        public let category: String?
    }
    
    public static let targetPredicateString = """
    subsystem CONTAINS[c] 'CryptoTokenKit' OR \
    subsystem CONTAINS[c] 'SmartCard' OR \
    subsystem CONTAINS[c] 'AuthenticationServices' OR \
    subsystem CONTAINS[c] 'LocalAuthentication' OR \
    subsystem CONTAINS[c] 'coreauthd' OR \
    subsystem CONTAINS[c] 'NearField' OR \
    subsystem CONTAINS[c] 'stockholm' OR \
    subsystem CONTAINS[c] 'securityd' OR \
    process == 'ctkd' OR \
    process == 'ctkahp' OR \
    process == 'coreauthd' OR \
    process == 'nfcd'
    """
    
    /// Pulls historical logs from Apple Unified Logging for the specified timeframe (e.g. "15m", "1h", "6h", "24h")
    public static func fetchLogs(timeframe: String = "1h") async throws -> [TraceEntry] {
        #if os(macOS)
        return try await fetchLogsOnMac(timeframe: timeframe)
        #else
        return try await fetchLogsOnIOS(timeframe: timeframe)
        #endif
    }
    
    #if os(macOS)
    private static func fetchLogsOnMac(timeframe: String) async throws -> [TraceEntry] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
                
                process.arguments = [
                    "show",
                    "--predicate", targetPredicateString,
                    "--last", timeframe,
                    "--info",
                    "--debug",
                    "--style", "ndjson"
                ]
                
                let stdoutPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = Pipe()
                
                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }
                
                let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                
                guard let outputString = String(data: data, encoding: .utf8) else {
                    continuation.resume(returning: [])
                    return
                }
                
                let entries = parseNDJSONOutput(outputString)
                continuation.resume(returning: entries)
            }
        }
    }
    #endif
    
    #if !os(macOS)
    private static func fetchLogsOnIOS(timeframe: String) async throws -> [TraceEntry] {
        // On iOS/iPadOS, query LoggingSupport private framework's OSLogEventStore / OSLogEventStream
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let path = "/System/Library/PrivateFrameworks/LoggingSupport.framework/LoggingSupport"
                guard let handle = dlopen(path, RTLD_NOW) else {
                    continuation.resume(returning: [])
                    return
                }
                defer { dlclose(handle) }
                
                guard let storeClass = NSClassFromString("OSLogEventStore") as? NSObject.Type,
                      let streamClass = NSClassFromString("OSLogEventStream") as? NSObject.Type else {
                    continuation.resume(returning: [])
                    return
                }
                
                guard let store = storeClass.perform(Selector(("localStore"))).takeUnretainedValue() as? NSObject else {
                    continuation.resume(returning: [])
                    return
                }
                
                let stream = streamClass.init()
                let predicate = NSPredicate(format: targetPredicateString)
                
                if stream.responds(to: Selector(("setFilterPredicate:"))) {
                    _ = stream.perform(Selector(("setFilterPredicate:")), with: predicate)
                }
                
                if stream.responds(to: Selector(("setFlags:"))) {
                    stream.setValue(NSNumber(value: 0xFF), forKey: "flags")
                }
                
                continuation.resume(returning: [])
            }
        }
    }
    #endif
    
    public static func parseNDJSONOutput(_ outputString: String) -> [TraceEntry] {
        let lines = outputString.components(separatedBy: .newlines)
        var entries: [TraceEntry] = []
        let decoder = JSONDecoder()
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSZ"
        
        var seq = 0
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.starts(with: "{") else { continue }
            
            guard let jsonData = trimmed.data(using: .utf8),
                          let event = try? decoder.decode(LogEventJSON.self, from: jsonData),
                          let message = event.eventMessage, !message.isEmpty else {
                continue
            }
            
            let date: Date
            if let ts = event.timestamp, let parsedDate = isoFormatter.date(from: ts) {
                date = parsedDate
            } else {
                date = Date()
            }
            
            let subsystem = event.subsystem ?? "com.apple.CryptoTokenKit"
            let procPath = event.processImagePath ?? "ctkd"
            let processName = (procPath as NSString).lastPathComponent
            
            seq += 1
            
            // Case 1: Message contains an actual APDU
            if let parsedPacket = APDUParser.parseLogLine(message, timestamp: date) {
                let packet = APDUPacket(
                    id: parsedPacket.id,
                    timestamp: date,
                    direction: parsedPacket.direction,
                    rawBytes: parsedPacket.rawBytes,
                    rawHex: parsedPacket.rawHex,
                    header: parsedPacket.header,
                    data: parsedPacket.data,
                    statusWord: parsedPacket.statusWord,
                    summary: parsedPacket.summary,
                    fullMessage: message
                )
                let entry = TraceEntry(
                    sequenceNumber: seq,
                    timestamp: date,
                    source: .systemLog(subsystem: subsystem, process: processName),
                    packet: packet,
                    rawLogMessage: message
                )
                entries.append(entry)
            } else {
                // Case 2: Smart Card / CTAP / Token lifecycle event
                let summary = sanitizeEventSummary(message)
                let packet = APDUPacket(
                    timestamp: date,
                    direction: .event,
                    rawBytes: [],
                    rawHex: message,
                    header: nil,
                    data: [],
                    statusWord: nil,
                    summary: summary,
                    fullMessage: message
                )
                let entry = TraceEntry(
                    sequenceNumber: seq,
                    timestamp: date,
                    source: .systemLog(subsystem: subsystem, process: processName),
                    packet: packet,
                    rawLogMessage: message
                )
                entries.append(entry)
            }
        }
        return entries
    }
    
    private static func sanitizeEventSummary(_ msg: String) -> String {
        if msg.contains("activating connection") {
            return "Token Client Connected: \(msg)"
        } else if msg.contains("LAContext") {
            return "LocalAuthentication Context: \(msg)"
        } else if msg.contains("deallocated") {
            return "Token Session Released"
        }
        return msg
    }
}
