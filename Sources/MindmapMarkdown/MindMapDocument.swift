import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let markdownText = UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)
}

/// A reference-type document: edits are visible immediately (a FileDocument binding defers
/// writes, so a read right after a write returns the old tree), and undo is explicit,
/// which lets "add topic + type its title" collapse into a single undo step.
final class MindMapDocument: ReferenceFileDocument {
    static var readableContentTypes: [UTType] { [.markdownText, .plainText] }
    static var writableContentTypes: [UTType] { [.markdownText] }

    @Published private(set) var root: MindNode

    init(root: MindNode = .sample) { self.root = root }

    required init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        else { throw CocoaError(.fileReadCorruptFile) }
        let name = configuration.file.filename.map { ($0 as NSString).deletingPathExtension } ?? "Central Idea"
        root = MarkdownCodec.parse(text, fallbackTitle: name)
    }

    func snapshot(contentType: UTType) throws -> MindNode { root }

    func fileWrapper(snapshot: MindNode, configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(MarkdownCodec.serialize(snapshot).utf8))
    }

    /// Applies an edit as one undoable step. Registering the undo is also what marks the
    /// document dirty, so autosave picks the change up.
    func apply(_ actionName: String, undo: UndoManager?, _ change: (inout MindNode) -> Void) {
        var next = root
        change(&next)
        guard next != root else { return }
        replace(with: next, actionName: actionName, undo: undo)
    }

    func replace(with next: MindNode, actionName: String, undo: UndoManager?) {
        let previous = root
        root = next
        undo?.registerUndo(withTarget: self) { doc in
            doc.replace(with: previous, actionName: actionName, undo: undo)
        }
        undo?.setActionName(actionName)
    }
}
