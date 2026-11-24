import AppKit
import SwiftUI

/// Keeps a document's file name equal to its central topic.
/// Saved file → renamed on disk (NSDocument.move, same as File ▸ Move To…).
/// Never-saved document → window title and the Save panel's suggested name.
enum FileNameSync {
    static func sanitized(_ title: String) -> String {
        var s = title.components(separatedBy: .newlines).joined(separator: " ")
        s = s.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        s = s.trimmingCharacters(in: .whitespaces)
        while s.hasPrefix(".") { s.removeFirst() }          // no hidden files
        return String(s.prefix(120)).trimmingCharacters(in: .whitespaces)
    }

    static func sync(window: NSWindow?, title: String) {
        guard let window, let doc = NSDocumentController.shared.document(for: window) else { return }
        let name = sanitized(title)
        guard !name.isEmpty else { return }

        guard let url = doc.fileURL else {
            doc.displayName = name
            doc.windowControllers.forEach { $0.synchronizeWindowTitleWithDocumentName() }
            return
        }
        guard url.deletingPathExtension().lastPathComponent != name else { return }
        let target = uniqueURL(for: name, next: url)
        doc.move(to: target) { error in
            if let error { NSLog("Mindmap Markdown: couldn't rename file: \(error.localizedDescription)") }
        }
    }

    /// "Name.md", or "Name 2.md", "Name 3.md"… if another file already has that name.
    /// A case-only change ("plan" → "Plan") points at the same file, so it's allowed as is.
    private static func uniqueURL(for name: String, next current: URL) -> URL {
        let dir = current.deletingLastPathComponent()
        let ext = current.pathExtension.isEmpty ? "md" : current.pathExtension
        var candidate = dir.appendingPathComponent(name).appendingPathExtension(ext)
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path),
              candidate.path.lowercased() != current.path.lowercased() {
            candidate = dir.appendingPathComponent("\(name) \(n)").appendingPathExtension(ext)
            n += 1
        }
        return candidate
    }
}

/// Reports the NSWindow hosting a SwiftUI view.
struct WindowReader: NSViewRepresentable {
    let onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView { Probe(onWindow) }
    func updateNSView(_ view: NSView, context: Context) {}

    private final class Probe: NSView {
        let onWindow: (NSWindow?) -> Void
        init(_ onWindow: @escaping (NSWindow?) -> Void) { self.onWindow = onWindow; super.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError() }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            let window = self.window
            DispatchQueue.main.async { self.onWindow(window) }
        }
    }
}
