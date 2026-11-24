import SwiftUI

@main
struct MindmapMarkdownApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        DocumentGroup(newDocument: { MindMapDocument() }) { file in
            ContentView(document: file.document)
                .frame(minWidth: 720, minHeight: 480)
        }
        .defaultSize(width: 1240, height: 820)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Opening a .md from Finder at launch also makes SwiftUI create an empty "Untitled"
    /// document. Once launch settles, close it if a real file is open and it's untouched.
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            let docs = NSDocumentController.shared.documents
            guard docs.contains(where: { $0.fileURL != nil }) else { return }
            for doc in docs where doc.fileURL == nil && !doc.isDocumentEdited { doc.close() }
        }
    }
}
