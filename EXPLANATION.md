# Nextpage: a newcomer’s guide

This guide explains the repository without assuming Swift or macOS-app experience. Read the sections in order the first time; use the folder map later as a reference.

## What this project is

Nextpage is a macOS desktop app for writing a journal in Markdown. A journal entry is a normal `.md` text file inside a folder the user chooses. That matters: the user owns the files, can read them in another editor, and does not need a cloud account or a database to use the app.

The app currently provides:

- folder and note navigation;
- create, edit, rename, and move-to-Trash flows;
- a live Markdown preview;
- autosaving that writes files atomically;
- detection of changes made outside the app; and
- permission handling for the journal folder.

The product is **local-first**. Do not add network requests, analytics, AI calls, or shell commands unless the feature has been explicitly approved.

## The important files at the root

| Path | What it is for |
| --- | --- |
| `Nextpage.xcodeproj` | The real macOS app project. Open this in Xcode to edit, run, and test the app. |
| `Package.swift` / `Package.resolved` | Lists Swift package dependencies used by Xcode. It is not a standalone Swift Package Manager app target (`targets` is intentionally empty). |
| `Info.plist` | Application metadata, including its bundle ID, display name, URL schemes, and macOS settings. |
| `Nextpage.entitlements` | macOS capabilities granted to the signed app. |
| `README.md` | Short product and build overview. |
| `AGENTS.md` | Repository rules for people and coding agents. Read it before changing code. |
| `CHANGELOG.md` / `HISTORY.md` | Current state and high-level milestones. |
| `LICENSE` | Nextpage’s MIT license. |
| `THIRD_PARTY_NOTICES.md` | Required notices for incorporated third-party code. |
| `IMPLEMENTATION.md` | A proposed AI-prompt-settings feature. It is a plan, not proof that the feature is implemented. |

`inspirations/MiaoYan/` is an ignored, read-only reference checkout. It is useful for comparison, but it is not part of the product and must not be edited or committed.

## How a macOS AppKit app fits together

Nextpage uses **AppKit**, Apple’s native macOS UI framework. In an AppKit app, the visible interface is built from several cooperating pieces:

```text
Main.storyboard / XIB
        │ creates views and connects outlets/actions
        ▼
Controllers
        │ coordinate user actions and application state
        ▼
Business + Helpers
        │ read/write notes, process Markdown, observe files
        ▼
User-selected journal folder
        │ contains the real .md files
        ▼
Views
        └── display the editor, note list, sidebar, preview, and feedback
```

- A **view** draws something or accepts direct interaction: for example, a text editor or sidebar row.
- A **controller** coordinates a user flow: for example, “the user selected this note, so load it into the editor.”
- The **business layer** holds rules and data objects: for example, how a note is represented and safely saved.
- **Resources** are non-Swift files such as the storyboard, localizations, images, and preview web assets.

The main interface is described in `Resources/Localization/Base.lproj/Main.storyboard`. Xcode uses the storyboard to construct objects and then connects them to Swift code through `IBOutlet` properties and `IBAction` methods.

## Folder map

### `Business/` — the journal’s rules and data

This folder is the best starting point for understanding what the app considers a note, project, sidebar item, or setting.

| File | Starting point |
| --- | --- |
| `Storage.swift` | Opens the selected journal location, scans notes, and makes persistence decisions. |
| `Note.swift` | Represents one Markdown note and its content/metadata. |
| `Project.swift` | Represents a project or journal location and its persisted settings. |
| `Markdown.swift` | Markdown-related business behavior. |
| `HtmlManager.swift` | Turns Markdown into HTML for the preview. |
| `WikilinkIndex.swift` | Indexes wiki-style links between notes. |
| `NoteVersionManager.swift` | Manages recoverable note versions. |
| `Sidebar.swift` / `SidebarItem.swift` | Builds the data shown in sidebar navigation. |
| `PrefsModel.swift` | Models preference sections and settings. |
| `FontCatalog.swift` / `FontConfiguration.swift` | Font choices and configuration. |

When changing anything that can lose a user’s writing, start here and add a test. Markdown files remain the source of truth; rendered HTML is only derived display data.

### `Controllers/` — application and user-flow coordination

