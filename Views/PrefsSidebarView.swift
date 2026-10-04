import Cocoa

// MARK: - Preferences Sidebar Delegate Protocol
@MainActor
protocol PrefsSidebarDelegate: AnyObject {
    func sidebarDidSelectCategory(_ category: PreferencesCategory)
}

// MARK: - Preferences Sidebar View
final class PrefsSidebarView: NSVisualEffectView {
    private enum Metrics {
        static let contentTopInset: CGFloat = 58
    }

    weak var delegate: PrefsSidebarDelegate?
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var scrollViewTopConstraint: NSLayoutConstraint!
    private var categories: [PreferencesCategory] = PreferencesCategory.allCases
    private var selectedCategory: PreferencesCategory = .general

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        setupScrollView()
        setupTableView()
        setupConstraints()
        setupAppearance()
    }

    private func setupScrollView() {
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.backgroundColor = NSColor.clear

        // Ensure the clip view is also transparent
        scrollView.contentView.drawsBackground = false
        scrollView.contentView.wantsLayer = true
        scrollView.contentView.layer?.backgroundColor = NSColor.clear.cgColor

        addSubview(scrollView)
    }

    private func setupTableView() {
        tableView = NSTableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.headerView = nil
        tableView.focusRingType = .none
        tableView.selectionHighlightStyle = .none  // Disable system selection drawing
        tableView.floatsGroupRows = false
        tableView.rowSizeStyle = .medium
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear  // Ensure table itself is transparent

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("CategoryColumn"))
        column.title = ""
        column.isEditable = false
        column.resizingMask = .autoresizingMask
        column.width = bounds.width
        tableView.addTableColumn(column)
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle

        scrollView.documentView = tableView
    }

    private func setupConstraints() {
        scrollViewTopConstraint = scrollView.topAnchor.constraint(equalTo: topAnchor, constant: Metrics.contentTopInset)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollViewTopConstraint,
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func setupAppearance() {
        wantsLayer = true
        configureMaterial()
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

    override func layout() {
        super.layout()
        tableView.frame = scrollView.contentView.bounds
        tableView.tableColumns.first?.width = tableView.bounds.width
    }

    private func updateColors() {
        guard let tableView else { return }
        let appearance = window?.effectiveAppearance ?? effectiveAppearance
        configureMaterial()

        let backgroundColor = Theme.settingsSidebarBackgroundColor.resolvedColor(for: appearance)

        layer?.backgroundColor = backgroundColor.cgColor
        tableView.backgroundColor = backgroundColor

        // Refresh all rows to update appearance
        tableView.enumerateAvailableRowViews { rowView, _ in
            rowView.needsDisplay = true
            // Force cell views to update their text colors immediately
            for case let cellView as PrefsSidebarCellView in rowView.subviews {
                cellView.setSelected(rowView.isSelected)
            }
        }
    }

    private func configureMaterial() {
        if Theme.usesModernSystemChrome {
            material = .sidebar
            blendingMode = .behindWindow
            state = .active
            isEmphasized = false
            layer?.backgroundColor = NSColor.clear.cgColor
        } else {
            material = .contentBackground
            blendingMode = .withinWindow
            state = .inactive
        }
    }

    func refreshAppearance() {
        updateColors()
    }

    func selectCategory(_ category: PreferencesCategory) {
        guard let index = categories.firstIndex(of: category) else {
            AppDelegate.trackError(NSError(domain: "PrefsSidebarError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Category \(category) not found"]), context: "PrefsSidebarView.selectCategory")
            return
        }
        selectedCategory = category

        // Ensure selection is properly set and visible
        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        tableView.scrollRowToVisible(index)

        // Force immediate display update
        if let rowView = tableView.rowView(atRow: index, makeIfNecessary: true) {
            rowView.needsDisplay = true
        }
    }
}

// MARK: - NSTableViewDataSource
extension PrefsSidebarView: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return categories.count
    }
}

// MARK: - NSTableViewDelegate
extension PrefsSidebarView: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let category = categories[row]
        let cellView = PrefsSidebarCellView()
        cellView.configure(with: category)
        return cellView
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return PrefsSidebarRowView()
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 28
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < categories.count else { return }

        let category = categories[selectedRow]
        selectedCategory = category
        delegate?.sidebarDidSelectCategory(category)
    }
}

