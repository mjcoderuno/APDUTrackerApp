import SwiftUI
#if canImport(BioCardCore)
import BioCardCore
#endif
#if canImport(BioCardUI)
import BioCardUI
#endif

@main
public struct BioCardApp: App {
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
