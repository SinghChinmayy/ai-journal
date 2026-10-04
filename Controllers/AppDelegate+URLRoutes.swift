import Cocoa
import Foundation

extension AppDelegate {
    enum HandledSchemes: String {
        case nextpage
        case nv
        case nvALT = "nvalt"
        case file
    }
    enum NextpageRoutes: String {
        case find
        case new
        case goto
    }
    enum NvALTRoutes: String {
        case find
        case blank = ""
        case make
        case goto
    }

    @MainActor
    func application(_ application: NSApplication, open urls: [URL]) {
        guard var url = urls.first,
            let scheme = url.scheme
        else { return }
        let path = url.absoluteString.escapePlus()
        if let escaped = URL(string: path) {
            url = escaped
        }
        switch scheme {
        case HandledSchemes.file.rawValue:
            if ViewController.shared() != nil {
                openNotes(urls: urls)
            } else {
                self.urls = urls
            }
        case HandledSchemes.nextpage.rawValue:
            NextpageRouter(url)
        case HandledSchemes.nv.rawValue,
            HandledSchemes.nvALT.rawValue:
            NvALTRouter(url)
        default:
            break
        }
    }

    @MainActor
    func openNotes(urls: [URL]) {
        guard let vc = ViewController.shared() else { return }
        let fileURL = urls[0]
        UserDefaultsManagement.beginSingleMode(for: fileURL)

        if let mwc = mainWindowController,
            mwc.window?.isVisible != true
        {
            mwc.makeNew()
        }

        // Pre-enumerate sibling files while sandbox implicit access is active.
        // In the App Store build, the sandbox extension from application:open:
        // grants access to the parent directory only during this call scope.
        var siblingFiles: [URL]?
        if !FileManager.default.directoryExists(atUrl: fileURL) {
            let parentDir = fileURL.deletingLastPathComponent()
            let extensions = Storage.sharedInstance().allowedExtensions
            if let contents = try? FileManager.default.contentsOfDirectory(
                at: parentDir,
                includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey],
                options: .skipsHiddenFiles)
            {
                siblingFiles = contents.filter { extensions.contains($0.pathExtension.lowercased()) }
            }
        }

