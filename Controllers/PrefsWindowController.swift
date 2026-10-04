import Cocoa

@MainActor
final class PrefsWindowController: NSWindowController, NSWindowDelegate {
    private var splitViewController: NSSplitViewController!
    private var sidebarViewController: NSViewController!
    private var prefsContentViewController: NSViewController!
    private var sidebarView: PrefsSidebarView!

    private lazy var generalPrefsVC = GeneralPrefsViewController()
    private lazy var editorPrefsVC = EditorPrefsViewController()
    private lazy var typographyPrefsVC = TypographyPrefsViewController()
    private lazy var promptPrefsVC = PromptPrefsViewController()

    private var currentCategory: PreferencesCategory = .general
    private var hasPreparedWindowForDisplay = false

    private enum Metrics {
        static let windowSize = NSSize(width: 800, height: 520)
        static let sidebarWidth: CGFloat = 176
        /// Keeps the sidebar list comfortably clear of the bottom edge on the
        /// shortest page.
        static let minimumHeight: CGFloat = 300
    }

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Metrics.windowSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.minSize = Metrics.windowSize
        window.maxSize = Metrics.windowSize

        window.styleMask.insert(.titled)
        window.styleMask.insert(.closable)
        window.styleMask.insert(.fullSizeContentView)
        window.isReleasedWhenClosed = false

        self.init(window: window)

        setupUIComponents()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateAlwaysOnTopState),
            name: .alwaysOnTopChanged,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .alwaysOnTopChanged, object: nil)
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        if splitViewController == nil {
            setupUIComponents()
        }
    }

    private func setupUIComponents() {
        guard window != nil else { return }

        window?.delegate = self

        setupWindow()
        setupSplitView()
        setupSidebar()
        setupContent()
        alignLabelColumns()
        showCategory(.general)
        applyWindowAppearance()

        window?.titleVisibility = .hidden
        window?.titlebarAppearsTransparent = true
        window?.title = currentCategory.title
        window?.toolbarStyle = .preference
        window?.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window?.standardWindowButton(.zoomButton)?.isHidden = true
    }

    private func setupWindow() {
        guard window != nil else {
            fatalError("PrefsWindowController window should be initialized during init")
        }
    }

    private func setupSplitView() {
        splitViewController = NSSplitViewController()

        // Replace default splitView with custom one
        let customSplitView = PrefsSplitView()
        customSplitView.isVertical = true
        customSplitView.dividerStyle = .thin
        customSplitView.autoresizesSubviews = false

        splitViewController.splitView = customSplitView

        splitViewController.splitViewItems.forEach { item in
            item.canCollapse = false
        }

        window?.contentViewController = splitViewController
    }

    private func setupSidebar() {
        sidebarView = PrefsSidebarView(frame: NSRect(x: 0, y: 0, width: Metrics.sidebarWidth, height: Metrics.windowSize.height))
        sidebarView.delegate = self

        sidebarViewController = NSViewController()
        sidebarViewController.view = sidebarView

        let sidebarItem = NSSplitViewItem(viewController: sidebarViewController)
        sidebarItem.minimumThickness = Metrics.sidebarWidth
        sidebarItem.maximumThickness = Metrics.sidebarWidth
        sidebarItem.canCollapse = false

        sidebarItem.allowsFullHeightLayout = true
        sidebarItem.titlebarSeparatorStyle = .none

        splitViewController.addSplitViewItem(sidebarItem)
    }

    private func setupContent() {
        prefsContentViewController = NSViewController()
        let contentView = PrefsContentBackgroundView(
            frame: NSRect(
                x: 0,
                y: 0,
                width: Metrics.windowSize.width - Metrics.sidebarWidth,
                height: Metrics.windowSize.height
            ))
        prefsContentViewController.view = contentView

        let contentItem = NSSplitViewItem(viewController: prefsContentViewController)
        contentItem.canCollapse = false

        splitViewController.addSplitViewItem(contentItem)
    }

    private func showCategory(_ category: PreferencesCategory) {
        currentCategory = category

        if let currentVC = prefsContentViewController.children.first {
            currentVC.removeFromParent()
            currentVC.view.removeFromSuperview()
        }

        let newVC = viewController(for: category)
        window?.title = category.title

        prefsContentViewController.addChild(newVC)

        newVC.view.translatesAutoresizingMaskIntoConstraints = false
        prefsContentViewController.view.addSubview(newVC.view)

        NSLayoutConstraint.activate([
            newVC.view.leadingAnchor.constraint(equalTo: prefsContentViewController.view.leadingAnchor),
            newVC.view.trailingAnchor.constraint(equalTo: prefsContentViewController.view.trailingAnchor),
            newVC.view.topAnchor.constraint(equalTo: prefsContentViewController.view.topAnchor),
            newVC.view.bottomAnchor.constraint(equalTo: prefsContentViewController.view.bottomAnchor),
        ])

        sidebarView?.selectCategory(category)
        fitWindow(to: newVC, animate: window?.isVisible == true)
    }

    /// Sizes the window to the page, keeping its top edge where it is, so a
    /// four-row page does not sit on the tallest page's empty space.
    private func fitWindow(to viewController: NSViewController, animate: Bool) {
        guard let window, let page = viewController as? BasePrefsViewController else { return }
        let height = max(Metrics.minimumHeight, page.preferredContentHeight.rounded(.up))
        let size = NSSize(width: Metrics.windowSize.width, height: height)
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
        guard frame.size != window.frame.size else { return }
        frame.origin = NSPoint(x: window.frame.minX, y: window.frame.maxY - frame.height)
        window.minSize = frame.size
        window.maxSize = frame.size
        window.setFrame(frame, display: true, animate: animate)
    }

    /// Every page gets the label column its widest label needs, measured
    /// across all pages, so the controls stay put when switching pages.
    private func alignLabelColumns() {
        let pages: [BasePrefsViewController] = [generalPrefsVC, editorPrefsVC, typographyPrefsVC, promptPrefsVC]
        pages.forEach { _ = $0.view }
        guard let width = pages.map(\.widestLabel).max() else { return }
        pages.forEach { $0.applyLabelColumnWidth(width) }
    }

    private func viewController(for category: PreferencesCategory) -> NSViewController {
        switch category {
        case .general:
            return generalPrefsVC
        case .typography:
            return typographyPrefsVC
        case .editor:
            return editorPrefsVC
        case .prompt:
            return promptPrefsVC
        }
    }

    func show() {
        if !isWindowLoaded {
            _ = window
        }

        prepareWindowForDisplayIfNeeded()
        updateAlwaysOnTopState()

        showWindow(self)
        window?.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showGlobalPromptSettings() {
        promptPrefsVC.selectGlobalPrompt()
        showCategory(.prompt)
        show()
    }

    @objc private func updateAlwaysOnTopState() {
        window?.level = UserDefaultsManagement.alwaysOnTop ? .floating : .normal
    }

    func selectCategory(_ category: PreferencesCategory) {
        showCategory(category)
    }

    func showPromptSettings(for project: Project?) {
        promptPrefsVC.select(project: project)
        showCategory(.prompt)
        show()
    }
}

