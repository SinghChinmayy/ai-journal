import Cocoa

@MainActor
class AboutWindowController: NSWindowController, NSWindowDelegate {
    override func windowDidLoad() {
        super.windowDidLoad()
        window?.delegate = self
        window?.title = I18n.str("About")
        window?.styleMask.remove(.miniaturizable)
        window?.styleMask.remove(.resizable)
        window?.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window?.standardWindowButton(.zoomButton)?.isHidden = true
        window?.backgroundColor = Theme.panelBackgroundColor
        window?.center()
    }
}