`AppDelegate.swift` is the traditional AppKit application entry point. It receives application-level events. Its extension files separate lifecycle and URL-routing code.

`ViewController.swift` is the central controller for the main editing screen. Its extensions split a large responsibility into focused files:

- `ViewController+Data.swift`: loading and updating note data;
- `ViewController+Editor.swift`: editor and preview behavior;
- `ViewController+Layout.swift`: panes, layout, and visible state;
- `ViewController+Action.swift`: menu and user-triggered commands; and
- `ViewController+Export.swift`: export behavior.

Other controllers own smaller windows or preferences screens, such as `PrefsWindowController.swift`, `ProjectSettingsViewController.swift`, `VersionHistoryViewController.swift`, and `AboutWindowController.swift`.

### `Views/` — the actual interface pieces

This folder contains AppKit subclasses. Common landmarks are:

- `EditTextView.swift`: the Markdown editing surface;
- `MPreviewView.swift`: the HTML/Markdown preview, backed by a web view;
- `SidebarProjectView.swift` and `SidebarNotesView.swift`: project and note navigation;
- `EditorSplitView.swift` and `SidebarSplitView.swift`: resizable panes;
- `StorageView.swift`: the initial folder-selection experience;
- `Toast.swift`: short-lived status/error messages; and
- `TitleBarView.swift`: custom title-bar presentation.

Views should focus on rendering and direct interactions. A view should not quietly become the owner of filesystem rules or other application-wide state.

### `Helpers/` and `Extensions/` — focused shared support

Helpers are small services shared across features. Notable examples include:

- `FileWatcher.swift` and `FileSystemEventManager.swift` for external file changes;
- `UIDelay.swift` for debounced autosave timing;
- `UserDefaultsManagement.swift` for app preferences and security-scoped bookmarks;
- `CustomTextStorage.swift`, `CodeBlockHighlighter.swift`, and `MarkdownRuleHighlighter.swift` for editor text treatment;
- `ImagesProcessor.swift`, `ImageLinkParser.swift`, and `ImagePreviewManager.swift` for images;
- `PdfExportController.swift` and `SharingService.swift` for output/sharing; and
- `Theme.swift` and `Localization.swift` for visual and language consistency.

Files in `Extensions/` add a small capability to an existing Apple type. For example, `String+.swift` adds string utilities and `FileManager+.swift` adds file-management conveniences. Prefer an extension only when the capability naturally belongs to that existing type; otherwise use a helper or a business type.

### `Resources/` — interface files, languages, assets, and preview renderer

- `Localization/Base.lproj/` holds the base storyboard and XIB.
- The other `.lproj` folders contain Spanish, Japanese, Simplified Chinese, and Traditional Chinese strings.
- `Images.xcassets/` is Xcode’s image/color asset catalog.
- `Initial/Welcome.md` is initial user-facing Markdown content.
- `DownView.bundle/` is the bundled HTML, JavaScript, CSS, and presentation renderer used by preview. Treat it as a versioned bundle: edit it only intentionally and verify preview behavior afterward.

### `NextpageTests/` — automated checks

Tests use Apple’s XCTest framework. Test filenames identify the feature under test: `StorageInitContentDecisionTests.swift`, `NoteSaveDebounceTests.swift`, `HtmlManagerTests.swift`, `WikilinkIndexTests.swift`, and so on.

For a bug fix, add a small test that fails before the fix and passes afterward. Persistence, autosave, external edits, deletion recovery, and permission handling are especially important because mistakes can lose writing.

## A note’s lifecycle

This is the useful mental model for most feature work:

```text
User selects a journal folder
    → Storage obtains/uses permission and scans Markdown files
    → Sidebar and note list display discovered items
    → User selects a note
    → ViewController loads Note data into EditTextView
    → User types
    → debounce waits briefly so every keystroke is not a write
    → atomic save replaces the Markdown file safely
    → HtmlManager renders content for MPreviewView
    → File watcher notices outside changes and the app reconciles them
```

“Atomic save” means the app writes a complete replacement file and swaps it into place, rather than leaving a half-written file if saving is interrupted. If both the app and another program edit a note, the app should preserve recoverable copies instead of silently choosing one version.

## Swift vocabulary used in this repository

