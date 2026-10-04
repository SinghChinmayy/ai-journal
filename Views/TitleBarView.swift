import Cocoa

/// A toolbar-style control that consistently presents the app preferences entry point.
@MainActor
final class SettingsButton: NSButton {
    override func awakeFromNib() {
        super.awakeFromNib()

        setButtonType(.momentaryPushIn)
        target = NSApp.delegate
        action = #selector(AppDelegate.openPreferences(_:))
        image = NSImage(
            systemSymbolName: "gearshape",
            accessibilityDescription: I18n.str("Settings")
        )
        image?.isTemplate = true
    }
}

@MainActor
class TitleBarView: NSView {
    var onMouseEnteredClosure: (() -> Void)?
    var onMouseExitedClosure: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        Task { @MainActor in
            refreshTrackingAreas()
        }
    }

    override func layout() {
        super.layout()
        Task { @MainActor in
            refreshTrackingAreas()
        }
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEnteredClosure?()
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExitedClosure?()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        Task { @MainActor in
            refreshTrackingAreas()
        }
    }

    private func refreshTrackingAreas() {
        trackingAreas.forEach(removeTrackingArea)
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }
}
