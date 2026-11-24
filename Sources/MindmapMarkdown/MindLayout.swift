import AppKit

/// Visual style per depth. Root = gradient pill, level 1 = coloured pill,
/// level 2+ = text sitting on a branch-coloured underline that the edges flow into.
enum NodeStyle {
    static func font(_ depth: Int) -> NSFont {
        switch depth {
        case 0: return .systemFont(ofSize: 22, weight: .bold)
        case 1: return .systemFont(ofSize: 16, weight: .semibold)
        default: return .systemFont(ofSize: 14, weight: .regular)
        }
    }
    static func padding(_ depth: Int) -> CGSize {
        switch depth {
        case 0: return CGSize(width: 28, height: 16)
        case 1: return CGSize(width: 16, height: 9)
        default: return CGSize(width: 6, height: 5)
        }
    }
    static let maxTextWidth: CGFloat = 240
    static func isUnderlined(_ depth: Int) -> Bool { depth >= 2 }
    /// Branch thickness where an edge *ends* at a node of this depth.
    static func thickness(_ depth: Int) -> CGFloat { depth <= 1 ? 3.5 : depth == 2 ? 2.2 : 1.6 }
}

struct LaidOutNode: Identifiable {
    let id: UUID
    let title: String
    let depth: Int
    let side: CGFloat          // +1 right, -1 left, 0 root
    var frame: CGRect
    var textSize: CGSize
    let branch: Int
    let parent: UUID?
    let childCount: Int
    let hiddenCount: Int       // descendants hidden by folding

    /// Point where edges attach: vertical centre for pills, the underline for plain topics.
    var anchorY: CGFloat { NodeStyle.isUnderlined(depth) ? frame.maxY : frame.midY }
    var farX: CGFloat { side < 0 ? frame.minX : frame.maxX }
    var nearX: CGFloat { side < 0 ? frame.maxX : frame.minX }
}

struct MindLayout {
    private(set) var nodes: [LaidOutNode] = []
    private(set) var size: CGSize = .zero
    private var index: [UUID: Int] = [:]

    subscript(id: UUID?) -> LaidOutNode? { id.flatMap { index[$0] }.map { nodes[$0] } }

    static let padding: CGFloat = 140

