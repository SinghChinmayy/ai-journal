# Feature: Global Config & Project-Based AI Prompt Settings

## Overview

Add a two-tier AI prompt configuration system to Nextpage:

1. **Global AI Prompt** — a fallback prompt editable from a ⚙ gear button pinned at the bottom of the main sidebar (left panel), stored in `UserDefaults`.
2. **Project AI Prompt** — a per-project override prompt accessible via right-click → "AI Settings…" on any project row, stored alongside existing project settings.

When a project has no prompt set, it automatically inherits the global prompt.

---

## Architecture

```
Main Sidebar (Left Panel)
├── [top] OutlineHeaderView + addProjectButton (+)
├── [middle] sidebarScrollView → SidebarProjectView (NSOutlineView)
│   └── Project rows (right-click → "AI Settings…")
└── [bottom] SidebarFooterView → ⚙ settings button
```

### Data Flow

```
GlobalAISettingsViewController  ──writes──▶  UserDefaultsManagement.globalAIPrompt
ProjectAISettingsViewController ──writes──▶  Project.aiPrompt ──▶ Project.saveSettings()

Project.effectiveAIPrompt:
    project.aiPrompt.isEmpty ? UserDefaultsManagement.globalAIPrompt : project.aiPrompt
```

---

## Files to Change

### New Files

| File | Purpose |
|------|---------|
| `Controllers/GlobalAISettingsViewController.swift` | Popover for editing the global prompt |
| `Controllers/ProjectAISettingsViewController.swift` | Popover for editing per-project prompt |
| `Views/SidebarFooterView.swift` | Thin footer bar at the bottom of the sidebar containing the gear button |
| `NextpageTests/AIPromptSettingsTests.swift` | Unit tests for prompt persistence and fallback logic |

### Modified Files

| File | Change |
|------|--------|
| `Business/Project.swift` | Add `aiPrompt` property + `effectiveAIPrompt` computed property |
| `Business/PrefsModel.swift` | _(optional)_ Register `AISettings` as a `SettingsConfigurable` if needed later |
| `Helpers/UserDefaultsManagement.swift` | Add `globalAIPrompt` key + accessor |
| `Views/SidebarProjectView.swift` | Add "AI Settings…" context menu item and action |
| `Controllers/ViewController.swift` | Add outlet for `SidebarFooterView`, global settings popover, and `showProjectAISettings()` |
| `Resources/Localization/Base.lproj/Main.storyboard` | Add `SidebarFooterView` to sidebar column; add menu item to outline view context menu |

---

## Implementation Steps

### Step 1 — Data Model

#### `Business/Project.swift`

Add `aiPrompt` property:

```swift
public var aiPrompt: String = ""

public var effectiveAIPrompt: String {
    aiPrompt.isEmpty ? UserDefaultsManagement.globalAIPrompt : aiPrompt
}
```

Update `saveSettings()`:

```swift
public func saveSettings() {
    let data: [String: Any] = [
        "sortBy": sortBySettings.rawValue,
        "sortDirection": sortDirectionSettings.rawValue,
        "showInCommon": showInCommon,
        "showInSidebar": showInSidebar,
        "aiPrompt": aiPrompt,          // ← add this
    ]
    UserDefaults.standard.set(data, forKey: url.path)
}
```

Update `loadSettings()`:

```swift
if let prompt = settings.value(forKey: "aiPrompt") as? String {
    aiPrompt = prompt
}
```

#### `Helpers/UserDefaultsManagement.swift`

Add to `Constants` enum:

```swift
static let GlobalAIPrompt = "globalAIPrompt"
```

Add computed property:

```swift
static var globalAIPrompt: String {
    get { UserDefaults.standard.string(forKey: Constants.GlobalAIPrompt) ?? "" }
    set { UserDefaults.standard.set(newValue, forKey: Constants.GlobalAIPrompt) }
}
```

---

### Step 2 — Global AI Settings UI

#### `Controllers/GlobalAISettingsViewController.swift`

```swift
import Cocoa

@MainActor
final class GlobalAISettingsViewController: NSViewController {

    private var scrollView: NSScrollView!
    private var textView: NSTextView!
    private var headerLabel: NSTextField!
    private var captionLabel: NSTextField!

    static let preferredSize = NSSize(width: 360, height: 240)

    override func loadView() {
        view = NSView(frame: NSRect(origin: .zero, size: Self.preferredSize))
        buildUI()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        textView.string = UserDefaultsManagement.globalAIPrompt
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        UserDefaultsManagement.globalAIPrompt = textView.string
    }

    private func buildUI() {
        // Header
        headerLabel = NSTextField(labelWithString: "Global AI Prompt")
        headerLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerLabel)

        // Caption
        captionLabel = NSTextField(
            wrappingLabelWithString: "Used as the default context for AI features. Projects can override this.")
        captionLabel.font = .systemFont(ofSize: 11)
        captionLabel.textColor = .secondaryLabelColor
        captionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(captionLabel)

        // Scroll + TextView
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        textView = NSTextView()
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 6, height: 6)
        scrollView.documentView = textView
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            headerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            captionLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 4),
            captionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            captionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: captionLabel.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
        ])
    }
}
```

