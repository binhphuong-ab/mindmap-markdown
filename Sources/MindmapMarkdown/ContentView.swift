import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var document: MindMapDocument
    @Environment(\.undoManager) private var undoManager

    @AppStorage("theme") private var themeID = Theme.aurora.id
    @AppStorage("layoutStyle") private var styleRaw = LayoutStyle.balanced.rawValue
    @AppStorage("showHints") private var showHints = true
    @AppStorage("nameFileAfterRoot") private var nameFileAfterRoot = true
    @AppStorage("autoHideToolbar") private var autoHideToolbar = true

    @StateObject private var ui = EditorUIState()
    @FocusState private var canvasFocused: Bool

    private var theme: Theme { Theme.named(themeID) }
    private var style: LayoutStyle { LayoutStyle(rawValue: styleRaw) ?? .balanced }
    private var root: MindNode { document.root }
    private func currentLayout() -> MindLayout { MindLayout(root: root, style: style) }

    var body: some View {
        let layout = currentLayout()
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    mapStack(layout)
                        .frame(width: layout.size.width * ui.zoom, height: layout.size.height * ui.zoom,
                               alignment: .topLeading)
                        .overlay(alignment: .topLeading) { scrollAnchors(layout) }
                        .frame(minWidth: geo.size.width, minHeight: geo.size.height)
                        .background {
                            Color.clear.contentShape(Rectangle()).onTapGesture {
                                ui.selection = nil
                                canvasFocused = true
                            }
                        }
                }
                .scrollIndicators(.automatic)
                .onAppear {
                    ui.viewport = geo.size
                    ui.selection = root.id
                    canvasFocused = true
                    DispatchQueue.main.async { proxy.scrollTo(anchorID(root.id), anchor: .center) }
                }
                .onChange(of: geo.size) { _, size in ui.viewport = size }
                // Keep the rename box on screen while it grows.
                .onChange(of: ui.editText) { _, _ in
                    if ui.editing != nil { proxy.scrollTo(editorAnchorID) }
                }
                .onChange(of: ui.editing) { _, id in
                    if id != nil { DispatchQueue.main.async { proxy.scrollTo(editorAnchorID) } }
                }
                .onChange(of: ui.selection) { _, id in
                    guard let id, ui.drag == nil else { return }
                    withAnimation(.easeOut(duration: 0.18)) { proxy.scrollTo(anchorID(id)) }
                }
            }
        }
        .ignoresSafeArea(.container, edges: .top)   // map runs under the (auto-hiding) top bar
        .background(LinearGradient(colors: theme.background, startPoint: .top, endPoint: .bottom))
        .overlay(alignment: .bottom) { if showHints { hintBar } }
        .focusable()
        .focused($canvasFocused)
        .focusEffectDisabled()
        .onKeyPress(phases: .down, action: handleKey)
        // SwiftUI's Edit ▸ Delete menu item owns the ⌫ key, so it never reaches onKeyPress.
        .onDeleteCommand { if ui.editing == nil { deleteSelected() } }
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    if ui.pinchBase == nil { ui.pinchBase = ui.zoom }
                    ui.zoom = clampZoom(ui.pinchBase! * value.magnification)
                }
                .onEnded { _ in ui.pinchBase = nil })
        .toolbar { toolbar }
        .inspector(isPresented: $ui.showSource) {
            SourcePanel(markdown: MarkdownCodec.serialize(root))
                .inspectorColumnWidth(min: 240, ideal: 320, max: 560)
        }
        .background(WindowReader { window in
            ui.window = window
            if let window {
                ui.chrome.enabled = autoHideToolbar
                ui.chrome.attach(to: window)
            }
            if nameFileAfterRoot, NSDocumentController.shared.document(for: window ?? NSWindow())?.fileURL == nil {
                FileNameSync.sync(window: window, title: root.title)   // new map: title it after the root
            }
        })
        .onChange(of: autoHideToolbar) { _, on in ui.chrome.enabled = on }
        .onChange(of: root.title) { _, title in
            if nameFileAfterRoot { FileNameSync.sync(window: ui.window, title: title) }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: root)
        .animation(.easeInOut(duration: 0.25), value: styleRaw)
    }

    // MARK: Map

    private func mapStack(_ layout: MindLayout) -> some View {
        ZStack(alignment: .topLeading) {
            MapCanvas(layout: layout, theme: theme, selection: ui.selection, editing: ui.editing,
                      dropTarget: ui.dropTarget, drag: ui.drag, actions: actions(layout))
            if let id = ui.editing, let node = layout[id] {
                editor(for: node)
            }
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
        .coordinateSpace(name: "map")
        .scaleEffect(ui.zoom, anchor: .topLeading)
        .environment(\.colorScheme, theme.isDark ? .dark : .light)   // editor matches the canvas
    }

    /// Invisible views at *scaled* positions so ScrollViewReader can keep the selection on screen.
    private func scrollAnchors(_ layout: MindLayout) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(layout.nodes) { n in
                Color.clear
                    .frame(width: n.frame.width * ui.zoom + 60, height: n.frame.height * ui.zoom + 60)
                    .id(anchorID(n.id))
                    .position(x: n.frame.midX * ui.zoom, y: n.frame.midY * ui.zoom)
            }
        }
        .overlay(alignment: .topLeading) {
            if let id = ui.editing, let node = layout[id] {
                let f = editorGeometry(for: node).frame.insetBy(dx: -24, dy: -24)
                Color.clear
                    .frame(width: f.width * ui.zoom, height: f.height * ui.zoom)
                    .id(editorAnchorID)
                    .position(x: f.midX * ui.zoom, y: f.midY * ui.zoom)
            }
        }
        .frame(width: layout.size.width * ui.zoom, height: layout.size.height * ui.zoom, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private func anchorID(_ id: UUID) -> String { "anchor-\(id.uuidString)" }
    private let editorAnchorID = "editor-anchor"

    /// The rename box wraps at the same width the topic wraps at once committed, and grows
    /// downward line by line instead of running sideways off the canvas.
    private func editorGeometry(for node: LaidOutNode) -> (frame: CGRect, field: CGSize) {
        let natural = TextMeasure.size(ui.editText, depth: node.depth, maxWidth: 4000).width
        let wrapWidth = max(min(natural, NodeStyle.maxTextWidth), 90)
        let textHeight = TextMeasure.size(ui.editText.isEmpty ? "Ag" : ui.editText,
                                          depth: node.depth, maxWidth: wrapWidth).height
        let field = CGSize(width: wrapWidth + 8,          // + NSTextField's line-fragment padding
                           height: textHeight + 2)
        let width = max(field.width + 20, node.frame.width + 8)
        let height = max(field.height + 14, node.frame.height + 6)
        let x: CGFloat = node.side > 0 ? node.frame.minX - 4
            : node.side < 0 ? node.frame.maxX + 4 - width : node.frame.midX - width / 2
        return (CGRect(x: x, y: node.frame.midY - height / 2, width: width, height: height), field)
    }

    private func editor(for node: LaidOutNode) -> some View {
        let g = editorGeometry(for: node)
        return EditorField(text: $ui.editText, font: NodeStyle.font(node.depth),
                           alignment: node.depth <= 1 ? .center : .left,
                           selectAll: ui.editSelectAll, onFinish: finishEditing)
            .frame(width: g.field.width, height: g.field.height)
            .frame(width: g.frame.width, height: g.frame.height)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 4))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(theme.accent, lineWidth: 2))
            .position(x: g.frame.midX, y: g.frame.midY)
            .id(node.id)   // fresh field (and focus) per edited node
    }

    private func actions(_ layout: MindLayout) -> MapActions {
        MapActions(
            select: { id in ui.selection = id; canvasFocused = true },
            edit: { id in startEditing(id) },
            toggleFold: { id in ui.selection = id; toggleFold(id); canvasFocused = true },
            dragChanged: { id, offset, location in
                ui.drag = DragState(id: id, offset: offset)
                ui.dropTarget = dropCandidate(at: location, dragging: id, layout: layout)
            },
            dragEnded: { id, location in
                if let target = dropCandidate(at: location, dragging: id, layout: layout) {
                    document.apply("Move Topic", undo: undoManager) { _ = $0.reparent(id, under: target) }
                }
                ui.drag = nil
                ui.dropTarget = nil
                ui.selection = id
            })
    }

    private func dropCandidate(at p: CGPoint, dragging id: UUID, layout: MindLayout) -> UUID? {
        guard let dragged = root.find(id) else { return nil }
        return layout.nodes.first { n in
            n.id != id && n.frame.insetBy(dx: -8, dy: -8).contains(p)
                && dragged.find(n.id) == nil && root.parentID(of: id) != n.id
        }?.id
    }

    // MARK: Editing

    private func startEditing(_ id: UUID, text: String? = nil, isNew: Bool = false) {
        guard let node = root.find(id) else { return }
        ui.selection = id
        ui.editText = text ?? node.title
        ui.editSelectAll = text == nil
        ui.editIsNew = isNew
        ui.editing = id
        canvasFocused = false          // hand first responder to the text field
    }

    private func finishEditing(_ how: EditorField.Finish) {
        guard let id = ui.editing else { return }
        let text = ui.editText.trimmingCharacters(in: .whitespacesAndNewlines)
        let wasNew = ui.editIsNew
        ui.editing = nil
        ui.editIsNew = false
        defer { canvasFocused = true }

        if wasNew {
            // Fold "add topic" and "name it" into one undo step: roll back the add,
            // then re-apply the finished result (or nothing, if it was cancelled/left empty).
            var final = root
            final.update(id) { $0.title = text }
            let parent = root.parentID(of: id)
            if undoManager?.canUndo == true { undoManager?.undo() }
            if how == .cancel || text.isEmpty {
                if root.find(id) != nil {   // no undo manager: remove by hand
                    document.apply("Delete Topic", undo: undoManager) { _ = $0.remove(id) }
                }
                ui.selection = parent ?? root.id
                return
            }
            document.replace(with: final, actionName: "Add Topic", undo: undoManager)
        } else if how != .cancel, !text.isEmpty {
            document.apply("Rename Topic", undo: undoManager) { $0.update(id) { $0.title = text } }
        }
        // Next run-loop turn, so the new child's undo isn't grouped with this commit.
        if how == .commitAndAddChild { DispatchQueue.main.async { addChild() } }
    }

    private func addChild() {
        var newID: UUID?
        document.apply("Add Topic", undo: undoManager) { newID = $0.addChild(to: ui.selection ?? $0.id) }
        if let newID { startEditing(newID, text: "", isNew: true) }
    }

    private func addSibling() {
        var newID: UUID?
        document.apply("Add Topic", undo: undoManager) { newID = $0.addSibling(after: ui.selection ?? $0.id) }
        if let newID { startEditing(newID, text: "", isNew: true) }
    }

    private func deleteSelected() {
        guard let id = ui.selection, id != root.id else { NSSound.beep(); return }
        var next: UUID?
        document.apply("Delete Topic", undo: undoManager) { next = $0.remove(id) }
        ui.selection = next
    }

    private func toggleFold(_ id: UUID?) {
        guard let id, let node = root.find(id), !node.children.isEmpty else { return }
        document.apply(node.collapsed ? "Expand" : "Collapse", undo: undoManager) { $0.update(id) { $0.collapsed.toggle() } }
    }

    private func moveSelected(_ offset: Int) {
        guard let id = ui.selection else { return }
        document.apply("Move Topic", undo: undoManager) { $0.move(id, by: offset) }
    }

    // MARK: Keyboard

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        guard ui.editing == nil else { return .ignored }
        let mods = press.modifiers
        let cmd = mods.contains(.command)

        switch press.key {
        case .tab where mods.isEmpty: addChild(); return .handled
        case .return where mods.isEmpty: addSibling(); return .handled
        case .delete, .deleteForward: deleteSelected(); return .handled
        case .space where mods.isEmpty: toggleFold(ui.selection); return .handled
        case .escape: ui.selection = nil; return .handled
        case .upArrow: cmd ? moveSelected(-1) : navigateVertical(-1); return .handled
        case .downArrow: cmd ? moveSelected(1) : navigateVertical(1); return .handled
        case .leftArrow: navigateHorizontal(-1); return .handled
        case .rightArrow: navigateHorizontal(1); return .handled
        default: break
        }

        if cmd {
            switch press.characters {
            case "=", "+": ui.zoom = clampZoom(ui.zoom * 1.2)
            case "-": ui.zoom = clampZoom(ui.zoom / 1.2)
            case "0": ui.zoom = 1
            case "9": zoomToFit()
            default: return .ignored
            }
            return .handled
        }

        if press.characters == "\u{F705}", let id = ui.selection { startEditing(id); return .handled } // F2

        // Typing a printable character starts editing and replaces the title, like a spreadsheet cell.
        if let id = ui.selection, mods.isDisjoint(with: [.control, .option]),
           let scalar = press.characters.unicodeScalars.first,
           !CharacterSet.controlCharacters.contains(scalar),
           !(0xF700...0xF8FF).contains(scalar.value) {
            startEditing(id, text: press.characters)
            return .handled
        }
        return .ignored
    }

    private func navigateHorizontal(_ dir: CGFloat) {
        let layout = currentLayout()
        guard let cur = layout[ui.selection] else { ui.selection = root.id; return }
        func nearestChild(of id: UUID, in l: MindLayout) -> UUID? {
            l.nodes.filter { $0.parent == id && (cur.depth != 0 || $0.side == dir) }
                .min { abs($0.frame.midY - cur.frame.midY) < abs($1.frame.midY - cur.frame.midY) }?.id
        }
        if cur.depth == 0 || cur.side == dir {
            if cur.hiddenCount > 0 {           // stepping into a folded branch unfolds it
                toggleFold(cur.id)
                ui.selection = nearestChild(of: cur.id, in: currentLayout()) ?? cur.id
            } else if let next = nearestChild(of: cur.id, in: layout) {
                ui.selection = next
            }
        } else {
            ui.selection = cur.parent
        }
    }

    private func navigateVertical(_ dir: CGFloat) {
        let layout = currentLayout()
        guard let cur = layout[ui.selection] else { ui.selection = root.id; return }
        guard cur.depth > 0 else { return }
        let siblings = layout.nodes.filter { $0.parent == cur.parent && $0.side == cur.side }
            .sorted { $0.frame.midY < $1.frame.midY }
        if let i = siblings.firstIndex(where: { $0.id == cur.id }), siblings.indices.contains(i + Int(dir)) {
            ui.selection = siblings[i + Int(dir)].id
            return
        }
        // No sibling that way: jump to the visually nearest topic on the same side.
        let candidates = layout.nodes.filter {
            $0.side == cur.side && $0.id != cur.id && ($0.frame.midY - cur.frame.midY) * dir > 1
        }
        if let best = candidates.min(by: { score($0, cur) < score($1, cur) }) { ui.selection = best.id }
    }

    private func score(_ n: LaidOutNode, _ cur: LaidOutNode) -> CGFloat {
        abs(n.frame.midY - cur.frame.midY) + 2 * abs(n.frame.midX - cur.frame.midX)
    }

    // MARK: Zoom & export

    private func clampZoom(_ z: CGFloat) -> CGFloat { min(max(z, 0.25), 3) }

    private func zoomToFit() {
        let size = currentLayout().size
        guard size.width > 0, ui.viewport.width > 0 else { return }
        ui.zoom = clampZoom(min((ui.viewport.width - 20) / size.width, (ui.viewport.height - 20) / size.height, 1.5))
    }

    @MainActor private func exportPNG() {
        let layout = currentLayout()
        let content = MapCanvas(layout: layout, theme: theme)
            .background(LinearGradient(colors: theme.background, startPoint: .top, endPoint: .bottom))
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let cg = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(root.title.isEmpty ? "Mind Map" : root.title).png"
        panel.begin { response in
            if response == .OK, let url = panel.url { try? png.write(to: url) }
        }
    }

    // MARK: Chrome

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button(action: addChild) { Label("Add Child", systemImage: "arrow.turn.down.right") }
                .help("Add child topic (Tab)")
            Button(action: addSibling) { Label("Add Sibling", systemImage: "plus") }
                .help("Add sibling topic (Return)")
            Button(action: deleteSelected) { Label("Delete", systemImage: "trash") }
                .help("Delete topic (⌫)")
                .disabled(ui.selection == nil || ui.selection == root.id)
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                Picker("Theme", selection: $themeID) {
                    ForEach(Theme.all) { t in Text(t.name).tag(t.id) }
                }
                .pickerStyle(.inline)
                Picker("Layout", selection: $styleRaw) {
                    ForEach(LayoutStyle.allCases) { s in Label(s.label, systemImage: s.icon).tag(s.rawValue) }
                }
                .pickerStyle(.inline)
                Divider()
                Toggle("Name File After Central Topic", isOn: $nameFileAfterRoot)
                Toggle("Auto-hide Toolbar", isOn: $autoHideToolbar)
                Toggle("Show Shortcut Hints", isOn: $showHints)
            } label: {
                Label("Style", systemImage: "paintpalette")
            }
            .help("Theme and layout")

            ControlGroup {
                Button { ui.zoom = clampZoom(ui.zoom / 1.2) } label: { Label("Zoom Out", systemImage: "minus.magnifyingglass") }
                Button { zoomToFit() } label: { Text("\(Int((ui.zoom * 100).rounded()))%").monospacedDigit() }
                    .help("Zoom to fit (⌘9) · ⌘0 for 100%")
                Button { ui.zoom = clampZoom(ui.zoom * 1.2) } label: { Label("Zoom In", systemImage: "plus.magnifyingglass") }
            }

            Button(action: exportPNG) { Label("Export PNG", systemImage: "square.and.arrow.up") }
                .help("Export as PNG image")
            Button { ui.showSource.toggle() } label: { Label("Markdown", systemImage: "doc.plaintext") }
                .help("Show the Markdown that gets saved")
        }
    }

    private var hintBar: some View {
        HStack(spacing: 14) {
            hint("Tab", "child"); hint("↩", "sibling"); hint("type", "rename")
            hint("Space", "fold"); hint("⌘↑↓", "reorder"); hint("drag", "re-parent")
        }
        .font(.system(size: 11))
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(.regularMaterial, in: Capsule())
        .padding(.bottom, 12)
        .allowsHitTesting(false)
    }

    private func hint(_ key: String, _ what: String) -> some View {
        HStack(spacing: 4) {
            Text(key).fontWeight(.semibold)
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 4).fill(.quaternary))
            Text(what).foregroundStyle(.secondary)
        }
    }
}

struct SourcePanel: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Markdown").font(.headline)
                Spacer()
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(markdown, forType: .string)
                }
            }
            .padding(12)
            Divider()
            ScrollView {
                Text(markdown)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
        }
    }
}

/// Transient editor state. (A class instead of `@State` vars: the macOS 27 SDK implements
/// `@State` as a macro whose plugin ships only with full Xcode, not the Command Line Tools.)
final class EditorUIState: ObservableObject {
    @Published var selection: UUID?
    @Published var editing: UUID?
    @Published var editText = ""
    @Published var editSelectAll = true
    @Published var editIsNew = false
    @Published var zoom: CGFloat = 1
    @Published var pinchBase: CGFloat?
    @Published var drag: DragState?
    @Published var dropTarget: UUID?
    @Published var showSource = false
    @Published var viewport: CGSize = .zero
    weak var window: NSWindow?
    let chrome = ChromeAutoHider()
}
