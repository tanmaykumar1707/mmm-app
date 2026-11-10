import SwiftUI

 @main
struct MMMWatchApp: App {

    @WKApplicationDelegateAdaptor var delegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        // Boot the WCSession connector early so it activates before first view load
        _ = PhoneConnector.shared
    }
}