        vc.reloadForSingleMode(originalFileURL: fileURL, siblingFiles: siblingFiles)
    }

    @MainActor
    func importNotes(urls: [URL]) {
        guard let vc = ViewController.shared() else { return }
        var importedNote: Note?
        var sidebarIndex: Int?
        for url in urls {
            if let items = vc.storageOutlineView.sidebarItems, let note = Storage.sharedInstance().getBy(url: url) {
                if let sidebarItem = items.first(where: { ($0 as? SidebarItem)?.project == note.project }) {
                    sidebarIndex = vc.storageOutlineView.row(forItem: sidebarItem)
                    importedNote = note
                }
            } else {
                let project = Storage.sharedInstance().getMainProject()
                let newUrl = vc.copy(project: project, url: url)
                UserDataService.instance.focusOnImport = newUrl
                UserDataService.instance.skipSidebarSelection = true
            }
        }
        if let note = importedNote, let si = sidebarIndex {
            vc.storageOutlineView.selectRowIndexes([si], byExtendingSelection: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                vc.notesTableView.setSelected(note: note)
            }
        }
    }
    // MARK: - Nextpage routes
    @MainActor
    func NextpageRouter(_ url: URL) {
        guard let directive = url.host else { return }
        switch directive {
        case NextpageRoutes.find.rawValue:
            RouteNextpageFind(url)
        case NextpageRoutes.new.rawValue:
            RouteNextpageNew(url)
        case NextpageRoutes.goto.rawValue:
            RouteNextpageGoto(url)
        default:
            break
        }
    }
    /// Handles URLs with the path /find/searchstring1%20searchstring2
    @MainActor
    func RouteNextpageFind(_ url: URL) {
        let lastPath = url.lastPathComponent
        guard ViewController.shared() != nil else {
            searchQuery = lastPath
            return
        }
        search(query: lastPath)
    }

    @MainActor
    func RouteNextpageGoto(_ url: URL) {
        let query = url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
        guard let vc = ViewController.shared() else { return }
        let notes = vc.storage.noteList.filter { $0.title == query }
        if notes.count > 1 {
            vc.updateTable {
                DispatchQueue.main.async {
                    vc.storageOutlineView.selectRowIndexes([0], byExtendingSelection: false)
                    self.RouteNextpageFind(url)
                    vc.toastMoreTitle()
                }
            }
        } else if notes.count == 1 {
            if let items = vc.storageOutlineView.sidebarItems {
                // Handle the scenario where the note sits in the root project
                var sidebarIndex = 0
                if let sidebarItem = items.first(where: { ($0 as? SidebarItem)?.project == notes[0].project }) {
                    sidebarIndex = vc.storageOutlineView.row(forItem: sidebarItem)
                }
                vc.updateTable {
                    DispatchQueue.main.async {
                        vc.storageOutlineView.selectRowIndexes([sidebarIndex], byExtendingSelection: false)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                            if let index = vc.notesTableView.noteList.firstIndex(where: { $0 === notes[0] }) {
                                vc.notesTableView.selectRowIndexes([index], byExtendingSelection: false)
                                vc.notesTableView.scrollRowToVisible(row: index, animated: false)
                            }
                        }
                    }
                }
            }
        } else {
            vc.toastNoTitle()
        }
    }

    @MainActor
    func search(query: String) {
        guard let controller = ViewController.shared() else { return }
        controller.search.stringValue = query
        controller.updateTable(search: true, searchText: query) {
            if let note = controller.notesTableView.noteList.first {
                DispatchQueue.main.async {
                    controller.search.suggestAutocomplete(note, filter: query)
                }
            }
        }
    }
    /// Handles URLs with the following paths:
    ///   - nextpage://make/?title=URI-escaped-title&html=URI-escaped-HTML-data
    ///   - nextpage://make/?title=URI-escaped-title&txt=URI-escaped-plain-text
    ///   - nextpage://make/?txt=URI-escaped-plain-text
    ///
    /// The three possible parameters (title, txt, html) are all optional.
    ///
    @MainActor
    func RouteNextpageNew(_ url: URL) {
        var title = ""
        var body = ""
        if let titleParam = url["title"] {
            title = titleParam
        }
        if let txtParam = url["txt"] {
            body = txtParam
        } else if let htmlParam = url["html"] {
            body = htmlParam
        }
        guard ViewController.shared() != nil else {
            newName = title
            newContent = body
            return
        }
        create(name: title, content: body)
    }

    @MainActor
    func create(name: String, content: String) {
        guard let controller = ViewController.shared() else { return }
        controller.createNote(name: name, content: content)
    }
    // MARK: - nvALT routes, for compatibility
    @MainActor
    func NvALTRouter(_ url: URL) {
        guard let directive = url.host else { return }
        switch directive {
        case NvALTRoutes.find.rawValue:
            RouteNvAltFind(url)
        case NvALTRoutes.make.rawValue:
            RouteNvAltMake(url)
        case NvALTRoutes.goto.rawValue:
            RouteNvAltGoto(url)
        default:
            RouteNvAltBlank(url)
        }
    }
    /// Handle URLs in the format nv://find/searchstring1%20searchstring2
    ///
    /// Note: this route is identical to the corresponding Nextpage route.
    ///
    @MainActor
    func RouteNvAltFind(_ url: URL) {
        RouteNextpageFind(url)
    }

    @MainActor
    func RouteNvAltGoto(_ url: URL) {
        RouteNextpageGoto(url)
    }
    /// Handle URLs in the format nv://note%20title
    ///
    /// Note: this route is an alias to the /find route above.
    ///
    @MainActor
    func RouteNvAltBlank(_ url: URL) {
        let pathWithFind = url.absoluteString.replacingOccurrences(of: "://", with: "://find/")
        guard let newURL = URL(string: pathWithFind) else { return }
        RouteNextpageFind(newURL)
    }
    /// Handle URLs in the format:
    ///
    ///   - nv://make/?title=URI-escaped-title&html=URI-escaped-HTML-data&tags=URI-escaped-tag-string
    ///   - nv://make/?title=URI-escaped-title&txt=URI-escaped-plain-text
    ///   - nv://make/?txt=URI-escaped-plain-text
    ///
    /// The four possible parameters (title, txt, html and tags) are all optional.
    ///
    @MainActor
    func RouteNvAltMake(_ url: URL) {
        var title = ""
        var body = ""
        if let titleParam = url["title"] {
            title = titleParam
        }
        if let txtParam = url["txt"] {
            body = txtParam
        } else if let htmlParam = url["html"] {
            body = htmlParam
        }
        if let tagsParam = url["tags"] {
            body = body.appending("\n\nnvALT tags: \(tagsParam)")
        }
        guard let controller = ViewController.shared() else { return }
        controller.createNote(name: title, content: body)
    }
}