    init(root: MindNode, style: LayoutStyle) {
        var heights: [UUID: CGFloat] = [:]
        var sizes: [UUID: (box: CGSize, text: CGSize)] = [:]

        func measure(_ n: MindNode, _ depth: Int) -> (box: CGSize, text: CGSize) {
            if let s = sizes[n.id] { return s }
            let t = TextMeasure.size(n.title, depth: depth)
            let p = NodeStyle.padding(depth)
            let box = CGSize(width: max(t.width + p.width * 2, depth == 0 ? 120 : 44),
                             height: t.height + p.height * 2)
            sizes[n.id] = (box, t)
            return (box, t)
        }
        func vGap(_ childDepth: Int) -> CGFloat { childDepth == 1 ? 26 : childDepth == 2 ? 10 : 6 }
        func hGap(_ parentDepth: Int) -> CGFloat { parentDepth == 0 ? 70 : parentDepth == 1 ? 44 : 32 }
        func visibleChildren(_ n: MindNode) -> [MindNode] { n.collapsed ? [] : n.children }

        @discardableResult
        func subtreeHeight(_ n: MindNode, _ depth: Int) -> CGFloat {
            if let h = heights[n.id] { return h }
            let kids = visibleChildren(n)
            let own = measure(n, depth).box.height
            let sum = kids.map { subtreeHeight($0, depth + 1) }.reduce(0, +)
                + vGap(depth + 1) * CGFloat(max(0, kids.count - 1))
            let h = max(own, sum)
            heights[n.id] = h
            return h
        }

        var out: [LaidOutNode] = []
        func place(_ n: MindNode, depth: Int, side: CGFloat, nearX: CGFloat, top: CGFloat,
                   branch: Int, parent: UUID) {
            let m = measure(n, depth)
            let centerY = top + subtreeHeight(n, depth) / 2
            let x = side > 0 ? nearX : nearX - m.box.width
            out.append(LaidOutNode(id: n.id, title: n.title, depth: depth, side: side,
                                   frame: CGRect(x: x, y: centerY - m.box.height / 2,
                                                 width: m.box.width, height: m.box.height),
                                   textSize: m.text, branch: branch, parent: parent,
                                   childCount: n.children.count,
                                   hiddenCount: n.collapsed ? n.descendantCount : 0))
            let kids = visibleChildren(n)
            placeGroup(kids, depth: depth + 1, side: side,
                       nearX: nearX + side * (m.box.width + hGap(depth)),
                       centerY: centerY, branch: { _ in branch }, parent: n.id)
        }
        func placeGroup(_ kids: [MindNode], depth: Int, side: CGFloat, nearX: CGFloat,
                        centerY: CGFloat, branch: (MindNode) -> Int, parent: UUID) {
            let total = kids.map { subtreeHeight($0, depth) }.reduce(0, +)
                + vGap(depth) * CGFloat(max(0, kids.count - 1))
            var y = centerY - total / 2
            for k in kids {
                place(k, depth: depth, side: side, nearX: nearX, top: y, branch: branch(k), parent: parent)
                y += subtreeHeight(k, depth) + vGap(depth)
            }
        }

        // Root at the origin.
        let rm = measure(root, 0)
        out.append(LaidOutNode(id: root.id, title: root.title, depth: 0, side: 0,
                               frame: CGRect(x: -rm.box.width / 2, y: -rm.box.height / 2,
                                             width: rm.box.width, height: rm.box.height),
                               textSize: rm.text, branch: -1, parent: nil,
                               childCount: root.children.count,
                               hiddenCount: root.collapsed ? root.descendantCount : 0))

        // Split first-level branches: fill the right side until it carries half the weight.
        let kids = visibleChildren(root)
        let weights = kids.map { subtreeHeight($0, 1) }
        let totalWeight = weights.reduce(0, +)
        var right: [MindNode] = [], left: [MindNode] = [], acc: CGFloat = 0
        for (k, w) in zip(kids, weights) {
            if style == .right || acc < totalWeight / 2 { right.append(k); acc += w } else { left.append(k) }
        }
        let branchIndex = Dictionary(uniqueKeysWithValues: root.children.enumerated().map { ($1.id, $0) })
        let gap = hGap(0)
        placeGroup(right, depth: 1, side: 1, nearX: rm.box.width / 2 + gap, centerY: 0,
                   branch: { branchIndex[$0.id] ?? 0 }, parent: root.id)
        // Left side runs bottom-to-top so reading order goes clockwise around the root.
        placeGroup(left.reversed(), depth: 1, side: -1, nearX: -rm.box.width / 2 - gap, centerY: 0,
                   branch: { branchIndex[$0.id] ?? 0 }, parent: root.id)

        // Shift everything into positive canvas coordinates.
        let bounds = out.reduce(CGRect.null) { $0.union($1.frame) }
        let dx = Self.padding - bounds.minX, dy = Self.padding - bounds.minY
        for i in out.indices { out[i].frame = out[i].frame.offsetBy(dx: dx, dy: dy) }
        nodes = out
        size = CGSize(width: bounds.width + Self.padding * 2, height: bounds.height + Self.padding * 2)
        index = Dictionary(uniqueKeysWithValues: out.enumerated().map { ($1.id, $0) })
    }
}

enum TextMeasure {
    nonisolated(unsafe) private static var cache: [String: CGSize] = [:]

    static func size(_ text: String, depth: Int, maxWidth: CGFloat = NodeStyle.maxTextWidth) -> CGSize {
        let key = "\(min(depth, 2))|\(maxWidth)|\(text)"
        if let s = cache[key] { return s }
        let font = NodeStyle.font(depth)
        let sample = text.isEmpty ? " " : text
        let r = (sample as NSString).boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font])
        // A couple of points of slack so SwiftUI's Text never wraps earlier than AppKit predicted.
        let s = CGSize(width: ceil(text.isEmpty ? 30 : r.width) + 3, height: ceil(r.height))
        if cache.count > 5000 { cache.removeAll() }
        cache[key] = s
        return s
    }
}