You do not need to learn all of Swift before making a small change. These terms cover most of what you will see:

| Swift term | Plain-English meaning |
| --- | --- |
| `struct` | A value-like data type, often used for small models or settings. |
| `class` | A reference-like type, common for AppKit views and controllers. |
| `enum` | A finite set of choices, optionally with associated data. |
| `protocol` | A contract describing methods/properties a type must provide. |
| `extension` | Adds behavior to an existing type in a separate file. |
| `optional` (`Type?`) | A value that may be missing. Handle it with `if let`, `guard let`, or `??`; do not force unwrap with `!` on persistence paths. |
| `guard` | Exits early when a required condition is not met, keeping the normal path readable. |
| `throws` / `try` | Swift’s explicit error-propagation system. File operations often use it. |
| closure | A small function passed to another function, similar to a callback. |
| `@MainActor` | Marks UI-affecting code as running on the main UI thread. |
| `async` / `await` | Modern Swift syntax for work that completes later without blocking the UI. |

Four spaces are used for indentation. Types use `UpperCamelCase`; methods and properties use `lowerCamelCase`.

## How to run the project

You need macOS and a full Xcode installation with the macOS SDK (not only Command Line Tools).

```bash
open Nextpage.xcodeproj
```

In Xcode, select the **Nextpage** scheme and press Run. To build or test from a terminal:

```bash
xcodebuild -project Nextpage.xcodeproj -scheme Nextpage \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO

xcodebuild test -project Nextpage.xcodeproj -scheme Nextpage \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

On first launch, select a disposable test folder rather than a real journal. The app may create `Welcome.md` only when that folder has no Markdown files.

## A safe first change

For a first code change, choose something visible and isolated, such as a label or small preference:

1. Find the text with `rg "exact text"`.
2. Identify whether it belongs in a localized strings file, a view, or a controller.
3. Make the smallest change that explains the desired behavior.
4. Add or update a focused XCTest if behavior—not just text—changed.
5. Run the narrowest relevant check, then the full test command.
6. Manually check source, preview, split view, keyboard navigation, dark mode, and relaunch after UI work.

For storage changes, work more cautiously: understand `Storage`, `Note`, autosave, and the file watcher before editing. Test a new folder, an existing note, a non-writable folder, an outside edit, and an interrupted/relaunched editing flow.

## Where to look for common questions

| Question | First places to inspect |
| --- | --- |
| “Where is a note saved?” | `Business/Storage.swift`, `Business/Note.swift` |
| “Why did the sidebar not update?” | `Business/Sidebar.swift`, `Views/SidebarProjectView.swift`, `Controllers/ViewController+Data.swift` |
| “How is Markdown preview rendered?” | `Business/HtmlManager.swift`, `Views/MPreviewView.swift`, `Resources/DownView.bundle/` |
| “How does autosave work?” | `Controllers/ViewController+Editor.swift`, `Helpers/UIDelay.swift`, relevant save-debounce tests |
| “How are outside file edits handled?” | `Helpers/FileWatcher.swift`, `Helpers/FileSystemEventManager.swift`, `Business/Storage.swift` |
| “Where is the layout defined?” | `Resources/Localization/Base.lproj/Main.storyboard`, `Controllers/ViewController+Layout.swift` |
| “Where do menu actions go?” | `Controllers/ViewController+Action.swift`, `Extensions/NSMenu+.swift` |
| “Where is a preference stored?” | `Helpers/UserDefaultsManagement.swift`, `Business/PrefsModel.swift`, preference controllers |

## Rules worth remembering

- Keep the user’s Markdown files portable and authoritative.
- Use atomic writes; never silently discard a divergent outside edit.
- Keep UI mutations on the main actor. Move slow filesystem scanning and Markdown work off the UI thread.
- Do not use force unwraps or silent `try?` around persistence.
- Localize user-visible text and preserve every supported language when changing strings.
- Do not edit the ignored inspiration checkout or vendored preview bundle casually.
- Read `AGENTS.md` before implementation; it contains the repository’s non-negotiable rules.

Once you can follow the note lifecycle and recognize the role of each top-level folder, the codebase becomes much easier to navigate. Start from the behavior you want to understand, then trace from a controller or view down into `Business/` rather than reading every Swift file in order.
