import Cocoa

class EditorView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        Theme.editorSurfaceBackgroundColor.resolvedColor(for: effectiveAppearance).setFill()
        dirtyRect.fill()
        wantsLayer = true
        layer?.backgroundColor = Theme.editorSurfaceBackgroundColor.resolvedColor(for: effectiveAppearance).cgColor
    }
}
