import AppKit

/// Hides the window's whole top bar (traffic lights, title, toolbar) so the map gets the full
/// window. Moving the mouse into the top strip reveals it; it hides again once the mouse has
/// been away from that strip for `hideDelay` seconds.
final class ChromeAutoHider {
    static let revealZone: CGFloat = 56      // ≈ height of the title bar + toolbar
    static let hideDelay: TimeInterval = 5

    var enabled = true {
        didSet {
            guard enabled != oldValue else { return }
            if enabled { armHideTimer() } else { hideTimer?.invalidate(); setVisible(true) }
        }
    }
    private(set) var visible = true

    private weak var window: NSWindow?
    private var monitor: Any?
    private var hideTimer: Timer?

    func attach(to window: NSWindow) {
        guard self.window !== window else { return }
        self.window = window
        // Let the canvas run underneath the bar, so showing/hiding it never shifts the map.
        window.styleMask.insert(.fullSizeContentView)
        window.acceptsMouseMovedEvents = true
        if monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
                self?.handle(event)
                return event
            }
        }
        setVisible(true, animated: false)
        if enabled { armHideTimer() }   // start visible so the controls are discoverable
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
        hideTimer?.invalidate()
    }

    private func handle(_ event: NSEvent) {
        guard enabled, let window, event.window === window else { return }
        if event.locationInWindow.y >= window.frame.height - Self.revealZone {
            setVisible(true)
            armHideTimer()                // restart the countdown on every move in the strip
        }
    }

    private func armHideTimer() {
        hideTimer?.invalidate()
        // Default run-loop mode on purpose: it doesn't fire while a menu (e.g. the Style menu)
        // is open, so the bar never vanishes from under an open menu.
        hideTimer = Timer.scheduledTimer(withTimeInterval: Self.hideDelay, repeats: false) { [weak self] _ in
            self?.hideIfMouseAway()
        }
    }

    private func hideIfMouseAway() {
        guard enabled, let window else { return }
        if window.styleMask.contains(.fullScreen) { return }   // macOS handles the bar in full screen
        if window.attachedSheet != nil || mouseInZone(window) { armHideTimer(); return }
        setVisible(false)
    }

    private func mouseInZone(_ window: NSWindow) -> Bool {
        let p = NSEvent.mouseLocation
        let f = window.frame
        return f.contains(p) && p.y >= f.maxY - Self.revealZone
    }

    /// The title-bar container holds the traffic lights, title and toolbar. Fading it as a
    /// single layer looks smooth, and SwiftUI's toolbar is never touched, so SwiftUI has no
    /// reason to re-apply its title settings halfway through (which caused the title flash).
    private var titlebarContainer: NSView? {
        window?.standardWindowButton(.closeButton)?.superview?.superview
    }

    private func setVisible(_ show: Bool, animated: Bool = true) {
        guard let bar = titlebarContainer else { return }
        visible = show
        if show {
            bar.isHidden = false
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = animated ? 0.18 : 0
                bar.animator().alphaValue = 1
            }
        } else {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = animated ? 0.25 : 0
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                bar.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                // Once invisible, take it out of hit-testing so clicks reach the map.
                guard let self, !self.visible else { return }   // revealed again mid-fade
                bar.isHidden = true
            })
        }
    }
}
