import Cocoa

extension AppDelegate {
    static func relaunchApp() {
        let appURL = Bundle.main.bundleURL

        DispatchQueue.main.async {
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.prefsWindowController?.close()
            }
            for window in NSApp.windows {
                if let sheet = window.attachedSheet {
                    window.endSheet(sheet)
                }
            }

            let configuration = NSWorkspace.OpenConfiguration()
            configuration.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
                if let error {
                    AppDelegate.trackError(error, context: "AppDelegate.relaunchApp")
                }
                DispatchQueue.main.async {
                    NSApp.terminate(nil)
                }
            }
        }
    }
}