@MainActor
private final class PromptPrefsViewController: BasePrefsViewController {
    private var scopePopUp: NSPopUpButton!
    private var textView: NSTextView!
    private var statusLabel: NSTextField!
    private var journalProject: Project?

    override func setupUI() {
        let stack = installPreferencesStack()

        scopePopUp = NSPopUpButton()
        scopePopUp.target = self
        scopePopUp.action = #selector(scopeChanged(_:))
        let scopeRow = makePreferencesRow(labelText: "\(I18n.str("Prompt Scope")):", control: scopePopUp)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.widthAnchor.constraint(equalToConstant: PrefsFormMetrics.controlWidth).isActive = true
        scrollView.heightAnchor.constraint(equalToConstant: 220).isActive = true

        textView = NSTextView()
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isVerticallyResizable = true
        textView.minSize = NSSize(width: 0, height: 220)
        scrollView.documentView = textView

        statusLabel = NSTextField(wrappingLabelWithString: "")
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.maximumNumberOfLines = 2
        statusLabel.widthAnchor.constraint(equalToConstant: PrefsFormMetrics.controlWidth).isActive = true

        let saveButton = NSButton(title: I18n.str("Save"), target: self, action: #selector(save(_:)))
        let reloadButton = NSButton(title: I18n.str("Reload"), target: self, action: #selector(reload(_:)))
        let buttons = makeControlStack([saveButton, reloadButton], spacing: 8)

        addPreferencesGroups([[scopeRow], [scrollView, statusLabel, buttons]], to: stack)
        refreshScopeOptions()
    }

    override func setupValues() {
        if journalProject == nil {
            journalProject = AppContext.shared.viewController?.getSidebarProject().flatMap { $0.isTrash ? nil : $0 }
        }
        refreshScopeOptions()
        loadPrompt()
    }

    func select(project: Project?) {
        journalProject = project?.isTrash == true ? nil : project
        guard isViewLoaded else { return }
        refreshScopeOptions(selectJournal: journalProject != nil)
        loadPrompt()
    }

    func selectGlobalPrompt() {
        guard isViewLoaded else { return }
        refreshScopeOptions()
        scopePopUp.selectItem(at: 0)
        loadPrompt()
    }

    private var promptStore: PromptStore? {
        guard let root = AppContext.shared.storage.getDefault()?.url else { return nil }
        return PromptStore(storageRoot: root)
    }

    private var selectedScope: PromptScope? {
        guard scopePopUp?.selectedTag() == 1, let journalProject else { return .global }
        return .journal(journalProject)
    }

    private func refreshScopeOptions(selectJournal: Bool = false) {
        guard scopePopUp != nil else { return }
        scopePopUp.removeAllItems()
        scopePopUp.addItem(withTitle: I18n.str("Global"))
        scopePopUp.lastItem?.tag = 0

        if let journalProject, !journalProject.isTrash {
            scopePopUp.addItem(withTitle: "\(I18n.str("Current Journal")) — \(journalProject.label)")
            scopePopUp.lastItem?.tag = 1
            scopePopUp.selectItem(at: selectJournal ? 1 : 0)
        }
    }

    @objc private func scopeChanged(_ sender: NSPopUpButton) {
        loadPrompt()
    }

    @objc private func reload(_ sender: Any) {
        loadPrompt()
    }

    @objc private func save(_ sender: Any) {
        guard let store = promptStore, let scope = selectedScope else { return }
        do {
            try store.save(textView.string, scope: scope)
            statusLabel.stringValue = I18n.str("Prompt saved")
        } catch {
            statusLabel.stringValue = error.localizedDescription
            NextpageAlert.show(
                message: I18n.str("Could not save prompt"),
                informativeText: error.localizedDescription,
                style: .warning,
                for: view.window
            )
        }
    }

    private func loadPrompt() {
        guard let store = promptStore, let scope = selectedScope else {
            textView?.string = ""
            statusLabel?.stringValue = I18n.str("Choose a journal folder before editing prompts.")
            return
        }

        do {
            textView?.string = try store.prompt(for: scope)
            statusLabel?.stringValue = scope == .global
                ? I18n.str("Saved at config/prompt.md")
                : I18n.str("Saved as prompt.md in the current journal")
        } catch {
            textView?.string = ""
            statusLabel?.stringValue = error.localizedDescription
        }
    }
}

extension PrefsWindowController: PrefsSidebarDelegate {
    func sidebarDidSelectCategory(_ category: PreferencesCategory) {
        guard category != currentCategory else { return }
        showCategory(category)
    }

    func refreshThemeAppearance() {
        updateWindowBackgroundColors()
        sidebarView?.refreshAppearance()
    }
}

extension PrefsWindowController {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        window?.orderOut(self)
        return false
    }

    func windowDidChangeEffectiveAppearance(_ notification: Notification) {
        applyWindowAppearance()
    }
}

extension PrefsWindowController {
    fileprivate func applyWindowAppearance() {
        guard let window else { return }

        let targetAppearance: NSAppearance? =
            switch UserDefaultsManagement.appearanceType {
            case .Light: NSAppearance(named: .aqua)
            case .Dark: NSAppearance(named: .darkAqua)
            case .System, .Custom: nil
            }

        window.appearance = targetAppearance
        window.contentView?.appearance = targetAppearance

        updateWindowBackgroundColors()

        // Ensure subviews refresh their appearance
        sidebarView?.refreshAppearance()
    }

