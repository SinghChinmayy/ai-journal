import Cocoa

@MainActor
class ClipboardManager {
    private weak var textView: EditTextView?

    init(textView: EditTextView) {
        self.textView = textView
    }

    func handleCopy() -> Bool {
        guard let textView = textView else { return false }

        if textView.selectedRanges.count > 1 {
            let combined = String()
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
            pasteboard.setString(combined.trim().removeLastNewLine(), forType: NSPasteboard.PasteboardType.string)
            return true
        }

        if textView.selectedRange.length == 0,
            let paragraphRange = textView.getParagraphRange(),
            let paragraph = textView.attributedSubstring(forProposedRange: paragraphRange, actualRange: nil)
        {
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
            pasteboard.setString(paragraph.string.trim().removeLastNewLine(), forType: NSPasteboard.PasteboardType.string)
            return true
        }

        return false
    }

    func handlePaste(in note: Note) -> Bool {
        guard let textView = textView else { return false }

        let pasteboard = NSPasteboard.general
        if pasteboard.string(forType: NSPasteboard.PasteboardType.fileURL) == nil {
            // Rich text copied from a browser (AI answers, docs pages) arrives as
            // HTML; convert to markdown when it carries block structure. Editor
            // syntax-highlight HTML has no such tags, so code paste stays plain.
            var content = pasteboard.string(forType: NSPasteboard.PasteboardType.string)
            if let html = pasteboard.string(forType: NSPasteboard.PasteboardType.html),
                let markdown = HtmlToMarkdown.convertIfStructured(html)
            {
                content = markdown
            }

            if let content = content {
                EditTextView.shouldForceRescan = true
                let currentRange = textView.selectedRange()
                textView.breakUndoCoalescing()
                textView.insertText(content, replacementRange: currentRange)
                textView.saveTextStorageContent(to: note)
                note.save()
                textView.fillHighlightLinks()
                return true
            }
        }

        return pasteImageFromClipboard(in: note)
    }

    private func pasteImageFromClipboard(in note: Note) -> Bool {
        guard let textView = textView else { return false }

        if let url = NSURL(from: NSPasteboard.general) {
            if !url.isFileURL {
                return false
            }
            return saveFile(url: url as URL, in: note)
        }

        if let clipboard = NSPasteboard.general.data(forType: .tiff),
            let image = NSImage(data: clipboard),
            let jpgData = image.jpgData
        {

            EditTextView.shouldForceRescan = true
            saveClipboard(data: jpgData, note: note)
            textView.saveTextStorageContent(to: note)
            note.save()
            textView.textStorage?.sizeAttachmentImages()
            return true
        }

        return false
    }

    func saveFile(url: URL, in note: Note) -> Bool {
        guard let textView = textView else { return false }

        if let data = try? Data(contentsOf: url) {
            var ext: String?

            if NSImage(data: data) != nil {
                ext = "jpg"
                if let source = CGImageSourceCreateWithData(data as CFData, nil) {
                    let uti = CGImageSourceGetType(source)
                    if let fileExtension = (uti as String?)?.utiFileExtension {
                        ext = fileExtension
                    }
                }
            }

            EditTextView.shouldForceRescan = true
            saveClipboard(data: data, note: note, ext: ext, url: url)
            textView.saveTextStorageContent(to: note)
            note.save()
            textView.textStorage?.sizeAttachmentImages()
            return true
        }

        return false
    }

    private func saveClipboard(data: Data, note: Note, ext: String? = nil, url: URL? = nil) {
        guard let textView else { return }

        if let path = ImagesProcessor.writeFile(data: data, url: url, note: note, ext: ext) {
            textView.breakUndoCoalescing()
            textView.insertText(
                NSAttributedString(string: "![](\(path))"),
                replacementRange: textView.selectedRange()
            )
        }
    }
}
