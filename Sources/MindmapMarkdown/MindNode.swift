import Foundation

/// One topic in the map. The whole map is a value-type tree rooted at a single node,
/// which keeps undo/redo trivial: every edit replaces the tree, SwiftUI diffs it.
struct MindNode: Identifiable, Equatable {
    var id = UUID()
    var title: String
    var children: [MindNode] = []
    var collapsed = false

    static let sample = MindNode(title: "Central Idea", children: [
        MindNode(title: "Goals", children: [MindNode(title: "Short term"), MindNode(title: "Long term")]),
        MindNode(title: "Ideas"),
        MindNode(title: "Resources"),
        MindNode(title: "Next steps", children: [MindNode(title: "Press Tab to add a child"),
                                                 MindNode(title: "Return adds a sibling")]),
    ])

    // MARK: Index-path addressing ([] is the root)

    subscript(path path: [Int]) -> MindNode {
        get { path.isEmpty ? self : children[path[0]][path: Array(path.dropFirst())] }
        set {
            if path.isEmpty { self = newValue }
            else { children[path[0]][path: Array(path.dropFirst())] = newValue }
        }
    }

    func indexPath(of target: UUID) -> [Int]? {
        if id == target { return [] }
        for (i, child) in children.enumerated() {
            if let sub = child.indexPath(of: target) { return [i] + sub }
        }
        return nil
    }

    func find(_ target: UUID) -> MindNode? {
        indexPath(of: target).map { self[path: $0] }
    }

    func parentID(of target: UUID) -> UUID? {
        guard let p = indexPath(of: target), !p.isEmpty else { return nil }
        return self[path: Array(p.dropLast())].id
    }

    var descendantCount: Int { children.reduce(children.count) { $0 + $1.descendantCount } }

    // MARK: Edits (all return the id that should be selected afterwards)

    mutating func update(_ target: UUID, _ change: (inout MindNode) -> Void) {
        guard let p = indexPath(of: target) else { return }
        change(&self[path: p])
    }

    @discardableResult
    mutating func addChild(to parent: UUID, title: String = "") -> UUID? {
        guard let p = indexPath(of: parent) else { return nil }
        let node = MindNode(title: title)
        self[path: p].collapsed = false
        self[path: p].children.append(node)
        return node.id
    }

    @discardableResult
    mutating func addSibling(after target: UUID, title: String = "") -> UUID? {
        guard let p = indexPath(of: target), let last = p.last else {
            return addChild(to: target, title: title)   // root has no siblings
        }
        let node = MindNode(title: title)
        self[path: Array(p.dropLast())].children.insert(node, at: last + 1)
        return node.id
    }

    /// Removes a node and returns the best neighbour to select next.
    mutating func remove(_ target: UUID) -> UUID? {
        guard let p = indexPath(of: target), let last = p.last else { return nil }
        let parentPath = Array(p.dropLast())
        self[path: parentPath].children.remove(at: last)
        let siblings = self[path: parentPath].children
        if siblings.isEmpty { return self[path: parentPath].id }
        return siblings[min(last, siblings.count - 1)].id
    }

    mutating func move(_ target: UUID, by offset: Int) {
        guard let p = indexPath(of: target), let last = p.last else { return }
        let parentPath = Array(p.dropLast())
        let to = last + offset
        guard self[path: parentPath].children.indices.contains(to) else { return }
        self[path: parentPath].children.swapAt(last, to)
    }

    /// Moves `target` to become the last child of `newParent`. Refuses cycles.
    mutating func reparent(_ target: UUID, under newParent: UUID) -> Bool {
        guard target != newParent,
              let node = find(target),
              node.find(newParent) == nil,                 // can't drop into own subtree
              parentID(of: target) != newParent,
              let p = indexPath(of: target), let last = p.last else { return false }
        self[path: Array(p.dropLast())].children.remove(at: last)
        guard let np = indexPath(of: newParent) else { return false }
        self[path: np].collapsed = false
        self[path: np].children.append(node)
        return true
    }
}
