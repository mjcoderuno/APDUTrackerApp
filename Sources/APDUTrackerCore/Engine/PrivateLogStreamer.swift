import Foundation

public final class PrivateLogStreamer: @unchecked Sendable {
    
    public enum StreamStatus: String, Sendable {
        case stopped = "Stopped"
        case streaming = "Active (Sniffing System Logs)"
        case error = "Unavailable (Private API restricted)"
    }
    
    public typealias LogHandler = @Sendable (TraceEntry) -> Void
    
    private var streamObject: AnyObject?
    private var isStreaming = false
    private let queue = DispatchQueue(label: "com.apdutracker.privatelogstreamer", qos: .userInitiated)
    private var sequenceCounter = 0
    
    public init() {}
    
    public var isAvailable: Bool {
        let handle = dlopen("/System/Library/PrivateFrameworks/LoggingSupport.framework/LoggingSupport", RTLD_NOW)
        defer { if let handle { dlclose(handle) } }
        return handle != nil && NSClassFromString("OSLogEventLiveStream") != nil
    }
    
    public func start(onPacket: @escaping LogHandler) throws {
        guard !isStreaming else { return }
        
        let path = "/System/Library/PrivateFrameworks/LoggingSupport.framework/LoggingSupport"
        guard let handle = dlopen(path, RTLD_NOW) else {
            throw NSError(
                domain: "PrivateLogStreamer",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not load LoggingSupport.framework at \(path)"]
            )
        }
        
        guard let streamClass = NSClassFromString("OSLogEventLiveStream") as? NSObject.Type else {
            dlclose(handle)
            throw NSError(
                domain: "PrivateLogStreamer",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "OSLogEventLiveStream class not found in runtime."]
            )
        }
        
        let stream = streamClass.init()
        self.streamObject = stream
        
        // Comprehensive predicate covering ALL Apple smart card, authentication, and NFC subsystems
        let predicate = NSPredicate(format: HistoricalLogReader.targetPredicateString)
        
        // Configure stream via KVC or selectors
        if stream.responds(to: Selector(("setFilterPredicate:"))) {
            _ = stream.perform(Selector(("setFilterPredicate:")), with: predicate)
        }
        
        // Set flags to 0xFF to include Info, Debug, and Sensitive/Private categories
        if stream.responds(to: Selector(("setFlags:"))) {
            stream.setValue(NSNumber(value: 0xFF), forKey: "flags")
        }
        
        // Define event handler block
        let block: @convention(block) (AnyObject) -> Void = { [weak self] (proxy: AnyObject) in
            guard let self = self else { return }
            self.processLogEvent(proxy: proxy, onPacket: onPacket)
        }
        
        if stream.responds(to: Selector(("setEventHandler:"))) {
            _ = stream.perform(Selector(("setEventHandler:")), with: block)
        }
        
        if stream.responds(to: Selector(("setQueue:"))) {
            _ = stream.perform(Selector(("setQueue:")), with: self.queue)
        }
        
        // Activate stream
        if stream.responds(to: Selector(("activate"))) {
            _ = stream.perform(Selector(("activate")))
            self.isStreaming = true
        } else {
            throw NSError(
                domain: "PrivateLogStreamer",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Stream object does not respond to activate."]
            )
        }
    }
    
    public func stop() {
        guard isStreaming, let stream = streamObject else { return }
        if stream.responds(to: Selector(("invalidate"))) {
            _ = stream.perform(Selector(("invalidate")))
        }
        self.streamObject = nil
        self.isStreaming = false
    }
    
    private func processLogEvent(proxy: AnyObject, onPacket: @escaping LogHandler) {
        let date = (proxy.value(forKey: "date") as? Date) ?? Date()
        let process = (proxy.value(forKey: "process") as? String) ?? "system"
        let subsystem = (proxy.value(forKey: "subsystem") as? String) ?? "com.apple.CryptoTokenKit"
        let message = (proxy.value(forKey: "composedMessage") as? String) ?? ""
        
        sequenceCounter += 1
        
        if let parsed = APDUParser.parseLogLine(message, timestamp: date) {
            let packet = APDUPacket(
                id: parsed.id,
                timestamp: date,
                direction: parsed.direction,
                rawBytes: parsed.rawBytes,
                rawHex: parsed.rawHex,
                header: parsed.header,
                data: parsed.data,
                statusWord: parsed.statusWord,
                summary: parsed.summary,
                fullMessage: message
            )
            let entry = TraceEntry(
                sequenceNumber: sequenceCounter,
                timestamp: date,
                source: .systemLog(subsystem: subsystem, process: process),
                packet: packet,
                rawLogMessage: message
            )
            onPacket(entry)
        } else {
            let packet = APDUPacket(
                timestamp: date,
                direction: .event,
                rawBytes: [],
                rawHex: message,
                header: nil,
                data: [],
                statusWord: nil,
                summary: message,
                fullMessage: message
            )
            let entry = TraceEntry(
                sequenceNumber: sequenceCounter,
                timestamp: date,
                source: .systemLog(subsystem: subsystem, process: process),
                packet: packet,
                rawLogMessage: message
            )
            onPacket(entry)
        }
    }
}
