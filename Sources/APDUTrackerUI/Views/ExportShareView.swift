import SwiftUI
#if canImport(APDUTrackerCore)
import APDUTrackerCore
#endif
#if os(macOS)
import AppKit
#endif

public struct ExportShareView: View {
    public let entries: [TraceEntry]
    @Environment(\.dismiss) private var dismiss
    @State private var reportText: String = ""
    @State private var saveStatus: String?
    
    public init(entries: [TraceEntry]) {
        self.entries = entries
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Action Buttons Bar
                HStack(spacing: 12) {
                    #if os(macOS)
                    Button(action: saveToAPDUTrackerFolder) {
                        Label("Save to APDUTracker Folder", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: saveToDesktop) {
                        Label("Save to Desktop", systemImage: "menubar.dock.rectangle")
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: saveWithFilePicker) {
                        Label("Choose Location...", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: copyToClipboard) {
                        Label("Copy All", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    #else
                    ShareLink(item: reportText) {
                        Label("Share Trace Report", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: copyToClipboard) {
                        Label("Copy All", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    #endif
                }
                .padding(.top, 8)
                .padding(.horizontal)
                
                if let status = saveStatus {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(status)
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(6)
                }
                
                // Report Text Viewer
                TextEditor(text: .constant(reportText))
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            .navigationTitle("Export APDU Trace (\(entries.count) logs)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                reportText = TextExporter.generateReport(from: entries)
            }
        }
        .frame(minWidth: 650, minHeight: 480)
    }
    
    #if os(macOS)
    private func saveToAPDUTrackerFolder() {
        let dir = URL(fileURLWithPath: "")
        let filename = "APDUTracker_Trace_\(timestampString()).txt"
        let url = dir.appendingPathComponent(filename)
        saveToFile(url: url)
    }
    
    private func saveToDesktop() {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let filename = "APDUTracker_Trace_\(timestampString()).txt"
        let url = desktop.appendingPathComponent(filename)
        saveToFile(url: url)
    }
    
    private func saveWithFilePicker() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "APDUTracker_Trace_\(timestampString()).txt"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            saveToFile(url: url)
        }
    }
    
    private func saveToFile(url: URL) {
        do {
            try reportText.write(to: url, atomically: true, encoding: .utf8)
            saveStatus = "Saved successfully: \(url.path)"
        } catch {
            saveStatus = "Save failed: \(error.localizedDescription)"
        }
    }
    #endif
    
    private func copyToClipboard() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(reportText, forType: .string)
        #else
        UIPasteboard.general.string = reportText
        #endif
        saveStatus = "Copied entire report to clipboard!"
    }
    
    private func timestampString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
}