    fileprivate func updateWindowBackgroundColors() {
        guard let window else { return }

        let effectiveAppearance = window.effectiveAppearance
        var backgroundColor: NSColor = .windowBackgroundColor
        effectiveAppearance.performAsCurrentDrawingAppearance {
            backgroundColor = Theme.settingsWindowBackgroundColor
        }

        window.backgroundColor = backgroundColor
    }
}

private final class PrefsContentBackgroundView: NSView {
    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        updateColors()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateColors()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    private func updateColors() {
        let appearance = window?.effectiveAppearance ?? effectiveAppearance
        let resolvedColor = Theme.settingsContentBackgroundColor.resolvedColor(for: appearance)
        layer?.backgroundColor = resolvedColor.cgColor
    }
}

// MARK: - Custom SplitView for Preferences
final class PrefsSplitView: NSSplitView {
    override func drawDivider(in rect: NSRect) {
        Theme.settingsDividerColor.resolvedColor(for: effectiveAppearance).setFill()

        guard Theme.usesModernSystemChrome else {
            rect.fill()
            return
        }

        NSBezierPath(rect: hairlineRect(in: rect)).fill()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    private func hairlineRect(in rect: NSRect) -> NSRect {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let thickness = 1 / scale

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

extension PrefsWindowController {
    fileprivate func prepareWindowForDisplayIfNeeded() {
        guard let window else { return }

        window.contentView?.layoutSubtreeIfNeeded()

        if !hasPreparedWindowForDisplay {
            if let page = prefsContentViewController.children.first {
                fitWindow(to: page, animate: false)
            }
            window.center()
            hasPreparedWindowForDisplay = true
        }
    }
}