---

### Step 3 — Project AI Settings UI

#### `Controllers/ProjectAISettingsViewController.swift`

```swift
import Cocoa

@MainActor
final class ProjectAISettingsViewController: NSViewController {

    private var project: Project?
    private var scrollView: NSScrollView!
    private var textView: NSTextView!
    private var headerLabel: NSTextField!
    private var captionLabel: NSTextField!

    static let preferredSize = NSSize(width: 360, height: 260)

    override func loadView() {
        view = NSView(frame: NSRect(origin: .zero, size: Self.preferredSize))
        buildUI()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        textView.string = project?.aiPrompt ?? ""
        updateCaption()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        project?.aiPrompt = textView.string
        project?.saveSettings()
    }

    func load(project: Project) {
        self.project = project
        if isViewLoaded {
            textView.string = project.aiPrompt
            updateCaption()
        }
    }

    private func updateCaption() {
        let global = UserDefaultsManagement.globalAIPrompt
        if global.isEmpty {
            captionLabel.stringValue = "No global prompt set. Leave empty to use no prompt."
        } else {
            let preview = global.count > 60 ? String(global.prefix(60)) + "…" : global
            captionLabel.stringValue = "Inherits global when empty: \"\(preview)\""
        }
    }

    private func buildUI() {
        let projectName = project?.label ?? "Project"

        headerLabel = NSTextField(labelWithString: "\(projectName) — AI Prompt")
        headerLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        headerLabel.lineBreakMode = .byTruncatingTail
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerLabel)

        captionLabel = NSTextField(wrappingLabelWithString: "")
        captionLabel.font = .systemFont(ofSize: 11)
        captionLabel.textColor = .secondaryLabelColor
        captionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(captionLabel)

        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        textView = NSTextView()
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 6, height: 6)
        scrollView.documentView = textView
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            headerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            captionLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 4),
            captionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            captionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: captionLabel.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
        ])
    }
}
```

---

### Step 4 — Sidebar Footer View

#### `Views/SidebarFooterView.swift`

```swift
import Cocoa

@MainActor
final class SidebarFooterView: NSView {

    static let height: CGFloat = 32

    private(set) lazy var settingsButton: NSButton = {
        let button = NSButton()
        button.bezelStyle = .regularSquare
        button.isBordered = false
        if #available(macOS 11.0, *) {
            button.image = NSImage(systemSymbolName: "gearshape",
                                   accessibilityDescription: "Global AI Settings")
        } else {
            button.title = "⚙"
        }
        button.imageScaling = .scaleProportionallyDown
        button.image?.isTemplate = true
        button.contentTintColor = Theme.sidebarActionColor
        button.toolTip = "AI Settings"
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        addSubview(settingsButton)
        NSLayoutConstraint.activate([
            settingsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            settingsButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 20),
            settingsButton.heightAnchor.constraint(equalToConstant: 20),
        ])
    }

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
```

---

### Step 5 — Wire Sidebar Context Menu

#### `Views/SidebarProjectView.swift`

Add menu item validation:

```swift
// In validateMenuItem(_:)
case #selector(openProjectAISettings(_:)):
    return sidebarItem.type == .Category && !sidebarItem.isTrash()
```

Add the action:

```swift
@objc func openProjectAISettings(_ sender: Any) {
    guard let sidebarItem = getSidebarItem(),
          let project = sidebarItem.project,
          let vc = AppContext.shared.viewController,
          let row = clickedRow >= 0 ? rowView(atRow: clickedRow, makeIfNecessary: false) : nil
    else { return }
    vc.showProjectAISettings(for: project, relativeTo: row)
}
```

Add menu item in `awakeFromNib()` (or storyboard):

```swift
// In awakeFromNib(), after existing menu setup
let aiItem = NSMenuItem(
    title: "AI Settings…",
    action: #selector(openProjectAISettings(_:)),
    keyEquivalent: ""
)
aiItem.target = self
menu?.addItem(NSMenuItem.separator())
menu?.addItem(aiItem)
```

---

### Step 6 — Wire ViewController

#### `Controllers/ViewController.swift`

Add outlet and popover:

```swift
@IBOutlet var sidebarFooterView: SidebarFooterView!

private lazy var globalAISettingsPopover: NSPopover = {
    let vc = GlobalAISettingsViewController()
    let popover = NSPopover()
    popover.behavior = .semitransient
    popover.contentViewController = vc
    popover.contentSize = GlobalAISettingsViewController.preferredSize
    return popover
}()

@IBAction func openGlobalAISettings(_ sender: NSButton) {
    if globalAISettingsPopover.isShown {
        globalAISettingsPopover.close()
    } else {
        globalAISettingsPopover.show(
            relativeTo: sender.bounds,
            of: sender,
            preferredEdge: .maxY
        )
    }
}

func showProjectAISettings(for project: Project, relativeTo anchorView: NSView) {
    let vc = ProjectAISettingsViewController()
    vc.load(project: project)
    let popover = NSPopover()
    popover.behavior = .semitransient
    popover.contentViewController = vc
    popover.contentSize = ProjectAISettingsViewController.preferredSize
    popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .maxX)
}
```

---

### Step 7 — Storyboard

In `Main.storyboard`:

1. **Add `SidebarFooterView`** to the sidebar column (the first subview of `sidebarSplitView`):
   - Custom class: `SidebarFooterView`, module: `Nextpage`
   - Pin: `leading = sidebar.leading`, `trailing = sidebar.trailing`, `height = 32`, `bottom = sidebar.bottom`
   - Constrain `sidebarScrollView.bottom` to `sidebarFooterView.top` (remove existing bottom-to-superview constraint)
   - Connect `settingsButton.action` → `ViewController.openGlobalAISettings(_:)`
   - Connect `IBOutlet sidebarFooterView` on `ViewController`

2. **Add "AI Settings…" `NSMenuItem`** to the `storageOutlineView` context menu (or do it programmatically in Step 5 above — prefer code to avoid storyboard conflicts).

---

### Step 8 — Unit Tests

#### `NextpageTests/AIPromptSettingsTests.swift`

```swift
import XCTest
@testable import Nextpage

@MainActor
final class AIPromptSettingsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaultsManagement.globalAIPrompt = ""
    }

    func testGlobalPromptPersistence() {
        UserDefaultsManagement.globalAIPrompt = "You are a helpful journaling assistant."
        XCTAssertEqual(UserDefaultsManagement.globalAIPrompt, "You are a helpful journaling assistant.")
    }

    func testProjectPromptPersistenceViaSettings() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let project = Project(url: tempDir)
        project.aiPrompt = "Focus on my work notes."
        project.saveSettings()

        let reloaded = Project(url: tempDir)
        XCTAssertEqual(reloaded.aiPrompt, "Focus on my work notes.")
    }

    func testEffectivePromptFallsBackToGlobal() throws {
        UserDefaultsManagement.globalAIPrompt = "Global prompt"
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let project = Project(url: tempDir)
        project.aiPrompt = ""

        XCTAssertEqual(project.effectiveAIPrompt, "Global prompt")
    }

    func testEffectivePromptProjectOverridesGlobal() throws {
        UserDefaultsManagement.globalAIPrompt = "Global prompt"
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let project = Project(url: tempDir)
        project.aiPrompt = "Project-specific prompt"

        XCTAssertEqual(project.effectiveAIPrompt, "Project-specific prompt")
    }
}
```

---

## Manual Verification Checklist

### Global Prompt
- [ ] ⚙ gear button visible at the bottom of the sidebar
- [ ] Clicking gear opens popover with "Global AI Prompt" header and caption
- [ ] Typing a prompt and closing persists on reopen
- [ ] Prompt survives app quit + relaunch
- [ ] Button respects "Button Display: On Hover" preference

### Project Prompt
- [ ] Right-click on project folder shows "AI Settings…" menu item
- [ ] Menu item is hidden for Trash and the "Nextpage" (All) root item
- [ ] Popover shows project name in header
- [ ] Caption shows inherited global prompt preview when project field is empty
- [ ] Typed prompt persists after close and reopen
- [ ] Prompt survives app quit + relaunch

### Fallback Logic
- [ ] `project.effectiveAIPrompt` returns global when project prompt is empty
- [ ] `project.effectiveAIPrompt` returns project prompt when set

### Edge Cases
- [ ] Dark mode — both popovers look correct
- [ ] Sidebar at minimum width (138pt) — gear button still tappable
- [ ] Long global prompt — caption truncates with "…" at 60 chars

---

## Commit Plan

```
feat: add global AI prompt setting with gear button in sidebar footer
feat: add per-project AI prompt override via right-click context menu
feat: add effectiveAIPrompt with global fallback on Project
test: add AIPromptSettingsTests for prompt persistence and fallback
```
