# Repository Guidelines

## Project Structure & Module Organization

This repository will contain **Nextpage**, a local-first macOS Markdown journal. The production Xcode project should live at the repository root as `Nextpage.xcodeproj`. Organize Swift code by responsibility: `Business/` for storage and journal rules, `Controllers/` for AppKit coordination, `Views/` for UI components, `Helpers/` and `Extensions/` for focused utilities, `Resources/` for assets and localized strings, and `NextpageTests/` for XCTest coverage.

`inspirations/MiaoYan/` is an ignored, read-only reference checkout. Do not develop inside it or commit copied upstream branding, credentials, build output, or user journal data.

## Build, Test, and Development Commands

After the Nextpage target is scaffolded, use:

```bash
open Nextpage.xcodeproj
xcodebuild -project Nextpage.xcodeproj -scheme Nextpage -configuration Debug build
xcodebuild test -project Nextpage.xcodeproj -scheme Nextpage \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
swiftlint lint --strict
swift-format lint --recursive . --strict
```

Run the narrowest relevant check first, then the full test command before opening a pull request.

## Coding Style & Naming Conventions

Use Swift 6, four-space indentation, and Swift API Design Guidelines. Name types with `UpperCamelCase`, methods and properties with `lowerCamelCase`, and test files `<Subject>Tests.swift`. Keep UI mutations on `@MainActor`; move filesystem scanning and Markdown parsing off the main thread. Avoid force unwraps and silent `try?` on persistence paths. Preserve portable Markdown as the source of truth and use atomic writes for journal files.

## Testing Guidelines

Use XCTest for unit and regression tests. Cover date-to-path mapping, Markdown round-tripping, autosave flushing, external edits, conflict backups, deletion recovery, and folder-permission failures. Add a regression test with every data-loss fix. Manually verify source, preview, split view, keyboard navigation, dark mode, and relaunch behavior after UI changes.

## Commit & Pull Request Guidelines

Use concise Conventional Commit subjects, such as `feat: add daily entry creation` or `fix: preserve external journal edits`. Keep commits focused. Pull requests must explain the user-visible behavior, list validation performed, link relevant issues, and include before/after screenshots for UI changes.

## Security & Local-First Rules

Do not add network calls, analytics, secrets, or shell execution without an explicit feature decision. Scope file access to the user-selected journal directory, retain security-scoped bookmarks, and never silently discard divergent external edits.
