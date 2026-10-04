import Cocoa

@MainActor
class SidebarNotesView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        fillNextpagePaneBackground(dirtyRect)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        MainActor.assumeIsolated { [self] in
            applyNextpagePaneBackground()
        }
    }
}
