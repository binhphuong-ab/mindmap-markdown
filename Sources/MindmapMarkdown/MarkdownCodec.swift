import Foundation

/// The YAML block at the top of a map file:
///
///     ---
///     created: 2026-11-24
///     modified: 2026-11-24
///     type: mindmap
///     ---
///
/// `created` is kept from the file, `modified` is the day of the save, and `type` is always
/// `mindmap`. Any other keys (tags, aliases…) are kept exactly as written.
struct FrontMatter: Equatable {
    var created: String
    var extraLines: [String] = []

    static let managedKeys: Set<String> = ["created", "modified", "type"]

    init(created: Date = Date()) { self.created = FrontMatter.day(created) }

    static func day(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// Reads the front matter block if the text starts with one. `fileCreated` is used when
    /// the file has no `created:` of its own (maps saved before front matter existed).
    static func parse(_ text: String, fileCreated: Date? = nil) -> FrontMatter {
        var fm = FrontMatter(created: fileCreated ?? Date())
        let lines = text.components(separatedBy: .newlines)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return fm }
        var skippingValue = false              // continuation lines of a key we rewrite
        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" || trimmed == "..." { break }
            let isContinuation = line.first == " " || line.first == "\t" || trimmed.hasPrefix("- ") || trimmed.isEmpty
            if isContinuation {
                if !skippingValue { fm.extraLines.append(line) }
                continue
            }
            guard let colon = line.firstIndex(of: ":") else { fm.extraLines.append(line); skippingValue = false; continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            if managedKeys.contains(key) {
                skippingValue = true
                if key == "created" {
                    let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    if !value.isEmpty { fm.created = value }
                }
            } else {
                skippingValue = false
                fm.extraLines.append(line)
            }
        }
        while fm.extraLines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { fm.extraLines.removeLast() }
        return fm
    }

    func render(modified: Date) -> String {
        (["---", "created: \(created)", "modified: \(FrontMatter.day(modified))", "type: mindmap"]
            + extraLines + ["---"]).joined(separator: "\n")
    }
}

/// Reads and writes mind maps as plain Markdown that reads like a normal document.
///
///     ---
///     created: 2026-11-24
///     modified: 2026-11-24
///     type: mindmap
///     ---
///
///     # Central Idea
///
///     ## Branch
///
///     - Detail
///       - Smaller detail
///
///     ## Another branch
///
/// Main branches become `##` headings and their sub-branches `###` headings (when they have
/// something under them); everything deeper is a nested `- ` list. Folding is a view setting
/// and is not written to the file.
///
/// On input, headings (`##`, `###`…), nested lists (`-`, `*`, `+`, `1.`), task boxes and
/// front matter are all understood, so older maps and ordinary notes open too. Markmap's
/// `<!-- markmap: fold -->` marker in older files still opens those branches folded.
enum MarkdownCodec {
    private static let foldRegex = try! NSRegularExpression(pattern: #"\s*<!--\s*markmap:\s*fold\s*-->"#)
    private static let commentRegex = try! NSRegularExpression(pattern: #"^\s*<!--.*-->\s*$"#)
    private static let headingRegex = try! NSRegularExpression(pattern: #"^ {0,3}(#{1,6})(?:\s+(.*?))?(?:\s+#+)?\s*$"#)
    private static let listRegex = try! NSRegularExpression(pattern: #"^([ \t]*)(?:[-*+]|\d+[.)])\s+(.*)$"#)

    /// Branches down to this heading level are written as headings; deeper ones as bullets.
    private static let deepestHeading = 3

    // MARK: Writing

    static func serialize(_ root: MindNode, frontMatter: FrontMatter = FrontMatter(),
                          modified: Date = Date()) -> String {
        var lines = [frontMatter.render(modified: modified), "", heading(1, root.title)]

        func bullets(_ nodes: [MindNode], _ level: Int) {
            let indent = String(repeating: "  ", count: level)
            for node in nodes {
                lines.append("\(indent)- \(clean(node.title))")
                bullets(node.children, level + 1)
            }
        }
        /// A group of siblings becomes headings only if one of them has topics under it —
        /// a list of one-liners reads better as bullets than as a stack of tiny headings.
        func section(_ nodes: [MindNode], headingLevel: Int) {
            guard !nodes.isEmpty else { return }
            if headingLevel <= deepestHeading, nodes.contains(where: { !$0.children.isEmpty }) {
                for node in nodes {
                    lines += ["", heading(headingLevel, node.title)]
                    section(node.children, headingLevel: headingLevel + 1)
                }
            } else {
                lines.append("")
                bullets(nodes, 0)
            }
        }

        section(root.children, headingLevel: 2)
        return lines.joined(separator: "\n") + "\n"
    }

    /// A title ending in `#` gets a closing `#`, or Markdown would read its tail as decoration.
    private static func heading(_ level: Int, _ title: String) -> String {
        let text = clean(title)
        return String(repeating: "#", count: level) + " " + text + (text.hasSuffix("#") ? " #" : "")
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

            let whole = NSRange(location: 0, length: (line as NSString).length)
            if commentRegex.firstMatch(in: line, range: whole) != nil { continue }

            let (content, folded) = stripFold(line)
            let ns = content as NSString
            let range = NSRange(location: 0, length: ns.length)

            if let m = headingRegex.firstMatch(in: content, range: range) {
                let level = m.range(at: 1).length
                let titleRange = m.range(at: 2)
                let title = titleRange.location == NSNotFound ? "" : ns.substring(with: titleRange)
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
