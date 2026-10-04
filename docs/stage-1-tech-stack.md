# Stage 1 Tech Stack

## Goal

Stage 1 is a dependable local Markdown desktop app for macOS. A user can choose a folder, navigate its Markdown files, create a file, read and render it, edit and save it, and move it to Trash. AI, Git sync, journal planning, and a database come after this foundation is stable.

## Decision

Build Nextpage as a thin fork of MiaoYan's macOS app rather than starting a new UI project. Keep the proven file and editor pipeline, remove unrelated product features, and add journal-specific behavior in later stages.

| Area | Choice | Reason |
| --- | --- | --- |
| Language | Swift 6 | Native macOS integration and matches the base project. |
| UI | AppKit with the existing storyboard | Reuses the three-pane sidebar, file list, editor, and preview. |
| Editor | `NSTextView` and `NSTextStorage` | Mature text editing, selection, undo, and keyboard support. |
| Preview | `WKWebView` | Renders styled HTML without replacing the editor buffer. |
| Markdown | `swift-cmark-gfm` | Supports CommonMark plus tables, task lists, strikethrough, and footnotes. |
| Storage | `FileManager`; one `.md` file per entry | Markdown remains portable and is the source of truth. |
| Folder access | `NSOpenPanel` plus a security-scoped bookmark | Lets a direct-download app reopen the chosen journal folder. |
| File changes | FSEvents through Nextpage's watcher | Keeps the list and editor in sync with Finder or Git edits. |
| Dependencies | Swift Package Manager | Already used by the base and built into Xcode. |
| Tests | XCTest | Covers storage and rendering rules without UI automation. |

Keep the deployment target at macOS 12 initially to minimize fork changes. Ship outside the Mac App Store during development.

## Stage 1 Product Scope

The main window retains three areas: folders, Markdown files, and an editor/preview pane. Stage 1 must support:

1. Choose and remember a local folder.
2. Discover `.md` files and navigate folders.
3. Create a Markdown file with a safe, unique name.
4. Open and edit UTF-8 Markdown with undo and redo.
5. Autosave after a short debounce and flush pending edits when switching files or quitting.
6. Render GitHub-flavored Markdown, including checklists.
7. Rename files without losing unsaved content.
8. Delete by moving files to Trash, with recovery through Finder.
9. Detect outside edits and avoid silently overwriting divergent content.
10. Restore the selected folder and file after relaunch.

## Modules to Retain from Nextpage

- `Business/Storage.swift` and `Business/Note.swift` for filesystem operations and safe saves.
- `Views/EditTextView.swift` for source editing.
- `Business/Markdown.swift` and `Views/MPreviewView.swift` for rendering.
- `Helpers/FileWatcher.swift` and `Helpers/FileSystemEventManager.swift` for external changes.
- The sidebar, note list, split view, and relevant XCTest coverage.

Remove cloud sync, mobile support, presentations, wikilinks, tags, encryption, image upload, export, auto-update, and AI integration from the Stage 1 build. Keep useful code in Git history rather than leaving disabled product paths in the app.

## Architecture Boundary

UI controllers may coordinate selection and presentation, but file rules live behind a small storage interface. Markdown text is authoritative; rendered HTML is derived and never saved over the source. All writes are atomic. A file that changed both in Nextpage and on disk must produce a recoverable conflict copy or require an explicit choice.

## Definition of Done

Stage 1 is complete when the create, open, edit, preview, navigate, rename, delete, relaunch, and external-edit flows work on a user-selected folder; storage tests pass; and a manual smoke test confirms that no tested action loses Markdown content.
