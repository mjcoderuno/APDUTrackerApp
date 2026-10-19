import SwiftUI
#if canImport(APDUTrackerCore)
import APDUTrackerCore
#endif

public struct APDURowView: View {
    public let entry: TraceEntry
    
    public init(entry: TraceEntry) {
        self.entry = entry
    }
    
    private var badgeColor: Color {
        switch entry.packet.direction {
        case .command:
            return .blue
        case .response:
            if let sw = entry.packet.statusWord {
                if sw.isSuccess {
                    return .green
                } else if sw.isBiometricRetry {
                    return .orange
                } else {
                    return .red
                }
            }
            return .green
        case .event:
            return .purple
        }
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: entry.timestamp)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Row Header
            HStack(spacing: 8) {
                Text(String(format: "#%04d", entry.sequenceNumber))
                    .font(.caption2.monospaced())
                    .foregroundColor(.secondary)
                
                Text(entry.packet.direction.rawValue)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(badgeColor.opacity(0.18))
                    .foregroundColor(badgeColor)
                    .cornerRadius(4)
                
                Text(entry.source.label)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12))
                    .foregroundColor(.secondary)
                    .cornerRadius(4)
                    .lineLimit(1)
                
                Spacer()
                
                Text(formattedTime)
                    .font(.caption2.monospaced())
                    .foregroundColor(.secondary)
            }
            
            // Primary Content (Log Message or APDU Hex)
            Text(entry.packet.primaryDisplayText)
                .font(.system(.body, design: entry.packet.isAPDU ? .monospaced : .default))
                .foregroundColor(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            
            // Secondary interpretation
            if entry.packet.isAPDU {
                HStack(spacing: 4) {
                    if let sw = entry.packet.statusWord {
                        Image(systemName: sw.isSuccess ? "checkmark.circle.fill" : (sw.isBiometricRetry ? "exclamationmark.triangle.fill" : "xmark.circle.fill"))
                            .foregroundColor(badgeColor)
                            .imageScale(.small)
                    }
                    Text(entry.packet.summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if entry.packet.summary != entry.packet.fullMessage {
                Text(entry.packet.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

