import Foundation

public final class TextExporter: Sendable {
    
    public init() {}
    
    /// Generates a standardized, readable TXT string report from an array of trace entries
    public static func generateReport(from entries: [TraceEntry], deviceDescription: String = "Apple Device (macOS / iOS)") -> String {
        var output = ""
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        // Header
        output += "================================================================================\n"
        output += "                   BIO CARD APDU TRACE AUDIT REPORT\n"
        output += "================================================================================\n"
        output += "Generated:   \(dateFormatter.string(from: Date()))\n"
        output += "Environment: \(deviceDescription)\n"
        output += "Total Logs:  \(entries.count) packet(s)\n"
        
        let successCount = entries.filter { $0.packet.statusWord?.isSuccess == true }.count
        let retryCount = entries.filter { $0.packet.statusWord?.isBiometricRetry == true }.count
        let errorCount = entries.filter {
            if let sw = $0.packet.statusWord {
                return !sw.isSuccess && !sw.isBiometricRetry
            }
            return false
        }.count
        
        output += "Summary:     \(successCount) Success | \(retryCount) Biometric Retries | \(errorCount) Errors\n"
        output += "================================================================================\n\n"
        
        guard !entries.isEmpty else {
            output += "No APDU packets captured in this session.\n"
            return output
        }
        
        // Items
        for entry in entries {
            let seq = String(format: "[%04d]", entry.sequenceNumber)
            let timeStr = dateFormatter.string(from: entry.timestamp)
            let dir = entry.packet.direction.rawValue
            
            output += "\(seq) \(timeStr) | \(entry.source.label) [\(dir)]\n"
            
            if entry.packet.isAPDU {
                output += "  \(dir): \(entry.packet.rawHex)\n"
                if let header = entry.packet.header {
                    output += "  Header:   [\(header.formattedString)]\n"
                }
                if !entry.packet.data.isEmpty {
                    output += "  Data:     [\(entry.packet.data.count) bytes]\n"
                }
                if let sw = entry.packet.statusWord {
                    output += "  Status:   \(sw.hexString) -> \(sw.meaning)\n"
                } else {
                    output += "  Action:   \(entry.packet.summary)\n"
                }
            } else {
                let msg = entry.packet.fullMessage ?? entry.rawLogMessage ?? entry.packet.rawHex
                output += "  Log:      \(msg)\n"
            }
            
            output += "--------------------------------------------------------------------------------\n"
        }
        
        output += "\n=== End of Report ===\n"
        return output
    }
    
    /// Writes the generated report directly to a specified file URL
    public static func exportToFile(entries: [TraceEntry], at fileURL: URL) throws {
        let content = generateReport(from: entries)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
