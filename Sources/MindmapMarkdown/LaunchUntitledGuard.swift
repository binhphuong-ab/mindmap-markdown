import AppKit
import ObjectiveC

/// Stops the blank "Untitled" map from flashing when the app is launched to open a file
/// (Finder double-click, Open With…).
///
/// SwiftUI's DocumentGroup always makes an untitled document at launch, even when the
/// launch is for opening a file, and shows its window ~0.1 s before the real file's
/// window. Closing it afterwards still left a visible flash of two windows.
///
/// So while a "launch to open a file" is in progress, the window of an untouched
/// untitled document is never shown; its document is closed instead. SwiftUI owns the
/// app delegate and the document controller (replacing either crashes it), so this
/// hooks `NSWindow.makeKeyAndOrderFront(_:)`, the call SwiftUI uses to show it.
enum LaunchUntitledGuard {
    /// On between "launched to open a file" and the first real document showing up.
    static var isActive = false

    static func install() {
        guard let original = class_getInstanceMethod(NSWindow.self, #selector(NSWindow.makeKeyAndOrderFront(_:))),
              let replacement = class_getInstanceMethod(NSWindow.self, #selector(NSWindow.mm_makeKeyAndOrderFront(_:)))
        else { return }
        method_exchangeImplementations(original, replacement)
        // The notification, not the delegate method: SwiftUI forwards the delegate call
        // only after it has already shown the untitled window; the notification comes first.
        NotificationCenter.default.addObserver(forName: NSApplication.didFinishLaunchingNotification,
                                               object: nil, queue: nil) { didFinishLaunching($0) }
    }

    /// `launchIsDefault == false` means the launch was to open a file.
    private static func didFinishLaunching(_ notification: Notification) {
        let isDefault = notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool ?? true
        guard !isDefault else { return }
        isActive = true
        // Never leave it on: after launch, File ▸ New must show its window as usual.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { isActive = false }
    }
}

extension NSWindow {
    @objc fileprivate func mm_makeKeyAndOrderFront(_ sender: Any?) {
        if LaunchUntitledGuard.isActive,
           let doc = NSDocumentController.shared.document(for: self) {
            if doc.fileURL == nil, !doc.isDocumentEdited {
                // The extra blank map: close it instead of showing it.
                DispatchQueue.main.async { doc.close() }
                return
            }
            // A real file is showing: launch is done, stop guarding.
            if doc.fileURL != nil { LaunchUntitledGuard.isActive = false }
        }
        mm_makeKeyAndOrderFront(sender)   // swapped: calls the original
    }
}