// MARK: - Preferences Sidebar Cell View
final class PrefsSidebarCellView: NSTableCellView {
    private var iconView: NSImageView!
    private var titleLabel: NSTextField!
    private var iconWidthConstraint: NSLayoutConstraint!
    private var labelLeadingConstraint: NSLayoutConstraint!
    private var isRowSelected = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.setAccessibilityElement(false)
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)

        titleLabel = NSTextField()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.isBordered = false
        titleLabel.backgroundColor = NSColor.clear
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        titleLabel.usesSingleLineMode = true
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.cell?.wraps = false
        titleLabel.cell?.isScrollable = true
        updateTextColor()
        addSubview(iconView)
        addSubview(titleLabel)

        setupConstraints()
    }

    private func setupConstraints() {
        iconWidthConstraint = iconView.widthAnchor.constraint(equalToConstant: 15)
        labelLeadingConstraint = titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconWidthConstraint,
            iconView.heightAnchor.constraint(equalToConstant: 15),

            labelLeadingConstraint,
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
        ])
    }

    func configure(with category: PreferencesCategory) {
        titleLabel.stringValue = category.title

        if let assetName = category.iconAssetName,
            let image = NSImage(named: assetName)
        {
            iconView.image = image
            iconView.image?.isTemplate = true
            iconView.isHidden = false
            iconWidthConstraint.constant = 15
            labelLeadingConstraint.constant = 8
        } else if #available(macOS 11.0, *),
            let image = NSImage(systemSymbolName: category.systemSymbolName, accessibilityDescription: category.title)
        {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            iconView.image = image.withSymbolConfiguration(config) ?? image
            iconView.image?.isTemplate = true
            iconView.isHidden = false
            iconWidthConstraint.constant = 15
            labelLeadingConstraint.constant = 8
        } else {
            iconView.image = nil
            iconView.isHidden = true
            iconWidthConstraint.constant = 0
            labelLeadingConstraint.constant = 0
        }

        updateTextColor()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateTextColor()
    }

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
            updateTextColor()
        }
    }

    private func updateTextColor() {
        let appearance = window?.effectiveAppearance ?? effectiveAppearance
        if isRowSelected || backgroundStyle == .emphasized {
            let color = selectedTextColor(for: appearance)
            titleLabel.textColor = color
            iconView.contentTintColor = color
        } else {
            let color = Theme.secondaryTextColor.resolvedColor(for: appearance)
            titleLabel.textColor = color
            iconView.contentTintColor = color
        }
    }

    private func selectedTextColor(for appearance: NSAppearance?) -> NSColor {
        if UserDefaultsManagement.appearanceType == .Custom {
            return Theme.textColor.resolvedColor(for: appearance)
        }

        if appearance?.isDark == true {
            return NSColor(calibratedWhite: 0.92, alpha: 1)
        }

        return NSColor(calibratedWhite: 0.18, alpha: 1)
    }

    func refreshTextColor() {
        updateTextColor()
    }

    func setSelected(_ selected: Bool) {
        isRowSelected = selected
        updateTextColor()
    }
}

// MARK: - Preferences Sidebar Row View
final class PrefsSidebarRowView: NSTableRowView {
    override var isEmphasized: Bool {
        get { false }
        set {}
    }

    override var isSelected: Bool {
        didSet {
            if oldValue != isSelected {
                needsDisplay = true
                // Notify cell views to update text colors
                updateCellTextColors()
            }
        }
    }

    override func drawBackground(in dirtyRect: NSRect) {
        // Don't draw anything - we override drawSelection instead
    }

    override func drawSelection(in dirtyRect: NSRect) {
        guard isSelected else { return }

        let selectionRect = bounds.insetBy(dx: 8, dy: 2)
        let path = NSBezierPath(roundedRect: selectionRect, xRadius: 6, yRadius: 6)
        Theme.sidebarSelectionBackgroundColor.resolvedColor(for: effectiveAppearance).setFill()
        path.fill()

        guard Theme.usesModernSystemChrome else { return }

        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let strokeWidth = 1 / scale
        let strokeRect = selectionRect.insetBy(dx: strokeWidth / 2, dy: strokeWidth / 2)
        let strokePath = NSBezierPath(roundedRect: strokeRect, xRadius: 6, yRadius: 6)
        strokePath.lineWidth = strokeWidth
        Theme.sidebarSelectionStrokeColor.resolvedColor(for: effectiveAppearance).setStroke()
        strokePath.stroke()
    }

    override func draw(_ dirtyRect: NSRect) {
        if isSelected {
            drawSelection(in: dirtyRect)
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
        updateCellTextColors()
    }

    override var backgroundColor: NSColor {
        get { return .clear }
        set {}
    }

    private func updateCellTextColors() {
        // Force cell views to update their text colors immediately
        for case let cellView as PrefsSidebarCellView in subviews {
            cellView.setSelected(isSelected)
        }
    }
}
