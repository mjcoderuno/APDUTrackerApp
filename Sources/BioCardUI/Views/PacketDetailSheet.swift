import SwiftUI
#if canImport(BioCardCore)
import BioCardCore
#endif
#if os(macOS)
import AppKit
#endif

public struct PacketDetailSheet: View {
    public let entry: TraceEntry
    @Environment(\.dismiss) private var dismiss
    @State private var copyFeedback: String?
    
    public init(entry: TraceEntry) {
        self.entry = entry
    }
    
    private var displayMessage: String {
        if let full = entry.packet.fullMessage, !full.isEmpty {
            return full
        }
        if let raw = entry.rawLogMessage, !raw.isEmpty {
            return raw
        }
        return entry.packet.rawHex
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Title Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Log Entry Detail #\(String(format: "%04d", entry.sequenceNumber))")
                        .font(.headline)
                    Text("\(entry.source.label) • \(entry.timestamp.formatted(date: .abbreviated, time: .complete))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let feedback = copyFeedback {
                    Text(feedback)
                        .font(.caption2)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(4)
                }
                
                Button(action: copyAllDetails) {
                    Label("Copy All", systemImage: "doc.on.doc")
                }
                .controlSize(.small)
                
#if os(macOS)
                Menu {
                    Button("Save to BioCard Folder", action: saveToBioCardFolder)
                    Button("Save to Desktop", action: saveToDesktop)
                    Button("Choose Location...", action: saveWithFilePicker)
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .controlSize(.small)
#else
                ShareLink(item: generateReport()) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .controlSize(.small)
#endif

                Button("Done") {
                    dismiss()
                }
                .controlSize(.small)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.secondary.opacity(0.1))
            
            Divider()
            
            // Content Body
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // Card 1: Primary Log / APDU Content
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(entry.packet.isAPDU ? "APDU HEX STREAM" : "FULL LOG / EVENT MESSAGE")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Copy Text") {
                                copyText(displayMessage)
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                        }
                        
