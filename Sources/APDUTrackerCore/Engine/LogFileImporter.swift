import Foundation

public final class LogFileImporter: Sendable {
    
    public init() {}
    
    /// Parses an external log file (ndjson dump, standard txt trace, or logarchive) into structured TraceEntry items
    public static func importLog(from fileURL: URL) async throws -> [TraceEntry] {
        let isAccessGranted = fileURL.startAccessingSecurityScopedResource()
        defer {
            if isAccessGranted { fileURL.stopAccessingSecurityScopedResource() }
        }
        
        let fileExtension = fileURL.pathExtension.lowercased()
        
        #if os(macOS)
        if fileExtension == "logarchive" {
            return try await importFromLogArchiveOnMac(archiveURL: fileURL)
        }
        #endif
        
        let fileData = try Data(contentsOf: fileURL)
        guard let text = String(data: fileData, encoding: .utf8) else {
            throw NSError(
                domain: "LogFileImporter",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not decode file content as UTF-8 text."]
            )
        }
        
        // Format 1: ndjson from 'log show --style ndjson'
        if text.contains("\"eventMessage\"") {
            return HistoricalLogReader.parseNDJSONOutput(text)
        }
        
        // Format 2: Standard plain text APDU log
        return parsePlainTextLog(text, filename: fileURL.lastPathComponent)
    }
    
    #if os(macOS)
    private static func importFromLogArchiveOnMac(archiveURL: URL) async throws -> [TraceEntry] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
                
                process.arguments = [
                    "show",
                    "--archive", archiveURL.path,
                    "--predicate", HistoricalLogReader.targetPredicateString,
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
                
                let entries = HistoricalLogReader.parseNDJSONOutput(outputString)
                continuation.resume(returning: entries)
            }
        }
    }
    #endif
    
    private static func parsePlainTextLog(_ text: String, filename: String) -> [TraceEntry] {
        let lines = text.components(separatedBy: .newlines)
        var entries: [TraceEntry] = []
        var seq = 0
        let date = Date()
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if trimmed.starts(with: "==") || trimmed.starts(with: "--") || trimmed.starts(with: "Summary:") {
                continue
            }
            
            seq += 1
            if let packet = APDUParser.parseLogLine(trimmed, timestamp: date) {
                let entry = TraceEntry(
                    sequenceNumber: seq,
                    timestamp: date,
                    source: .systemLog(subsystem: "Imported", process: filename),
                    packet: packet,
                    rawLogMessage: trimmed
                )
                entries.append(entry)
            } else {
                let packet = APDUPacket(
                    timestamp: date,
                    direction: .event,
                    rawBytes: [],
                    rawHex: trimmed,
                    header: nil,
                    data: [],
                    statusWord: nil,
                    summary: trimmed,
                    fullMessage: trimmed
                )
                let entry = TraceEntry(
                    sequenceNumber: seq,
                    timestamp: date,
                    source: .systemLog(subsystem: "Imported", process: filename),
                    packet: packet,
                    rawLogMessage: trimmed
                )
                entries.append(entry)
            }
        }
        return entries
    }
}
