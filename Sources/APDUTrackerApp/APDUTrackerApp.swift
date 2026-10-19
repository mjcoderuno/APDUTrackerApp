import SwiftUI
#if canImport(APDUTrackerCore)
import APDUTrackerCore
#endif
#if canImport(APDUTrackerUI)
import APDUTrackerUI
#endif

@main
public struct APDUTrackerApp: App {
    public init() {}
    
    public var body: some Scene {
        WindowGroup {
            MainConsoleView()
                #if os(macOS)
                .frame(minWidth: 850, minHeight: 600)
                #endif
        }
    }
}

