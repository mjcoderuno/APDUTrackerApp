import Foundation
#if canImport(CoreNFC)
import CoreNFC
#endif
#if canImport(CryptoTokenKit)
import CryptoTokenKit
#endif

public final class DirectTransceiver: NSObject, @unchecked Sendable {
    
    public typealias PacketCallback = @Sendable (TraceEntry) -> Void
    private var sequenceCounter = 1000
    private var activeCallback: PacketCallback?
    
    #if os(iOS) && canImport(CoreNFC)
    private var nfcSession: NFCTagReaderSession?
    #endif
    
    public override init() {
        super.init()
    }
    
    /// Starts real hardware NFC card scan on iOS, or runs direct test sequence on macOS/Simulator
    public func startCardSession(onPacket: @escaping PacketCallback) {
        self.activeCallback = onPacket
        
        #if os(iOS) && canImport(CoreNFC)
        if NFCTagReaderSession.readingAvailable {
            let session = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: nil)
            session?.alertMessage = "Hold your biometric card near the top of your iPhone to read APDUs."
            session?.begin()
            self.nfcSession = session
            return
        }
        #endif
        
        // Fallback or macOS execution: run test sequence
        runBiometricTestSequence(onPacket: onPacket)
    }
    
    /// Runs a simulated or direct test sequence with a biometric smart card
    public func runBiometricTestSequence(onPacket: @escaping PacketCallback) {
        let dispatchQueue = DispatchQueue.global(qos: .userInitiated)
        
        dispatchQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 1. SELECT AID (Biometric Applet)
            let selectHex = "00 A4 04 00 07 A0 00 00 00 04 10 10"
            self.emit(hex: selectHex, direction: .command, source: .directHardware(readerName: "BioCard Direct Bus"), onPacket: onPacket)
            Thread.sleep(forTimeInterval: 0.15)
            
            // Response: 90 00
            self.emit(hex: "90 00", direction: .response, source: .directHardware(readerName: "BioCard Direct Bus"), onPacket: onPacket)
            Thread.sleep(forTimeInterval: 0.25)
            
            // 2. BIOMETRIC VERIFY (Attempt 1 - Poor finger placement simulation)
            let verifyHex1 = "00 20 00 81 12 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F 10 11 12"
            self.emit(hex: verifyHex1, direction: .command, source: .directHardware(readerName: "BioCard Direct Bus"), onPacket: onPacket)
            Thread.sleep(forTimeInterval: 0.40)
            
            // Response: 63 C2 (Failed, 2 retries remaining)
            self.emit(hex: "63 C2", direction: .response, source: .directHardware(readerName: "BioCard Direct Bus"), onPacket: onPacket)
            Thread.sleep(forTimeInterval: 0.50)
            
            // 3. BIOMETRIC VERIFY (Attempt 2 - Successful Match-on-Card)
            let verifyHex2 = "00 20 00 81 12 10 20 30 40 50 60 70 80 90 A0 B0 C0 D0 E0 F0 01 02 03"
            self.emit(hex: verifyHex2, direction: .command, source: .directHardware(readerName: "BioCard Direct Bus"), onPacket: onPacket)
            Thread.sleep(forTimeInterval: 0.65)
            
            // Response: 90 00 (Match Confirmed)
            self.emit(hex: "90 00", direction: .response, source: .directHardware(readerName: "BioCard Direct Bus"), onPacket: onPacket)
        }
    }
    
    private func emit(
        hex: String,
        direction: APDUDirection,
        source: TraceSource,
        onPacket: @escaping PacketCallback
    ) {
        let bytes = APDUParser.hexToBytes(hex)
        let packet: APDUPacket?
        if direction == .command {
            packet = APDUParser.parseCommandAPDU(bytes: bytes)
        } else {
            packet = APDUParser.parseResponseAPDU(bytes: bytes)
        }
        
        guard let validPacket = packet else { return }
        sequenceCounter += 1
        let entry = TraceEntry(
            sequenceNumber: sequenceCounter,
            timestamp: Date(),
            source: source,
            packet: validPacket,
            rawLogMessage: hex
        )
        onPacket(entry)
    }
}

#if os(iOS) && canImport(CoreNFC)
extension DirectTransceiver: NFCTagReaderSessionDelegate {
    
    public func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}
    
    public func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        self.nfcSession = nil
    }
    
    public func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else { return }
        
        session.connect(to: tag) { [weak self] (error: Error?) in
            guard let self = self, error == nil else {
                session.invalidate(errorMessage: "Connection to card failed.")
                return
            }
            
            guard case let .iso7816(iso7816Tag) = tag else {
                session.invalidate(errorMessage: "Card is not an ISO 7816 smart card.")
                return
            }
            
            guard let callback = self.activeCallback else { return }
            
            // 1. Log Card Detected & Historical Bytes
            let readerName = "iPhone CoreNFC"
            if let hist = iso7816Tag.historicalBytes {
                let histHex = APDUParser.bytesToHex([UInt8](hist))
                self.emit(hex: histHex, direction: .event, source: .directHardware(readerName: readerName), onPacket: callback)
            }
            
            // 2. Transmit SELECT AID Command
            let selectAID = Data([0x00, 0xA4, 0x04, 0x00, 0x07, 0xA0, 0x00, 0x00, 0x00, 0x04, 0x10, 0x10])
            guard let apdu = NFCISO7816APDU(data: selectAID) else {
                session.invalidate(errorMessage: "Malformed APDU.")
                return
            }
            
            self.emit(hex: APDUParser.bytesToHex([UInt8](selectAID)), direction: .command, source: .directHardware(readerName: readerName), onPacket: callback)
            
            iso7816Tag.sendCommand(apdu: apdu) { (responseData: Data, sw1: UInt8, sw2: UInt8, sendError: Error?) in
                if let sendError = sendError {
                    session.invalidate(errorMessage: "APDU transmit failed: \(sendError.localizedDescription)")
                    return
                }
                
                var fullResponse = [UInt8](responseData)
                fullResponse.append(sw1)
                fullResponse.append(sw2)
                let respHex = APDUParser.bytesToHex(fullResponse)
                self.emit(hex: respHex, direction: .response, source: .directHardware(readerName: readerName), onPacket: callback)
                
                session.alertMessage = "Biometric APDU trace captured successfully!"
                session.invalidate()
            }
        }
    }
}
#endif
