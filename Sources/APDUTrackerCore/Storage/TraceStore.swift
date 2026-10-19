import Foundation
import Combine

public enum LogCategoryFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case apduOnly = "APDU Only"
    case systemEvents = "System Events"
    case successOnly = "Success (90 00)"
    case errorsOnly = "Errors & Retries"
    
    public var id: String { rawValue }
}

@MainActor
public final class TraceStore: ObservableObject {
    
    @Published public private(set) var entries: [TraceEntry] = []
    @Published public var filterText: String = ""
    @Published public var selectedCategory: LogCategoryFilter = .all
    @Published public var selectedSubsystemFilter: String = "All"
    @Published public var selectedTimeframe: String = "1h"
    @Published public private(set) var isStreaming: Bool = false
    @Published public private(set) var isLoadingHistorical: Bool = false
    @Published public private(set) var statusMessage: String = "Ready"
    @Published public var lastSavedPath: String?
    
    private let streamer = PrivateLogStreamer()
    private let directTransceiver = DirectTransceiver()
    
    public init() {
        Task {
            await fetchHistoricalLogs(timeframe: "1h")
        }
    }
    
    public var availableSubsystems: [String] {
        var set = Set<String>()
        for entry in entries {
            switch entry.source {
            case .systemLog(let sub, _):
                set.insert(sub)
            case .directHardware(let name):
                set.insert(name)
            case .simulated:
                set.insert("Simulation")
            }
        }
        return ["All"] + Array(set).sorted()
    }
    
    public var filteredEntries: [TraceEntry] {
        entries.filter { entry in
            // 1. Category Filter
            switch selectedCategory {
            case .all:
                break
            case .apduOnly:
                if !entry.packet.isAPDU { return false }
            case .systemEvents:
                if entry.packet.isAPDU { return false }
            case .successOnly:
                if entry.packet.statusWord?.isSuccess != true { return false }
            case .errorsOnly:
                if let sw = entry.packet.statusWord {
                    if sw.isSuccess { return false }
                } else if entry.packet.direction != .event {
                    return false
                }
            }
            
            // 2. Subsystem Filter
            if selectedSubsystemFilter != "All" {
                switch entry.source {
                case .systemLog(let sub, _):
                    if sub != selectedSubsystemFilter { return false }
                case .directHardware(let name):
                    if name != selectedSubsystemFilter { return false }
                case .simulated:
                    if selectedSubsystemFilter != "Simulation" { return false }
                }
            }
            
            // 3. Search Query Filter
            guard !filterText.trimmingCharacters(in: .whitespaces).isEmpty else {
                return true
            }
            
            let term = filterText.lowercased()
            let matchesHex = entry.packet.rawHex.lowercased().contains(term)
            let matchesSummary = entry.packet.summary.lowercased().contains(term)
            let matchesSource = entry.source.label.lowercased().contains(term)
            let matchesLog = entry.rawLogMessage?.lowercased().contains(term) ?? false
            let matchesFull = entry.packet.fullMessage?.lowercased().contains(term) ?? false
            let matchesMeaning = entry.packet.statusWord?.meaning.lowercased().contains(term) ?? false
            
            return matchesHex || matchesSummary || matchesSource || matchesLog || matchesFull || matchesMeaning
        }
    }
    
    public var hasActiveFilters: Bool {
        !filterText.isEmpty || selectedCategory != .all || selectedSubsystemFilter != "All"
    }
    
    public func resetFilters() {
        filterText = ""
        selectedCategory = .all
        selectedSubsystemFilter = "All"
    }
    
    /// Pulls existing system logs from Apple Unified Logging
    public func fetchHistoricalLogs(timeframe: String = "1h") async {
        isLoadingHistorical = true
        statusMessage = "Pulling existing logs for past \(timeframe)..."
        
        do {
            let fetched = try await HistoricalLogReader.fetchLogs(timeframe: timeframe)
            if fetched.isEmpty {
                statusMessage = "No logs found in the past \(timeframe)."
            } else {
                var existingSet = Set(entries.map { "\($0.timestamp.timeIntervalSince1970)_\($0.rawLogMessage ?? "")" })
                var newCount = 0
                for item in fetched {
                    let key = "\(item.timestamp.timeIntervalSince1970)_\(item.rawLogMessage ?? "")"
                    if !existingSet.contains(key) {
                        existingSet.insert(key)
                        entries.append(item)
                        newCount += 1
                    }
                }
                statusMessage = "Pulled \(newCount) existing logs from past \(timeframe)."
            }
        } catch {
            statusMessage = "Failed to pull logs: \(error.localizedDescription)"
        }
        isLoadingHistorical = false
    }
    
    /// Imports external log files (.logarchive, .ndjson, or .txt trace reports)
    public func importLogFile(from fileURL: URL) async {
        isLoadingHistorical = true
        statusMessage = "Importing \(fileURL.lastPathComponent)..."
        
        do {
            let imported = try await LogFileImporter.importLog(from: fileURL)
            if imported.isEmpty {
                statusMessage = "No APDU or security logs recognized in file."
            } else {
                entries.append(contentsOf: imported)
                statusMessage = "Successfully imported \(imported.count) log(s) from \(fileURL.lastPathComponent)"
            }
        } catch {
            statusMessage = "Import error: \(error.localizedDescription)"
        }
        isLoadingHistorical = false
    }
    
    public func toggleStreaming() {
        if isStreaming {
            stopStreaming()
        } else {
            startStreaming()
        }
    }
    
    public func startStreaming() {
        guard !isStreaming else { return }
        do {
            try streamer.start { [weak self] entry in
                Task { @MainActor [weak self] in
                    self?.append(entry)
                }
            }
            isStreaming = true
            statusMessage = "Live Sniffing Active (System Logging)"
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
        }
    }
    
    public func stopStreaming() {
        streamer.stop()
        isStreaming = false
        statusMessage = "Sniffing Stopped"
    }
    
    public func runDirectTest() {
        statusMessage = "Starting card session..."
        directTransceiver.startCardSession { [weak self] entry in
            Task { @MainActor [weak self] in
                self?.append(entry)
                self?.statusMessage = "Card trace captured."
            }
        }
    }
    
    @discardableResult
    public func saveReportToLocalDisk(folder: URL? = nil) -> String? {
        guard !entries.isEmpty else {
            statusMessage = "Cannot export: log is empty."
            return nil
        }
        
        let targetDirectory: URL
        if let folder = folder {
            targetDirectory = folder
        } else {
            let pocDir = URL(fileURLWithPath: "/Users/mrityunjaykumar/Documents/POC/APDUTracker")
            if FileManager.default.fileExists(atPath: pocDir.path) {
                targetDirectory = pocDir
            } else {
                targetDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            }
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "APDUTracker_Trace_\(formatter.string(from: Date())).txt"
        let fileURL = targetDirectory.appendingPathComponent(filename)
        
        do {
            try TextExporter.exportToFile(entries: entries, at: fileURL)
            lastSavedPath = fileURL.path
            statusMessage = "Report saved to: \(filename)"
            return fileURL.path
        } catch {
            statusMessage = "Export failed: \(error.localizedDescription)"
            return nil
        }
    }
    
    public func append(_ entry: TraceEntry) {
        entries.append(entry)
    }
    
    public func clear() {
        entries.removeAll()
        statusMessage = "Log cleared."
        lastSavedPath = nil
    }
}
