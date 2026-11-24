import Foundation

/// Reads and writes mind maps as plain Markdown.
///
///     # Central Idea
///
///     - Branch
///       - Leaf
///     - Folded branch <!-- markmap: fold -->
///
/// The output is Markmap/Obsidian compatible. On input, headings (`##`, `###`…) and
/// nested lists (`-`, `*`, `+`, `1.`) are both understood, so ordinary notes open too.
enum MarkdownCodec {
    static let foldMarker = "<!-- markmap: fold -->"
    private static let foldRegex = try! NSRegularExpression(pattern: #"\s*<!--\s*markmap:\s*fold\s*-->"#)
    private static let headingRegex = try! NSRegularExpression(pattern: #"^ {0,3}(#{1,6})\s+(.*?)\s*#*\s*$"#)
    private static let listRegex = try! NSRegularExpression(pattern: #"^([ \t]*)(?:[-*+]|\d+[.)])\s+(.*)$"#)

    // MARK: Writing

    static func serialize(_ root: MindNode) -> String {
        var out = "# \(clean(root.title))\n"
        if !root.children.isEmpty { out += "\n" }
        func walk(_ node: MindNode, _ level: Int) {
            let indent = String(repeating: "  ", count: level)
            let fold = node.collapsed && !node.children.isEmpty ? " \(foldMarker)" : ""
            out += "\(indent)- \(clean(node.title))\(fold)\n"
            node.children.forEach { walk($0, level + 1) }
        }
        root.children.forEach { walk($0, 0) }
        return out
    }

    private static func clean(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
    }

    // MARK: Reading

    private final class Box {
        var title: String, collapsed: Bool, children: [Box] = []
        init(_ title: String, _ collapsed: Bool = false) { self.title = title; self.collapsed = collapsed }
        func node() -> MindNode {
            MindNode(title: title, children: children.map { $0.node() }, collapsed: collapsed)
        }
    }

    static func parse(_ text: String, fallbackTitle: String = "Central Idea") -> MindNode {
        var root: Box?
        var rootLevel = 0                       // heading level of the root (0 = synthesized)
        var stack: [Box] = []                   // stack[d] = latest node at depth d
        var base = 0                            // depth of the heading that owns the current list
        var listStack: [(indent: Int, level: Int)] = []
        var inFence = false, inFrontMatter = false

        func ensureRoot() {
            if root == nil { let r = Box(fallbackTitle); root = r; stack = [r] }
        }
        @discardableResult func insert(_ box: Box, depth: Int) -> Int {
            let parent = max(0, min(depth - 1, stack.count - 1))
            stack[parent].children.append(box)
            stack = Array(stack.prefix(parent + 1)) + [box]
            return parent + 1
        }

        let lines = text.components(separatedBy: .newlines)
        for (n, raw) in lines.enumerated() {
            let line = raw.replacingOccurrences(of: "\t", with: "    ")
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if n == 0 && trimmed == "---" { inFrontMatter = true; continue }
            if inFrontMatter { if trimmed == "---" || trimmed == "..." { inFrontMatter = false }; continue }
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") { inFence.toggle(); continue }
            if inFence || trimmed.isEmpty { continue }

            let (content, folded) = stripFold(line)
            let ns = content as NSString
            let range = NSRange(location: 0, length: ns.length)

            if let m = headingRegex.firstMatch(in: content, range: range) {
                let level = m.range(at: 1).length
                let title = ns.substring(with: m.range(at: 2))
                listStack = []
                if root == nil {
                    let r = Box(title, folded); root = r; stack = [r]; rootLevel = level; base = 0
                } else {
                    base = insert(Box(title, folded), depth: max(1, level - rootLevel))
                }
            } else if let m = listRegex.firstMatch(in: content, range: range) {
                ensureRoot()
                let indent = m.range(at: 1).length
                var title = ns.substring(with: m.range(at: 2))
                for box in ["[ ] ", "[x] ", "[X] "] where title.hasPrefix(box) { title.removeFirst(4) }
                while let last = listStack.last, last.indent > indent { listStack.removeLast() }
                let level: Int
                if let last = listStack.last, last.indent == indent { level = last.level }
                else { level = (listStack.last?.level ?? 0) + 1; listStack.append((indent, level)) }
                insert(Box(title, folded), depth: base + level)
            } else {
                ensureRoot()
                // Indented plain text continues the previous item; otherwise it's a topic of its own.
                if line.first == " ", let last = stack.last, stack.count > 1 {
                    last.title += " " + trimmed
                } else {
                    insert(Box(trimmed, folded), depth: base + 1)
                }
            }
        }
        ensureRoot()
        return root!.node()
    }

    private static func stripFold(_ s: String) -> (String, Bool) {
        let ns = s as NSString
        let r = NSRange(location: 0, length: ns.length)
        guard foldRegex.firstMatch(in: s, range: r) != nil else { return (s, false) }
        return (foldRegex.stringByReplacingMatches(in: s, range: r, withTemplate: ""), true)
    }
}