                        Text(displayMessage)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.08))
                            .cornerRadius(8)
                    }
                    .padding(14)
                    .background(Color(white: 0.12, opacity: 0.05))
                    .cornerRadius(10)
                    
                    // Card 2: APDU Header & Status Word (if APDU)
                    if entry.packet.isAPDU {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("APDU PROTOCOL BREAKDOWN")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            
                            if let header = entry.packet.header {
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading) {
                                        Text("CLA").font(.caption2).foregroundColor(.secondary)
                                        Text(String(format: "0x%02X", header.cla)).font(.subheadline.monospaced().bold())
                                    }
                                    VStack(alignment: .leading) {
                                        Text("INS").font(.caption2).foregroundColor(.secondary)
                                        Text(String(format: "0x%02X", header.ins)).font(.subheadline.monospaced().bold())
                                    }
                                    VStack(alignment: .leading) {
                                        Text("P1").font(.caption2).foregroundColor(.secondary)
                                        Text(String(format: "0x%02X", header.p1)).font(.subheadline.monospaced().bold())
                                    }
                                    VStack(alignment: .leading) {
                                        Text("P2").font(.caption2).foregroundColor(.secondary)
                                        Text(String(format: "0x%02X", header.p2)).font(.subheadline.monospaced().bold())
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text("Action").font(.caption2).foregroundColor(.secondary)
                                        Text(entry.packet.summary).font(.caption.bold())
                                    }
                                }
                                .padding(10)
                                .background(Color.secondary.opacity(0.06))
                                .cornerRadius(6)
                            }
                            
                            if let sw = entry.packet.statusWord {
                                HStack(spacing: 12) {
                                    Image(systemName: sw.isSuccess ? "checkmark.circle.fill" : (sw.isBiometricRetry ? "exclamationmark.triangle.fill" : "xmark.circle.fill"))
                                        .foregroundColor(sw.isSuccess ? .green : (sw.isBiometricRetry ? .orange : .red))
                                        .font(.title3)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Status Word: \(sw.hexString)")
                                            .font(.subheadline.monospaced().bold())
                                        Text(sw.meaning)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if let retries = sw.remainingRetries {
                                        Text("\(retries) Retries Left")
                                            .font(.caption.bold())
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.orange.opacity(0.18))
                                            .foregroundColor(.orange)
                                            .cornerRadius(6)
                                    }
                                }
                                .padding(10)
                                .background(Color.secondary.opacity(0.06))
                                .cornerRadius(6)
                            }
                            
                            if !entry.packet.data.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Payload Data (\(entry.packet.data.count) bytes)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(APDUParser.bytesToHex(entry.packet.data))
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                        .padding(8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.secondary.opacity(0.06))
                                        .cornerRadius(6)
                                }
                            }
                        }
                        .padding(14)
                        .background(Color(white: 0.12, opacity: 0.05))
                        .cornerRadius(10)
                    }
                    
                    // Card 3: System Metadata
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SYSTEM METADATA")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        
                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                            GridRow {
                                Text("Sequence:").foregroundColor(.secondary).font(.caption)
                                Text(String(format: "#%04d", entry.sequenceNumber)).font(.caption.monospaced())
                            }
                            GridRow {
                                Text("Timestamp:").foregroundColor(.secondary).font(.caption)
                                Text(entry.timestamp.formatted(date: .complete, time: .complete)).font(.caption.monospaced())
                            }
                            GridRow {
                                Text("Source:").foregroundColor(.secondary).font(.caption)
                                Text(entry.source.label).font(.caption)
                            }
                            GridRow {
                                Text("Direction / Type:").foregroundColor(.secondary).font(.caption)
                                Text(entry.packet.direction.rawValue).font(.caption.bold())
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(white: 0.12, opacity: 0.05))
                    .cornerRadius(10)
                }
                .padding(16)
            }
        }
        .frame(minWidth: 700, idealWidth: 750, minHeight: 520, idealHeight: 650)
    }
    
    private func copyText(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
        copyFeedback = "Copied!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copyFeedback = nil
        }
    }
    
    private func copyAllDetails() {
        var report = "=== BioCard Log Detail ===\n"
        report += "Sequence: #\(String(format: "%04d", entry.sequenceNumber))\n"
        report += "Timestamp: \(entry.timestamp)\n"
        report += "Source: \(entry.source.label)\n"
        report += "Type: \(entry.packet.direction.rawValue)\n"
        report += "Message: \(displayMessage)\n"
        if let sw = entry.packet.statusWord {
            report += "Status: \(sw.hexString) (\(sw.meaning))\n"
        }
        copyText(report)
    }
    
    private func generateReport() -> String {
        var report = "=== BioCard Log Detail ===\n"
        report += "Sequence: #\(String(format: "%04d", entry.sequenceNumber))\n"
        report += "Timestamp: \(entry.timestamp)\n"
        report += "Source: \(entry.source.label)\n"
        report += "Type: \(entry.packet.direction.rawValue)\n"
        report += "Message: \(displayMessage)\n"
        if let sw = entry.packet.statusWord {
            report += "Status: \(sw.hexString) (\(sw.meaning))\n"
        }
        return report
    }
    
    private func timestampString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
    
    #if os(macOS)
    private func saveToBioCardFolder() {
        // Get user's Documents directory safely using FileManager
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            // Could not find documents directory; fail gracefully
            return
        }
        
        let bioCardDir = documentsDir.appendingPathComponent("BioCard")
        
        // Check if BioCard folder exists, and create if not
        if !FileManager.default.fileExists(atPath: bioCardDir.path) {
            do {
                try FileManager.default.createDirectory(at: bioCardDir, withIntermediateDirectories: true)
            } catch {
                // Failed to create directory; fail gracefully
                return
            }
        }
        
        let filename = "BioCard_Trace_\(timestampString()).txt"
        let url = bioCardDir.appendingPathComponent(filename)
        
        saveToFile(url: url)
    }
    
    private func saveToDesktop() {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let filename = "BioCard_Trace_\(timestampString()).txt"
        let url = desktop.appendingPathComponent(filename)
        saveToFile(url: url)
    }
    
    private func saveWithFilePicker() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "BioCard_Trace_\(timestampString()).txt"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            saveToFile(url: url)
        }
    }
    
    private func saveToFile(url: URL) {
        do {
            try generateReport().write(to: url, atomically: true, encoding: .utf8)
            // you could add UI feedback if desired
        } catch {
            // handle error if needed
        }
    }
    #endif
}

