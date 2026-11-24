import SwiftUI
import AppKit

/// An AppKit text field, because SwiftUI's TextField always selects all text on focus.
/// "Type to replace" needs the caret placed after the first typed character instead.
struct EditorField: NSViewRepresentable {
    enum Finish { case commit, commitAndAddChild, cancel }

    @Binding var text: String
    let font: NSFont
    let alignment: NSTextAlignment
    let selectAll: Bool
    let onFinish: (Finish) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.font = font
        field.alignment = alignment
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.textColor = .labelColor
        field.placeholderString = "New idea"
        // Wrap instead of scrolling sideways; Return still commits (see doCommandBy).
        field.usesSingleLineMode = false
        field.cell?.isScrollable = false
        field.cell?.wraps = true
        field.lineBreakMode = .byWordWrapping
        field.maximumNumberOfLines = 0
        field.setContentHuggingPriority(.defaultLow, for: .vertical)
        field.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        field.delegate = context.coordinator
        focus(field, attempts: 5)
        return field
    }

    private func focus(_ field: NSTextField, attempts: Int) {
        DispatchQueue.main.async {
            guard let window = field.window else {
                if attempts > 0 { focus(field, attempts: attempts - 1) }
                return
            }
            window.makeFirstResponder(field)
            if !selectAll, let editor = field.currentEditor() {
                editor.selectedRange = NSRange(location: (field.stringValue as NSString).length, length: 0)
            }
        }
    }

    /// Take exactly the size the rename box proposes. Without this SwiftUI uses the field's
    /// intrinsic size, which is one line tall, and long text scrolls inside a thin strip.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSTextField, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 120, height: proposal.height ?? 20)
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text { field.stringValue = text }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: EditorField
        private var finished = false
        init(_ parent: EditorField) { self.parent = parent }

        func controlTextDidChange(_ note: Notification) {
            if let field = note.object as? NSTextField { parent.text = field.stringValue }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.insertNewline(_:)): finish(.commit)
            case #selector(NSResponder.insertTab(_:)): finish(.commitAndAddChild)
            case #selector(NSResponder.cancelOperation(_:)): finish(.cancel)
            default: return false
            }
            return true
        }

        // Clicking elsewhere also commits.
        func controlTextDidEndEditing(_ note: Notification) { finish(.commit) }

        private func finish(_ how: Finish) {
            guard !finished else { return }
            finished = true
            parent.onFinish(how)
        }
    }
}
