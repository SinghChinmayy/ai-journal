# Nextpage

Nextpage is a local-first Markdown journal for macOS. It keeps each note as a normal `.md` file in a folder you choose, so the journal remains readable and editable outside the app.

Stage 1 provides:

- folder and Markdown-file navigation;
- create, read, edit, rename, and delete flows;
- debounced atomic autosave with lifecycle flushing;
- GitHub-flavored Markdown preview, including task lists;
- external file-change detection and recoverable conflicts;
- security-scoped access to the selected journal folder.

AI-assisted journaling and Git synchronization are planned later. The current app makes no AI or sync requests.

## Requirements

- macOS 12 or later
- Xcode 16 or later with the macOS SDK

## Development

```bash
open Nextpage.xcodeproj
xcodebuild -project Nextpage.xcodeproj -scheme Nextpage \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
xcodebuild test -project Nextpage.xcodeproj -scheme Nextpage \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

The first launch asks for a journal folder. Nextpage stores permission to reopen that folder and creates a small `Welcome.md` only when the selected folder contains no Markdown files.

## License

Nextpage is licensed under the [MIT License](LICENSE), copyright © 2026 Chinmay Singh.