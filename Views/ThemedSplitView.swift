import Cocoa

@MainActor
class ThemedSplitView: NSSplitView, NSSplitViewDelegate {
    override func awakeFromNib() {
        super.awakeFromNib()
        MainActor.assumeIsolated { [self] in
            delegate = self
            applyDividerColor()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyDividerColor()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyDividerColor()
    }

    override func drawDivider(in rect: NSRect) {
        let dividerColor = resolvedDividerColor()
        dividerColor.setFill()

        guard Theme.usesModernSystemChrome else {
            NSBezierPath(rect: rect).fill()
            return
        }

        NSBezierPath(rect: hairlineRect(in: rect)).fill()
    }

    func currentDividerColor() -> NSColor {
        return Theme.splitDividerColor
    }

    func resolvedDividerColor() -> NSColor {
        let appearance = window?.effectiveAppearance ?? effectiveAppearance
        return currentDividerColor().resolvedColor(for: appearance)
    }

    func applyDividerColor() {
        setValue(resolvedDividerColor(), forKey: "dividerColor")
        needsDisplay = true
        displayIfNeeded()
    }

    private func hairlineRect(in rect: NSRect) -> NSRect {
        let thickness: CGFloat = 1

        if isVertical {
            return NSRect(
                x: rect.midX - thickness / 2,
                y: rect.minY,
                width: thickness,
                height: rect.height
            )
        }

        return NSRect(
            x: rect.minX,
            y: rect.midY - thickness / 2,
            width: rect.width,
            height: thickness
        )
    }
}
