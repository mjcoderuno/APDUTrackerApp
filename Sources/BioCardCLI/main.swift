import Foundation
import BioCardCore

print("=======================================================")
print(" BioCard APDU Trace Sniffer & Direct Hardware Verifier ")
print("=======================================================")

let streamer = PrivateLogStreamer()
print("LoggingSupport Private Framework available: \(streamer.isAvailable)")

let direct = DirectTransceiver()
var capturedEntries: [TraceEntry] = []
let semaphore = DispatchSemaphore(value: 0)

print("\nExecuting biometric card verification sequence...")
direct.runBiometricTestSequence { entry in
    capturedEntries.append(entry)
    let dir = entry.packet.direction.rawValue
    let summary = entry.packet.summary
    print(String(format: " [%04d] %@: %@ | %@", entry.sequenceNumber, dir, entry.packet.rawHex, summary))
    
    if capturedEntries.count >= 6 {
        semaphore.signal()
    }
}

_ = semaphore.wait(timeout: .now() + 3.0)

print("\nGenerating APDU Trace .txt Report...")
let report = TextExporter.generateReport(from: capturedEntries)
print(report)

let exportPath = FileManager.default.currentDirectoryPath + "/sample_apdu_trace.txt"
let exportURL = URL(fileURLWithPath: exportPath)
try? TextExporter.exportToFile(entries: capturedEntries, at: exportURL)
print("Trace report exported to: \(exportPath)")
