import SwiftUI
import UniformTypeIdentifiers
#if canImport(BioCardCore)
import BioCardCore
#endif

public struct MainConsoleView: View {
    @StateObject private var store = TraceStore()
    @State private var selectedEntry: TraceEntry?
    @State private var showExportSheet = false
    @State private var showFileImporter = false
    
    private let timeframes = ["15m", "1h", "6h", "24h"]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top Status Header Bar
                HStack(spacing: 12) {
                    Circle()
                        .fill(store.isStreaming ? Color.green : (store.isLoadingHistorical ? Color.blue : Color.orange))
                        .frame(width: 10, height: 10)
                    
                    if store.isLoadingHistorical {
                        ProgressView()
                            .controlSize(.small)
                    }
                    
                    Text(store.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(store.filteredEntries.count) of \(store.entries.count) logs")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.08))
                
                // Dedicated Filter Bar
                VStack(spacing: 6) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            // Category Filter Picker
                            ForEach(LogCategoryFilter.allCases) { cat in
                                Button(action: {
                                    store.selectedCategory = cat
                                }) {
                                    Text(cat.rawValue)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(store.selectedCategory == cat ? Color.accentColor : Color.secondary.opacity(0.12))
                                        .foregroundColor(store.selectedCategory == cat ? .white : .primary)
                                        .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Divider()
                                .frame(height: 18)
                            
                            // Subsystem Filter Menu
                            Menu {
                                ForEach(store.availableSubsystems, id: \.self) { sub in
                                    Button(sub) {
                                        store.selectedSubsystemFilter = sub
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                    Text(store.selectedSubsystemFilter == "All" ? "All Subsystems" : store.selectedSubsystemFilter)
                                        .lineLimit(1)
                                }
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(store.selectedSubsystemFilter != "All" ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
                                .cornerRadius(12)
                            }
                            
                            // Reset Filters Button
                            if store.hasActiveFilters {
                                Button(action: { store.resetFilters() }) {
                                    HStack(spacing: 2) {
                                        Image(systemName: "xmark.circle.fill")
                                        Text("Reset")
                                    }
                                    .font(.caption2.bold())
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                    }
                }
                .background(Color.secondary.opacity(0.04))
                
                Divider()
                
                // Notification Banner if file saved
                if let savedPath = store.lastSavedPath {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Saved to: \(savedPath)")
                            .font(.caption.monospaced())
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer()
                        Button("Dismiss") {
                            store.lastSavedPath = nil
                        }
                        .font(.caption2)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.12))
                }
                
                // Trace Packet List
                if store.filteredEntries.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "creditcard.and.123")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        
                        Text(store.hasActiveFilters ? "No Logs Match Current Filters" : "No APDU Traces Displayed")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        if store.hasActiveFilters {
                            Button("Reset Filters") {
                                store.resetFilters()
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Text("Pull past system logs from when you tested your card in the browser,\nstart live sniffing, or tap 'Scan Card' to read directly via NFC.")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary.opacity(0.8))
                                .padding(.horizontal, 32)
                            
                            HStack(spacing: 12) {
                                Button(action: {
                                    Task {
                                        await store.fetchHistoricalLogs(timeframe: store.selectedTimeframe)
                                    }
                                }) {
                                    Label("Pull Existing Logs (\(store.selectedTimeframe))", systemImage: "clock.arrow.circlepath")
                                }
                                .buttonStyle(.borderedProminent)
                                
                                Button(action: { store.toggleStreaming() }) {
                                    Label(store.isStreaming ? "Stop Sniffing" : "Start Sniffing",
                                          systemImage: store.isStreaming ? "stop.fill" : "play.fill")
                                }
                                .buttonStyle(.bordered)
                                
                                Button(action: { showFileImporter = true }) {
                                    Label("Import Log File...", systemImage: "square.and.arrow.down")
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.top, 8)
                        }
                        
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(store.filteredEntries) { entry in
                            HStack(alignment: .center) {
                                APDURowView(entry: entry)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(.secondary.opacity(0.5))
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedEntry = entry
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("BioCard APDU Inspector")
            .searchable(text: $store.filterText, prompt: "Search by hex, instruction, process, or status word")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    // Timeframe Picker
                    Picker("Timeframe", selection: $store.selectedTimeframe) {
                        ForEach(timeframes, id: \.self) { tf in
                            Text(tf).tag(tf)
                        }
                    }
                    .pickerStyle(.segmented)
                    #if os(macOS)
                    .frame(width: 150)
                    #endif
                    
                    // Pull Existing Logs
                    Button(action: {
                        Task {
                            await store.fetchHistoricalLogs(timeframe: store.selectedTimeframe)
                        }
                    }) {
                        Label("Pull Past Logs", systemImage: "arrow.clockwise")
                    }
                    .help("Fetch existing logs from Apple Unified Logging")
                    
                    // Import Log File
                    Button(action: { showFileImporter = true }) {
                        Label("Import File", systemImage: "square.and.arrow.down")
                    }
                    .help("Import external log file, .logarchive, or .txt trace")
                    
                    // Live Sniffing Toggle
                    Button(action: { store.toggleStreaming() }) {
                        Label(store.isStreaming ? "Stop" : "Live Sniff",
                              systemImage: store.isStreaming ? "stop.circle.fill" : "record.circle")
                    }
                    .tint(store.isStreaming ? .red : .primary)
                    .help("Sniff live APDUs from browser / security daemons")
                    
                    // Direct NFC Card Scan / Test Sequence
                    Button(action: { store.runDirectTest() }) {
                        Label("Scan Card", systemImage: "touchid")
                    }
                    .help("Scan card via NFC on iOS, or run direct test sequence")
                    
                    // Quick Save to Local Disk
                    Button(action: {
                        store.saveReportToLocalDisk()
                    }) {
                        Label("Save .TXT", systemImage: "arrow.down.doc.fill")
                    }
                    .tint(.blue)
                    .disabled(store.entries.isEmpty)
                    .help("Quickly save the trace as .txt directly to local disk")
                    
                    // Full Export & Share Sheet
                    Button(action: { showExportSheet = true }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .disabled(store.entries.isEmpty)
                    .help("Preview, share, or choose custom folder to save")
                    
                    // Clear
                    Button(role: .destructive, action: { store.clear() }) {
                        Label("Clear", systemImage: "trash")
                    }
                    .disabled(store.entries.isEmpty)
                    .help("Clear logs from memory")
                }
            }
            .sheet(item: $selectedEntry) { entry in
                PacketDetailSheet(entry: entry)
            }
            .sheet(isPresented: $showExportSheet) {
                ExportShareView(entries: store.entries)
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.plainText, .json, .data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    Task {
                        await store.importLogFile(from: url)
                    }
                case .failure(let error):
                    store.saveReportToLocalDisk() // keeps UI feedback
                }
            }
        }
    }
}
