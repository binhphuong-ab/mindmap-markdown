import SwiftUI

/// Callbacks the canvas forwards to the editor. `nil` actions = static render (PNG export).
struct MapActions {
    var select: (UUID) -> Void
    var edit: (UUID) -> Void
    var toggleFold: (UUID) -> Void
    var dragChanged: (UUID, CGSize, CGPoint) -> Void
    var dragEnded: (UUID, CGPoint) -> Void
}

struct DragState: Equatable { var id: UUID; var offset: CGSize }

/// Draws edges (one Canvas pass) and topics (SwiftUI views) at laid-out positions.
struct MapCanvas: View {
    let layout: MindLayout
    let theme: Theme
    var selection: UUID? = nil
    var editing: UUID? = nil
    var dropTarget: UUID? = nil
    var drag: DragState? = nil
    var actions: MapActions? = nil

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { ctx, _ in drawEdges(ctx) }
                .frame(width: layout.size.width, height: layout.size.height)
                .allowsHitTesting(false)

            ForEach(layout.nodes) { node in
                NodeView(node: node, theme: theme,
                         selected: node.id == selection && editing == nil,
                         isDropTarget: node.id == dropTarget,
                         hideText: node.id == editing)
                    .frame(width: node.frame.width, height: node.frame.height)
                    .modifier(NodeInteraction(node: node, actions: actions))
                    .offset(drag?.id == node.id ? drag!.offset : .zero)
                    .opacity(drag?.id == node.id ? 0.75 : 1)
                    .zIndex(drag?.id == node.id ? 10 : 0)
                    .position(x: node.frame.midX, y: node.frame.midY)
            }

            ForEach(layout.nodes.filter(showsBadge)) { node in
                FoldBadge(node: node, color: node.depth == 0 ? theme.accent : theme.branch(node.branch),
                          textColor: node.depth == 0 ? theme.rootText : theme.branchText)
                    .onTapGesture { actions?.toggleFold(node.id) }
                    .position(x: node.side < 0 ? node.frame.minX - 13 : node.frame.maxX + 13,
                              y: node.anchorY)
            }
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
    }

    private func showsBadge(_ n: LaidOutNode) -> Bool {
        n.hiddenCount > 0 || (actions != nil && n.id == selection && n.childCount > 0 && editing == nil)
    }

    private func drawEdges(_ ctx: GraphicsContext) {
        for node in layout.nodes {
            guard let parent = layout[node.parent] else { continue }
            let color = theme.branch(node.branch)
            let start: CGPoint, w0: CGFloat
            if parent.depth == 0 {
                // Branches grow out from inside the root pill; the root is drawn on top.
                start = CGPoint(x: parent.frame.midX + node.side * parent.frame.width * 0.25, y: parent.frame.midY)
                w0 = 8
            } else {
                start = CGPoint(x: parent.farX, y: parent.anchorY)
                w0 = NodeStyle.thickness(parent.depth)
            }
            let w1 = NodeStyle.thickness(node.depth)
            let end = CGPoint(x: node.nearX, y: node.anchorY)
            ctx.fill(Self.taperedCurve(from: start, to: end, w0: w0, w1: w1), with: .color(color))

            if NodeStyle.isUnderlined(node.depth) {
                let r = CGRect(x: node.frame.minX, y: node.frame.maxY - w1 / 2, width: node.frame.width, height: w1)
                ctx.fill(Path(roundedRect: r, cornerRadius: w1 / 2), with: .color(color))
            }
        }
    }

    /// An S-curve drawn as a filled ribbon so it can taper from parent to child.
    static func taperedCurve(from a: CGPoint, to b: CGPoint, w0: CGFloat, w1: CGFloat) -> Path {
        let midX = a.x + (b.x - a.x) * 0.5
        let c1 = CGPoint(x: midX, y: a.y), c2 = CGPoint(x: midX, y: b.y)
        func up(_ p: CGPoint, _ w: CGFloat) -> CGPoint { CGPoint(x: p.x, y: p.y - w / 2) }
        func down(_ p: CGPoint, _ w: CGFloat) -> CGPoint { CGPoint(x: p.x, y: p.y + w / 2) }
        var p = Path()
        p.move(to: up(a, w0))
        p.addCurve(to: up(b, w1), control1: up(c1, w0), control2: up(c2, w1))
        p.addLine(to: down(b, w1))
        p.addCurve(to: down(a, w0), control1: down(c2, w1), control2: down(c1, w0))
        p.closeSubpath()
        return p
    }
}

struct NodeView: View {
    let node: LaidOutNode
    let theme: Theme
    let selected: Bool
    let isDropTarget: Bool
    let hideText: Bool

    private var cornerRadius: CGFloat {
        switch node.depth {
        case 0: return min(node.frame.height / 2, 26)
        case 1: return 12
        default: return 6
        }
    }

    var body: some View {
        let color = theme.branch(node.branch)
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        Text(node.title)
            .font(Font(NodeStyle.font(node.depth) as CTFont))
            .foregroundStyle(node.depth == 0 ? theme.rootText : node.depth == 1 ? theme.branchText : theme.text)
            .multilineTextAlignment(node.depth <= 1 ? .center : .leading)
            .frame(width: node.textSize.width, height: node.textSize.height,
                   alignment: node.depth <= 1 ? .center : .leading)
            .opacity(hideText ? 0 : 1)
            .frame(width: node.frame.width, height: node.frame.height)
            .background {
                switch node.depth {
                case 0:
                    shape.fill(LinearGradient(colors: theme.root, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: theme.root[0].opacity(0.4), radius: 16, y: 7)
                case 1:
                    shape.fill(LinearGradient(colors: [color, color.opacity(0.82)], startPoint: .top, endPoint: .bottom))
                        .shadow(color: color.opacity(0.3), radius: 7, y: 3)
                default:
                    shape.fill(selected ? theme.accent.opacity(0.12) : .clear)
                }
            }
            .overlay {
                if selected {
                    shape.inset(by: -4).stroke(theme.accent, lineWidth: 2.5)
                } else if isDropTarget {
                    shape.inset(by: -5).stroke(theme.accent, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                }
            }
    }
}

struct FoldBadge: View {
    let node: LaidOutNode
    let color: Color
    let textColor: Color

    var body: some View {
        let label = node.hiddenCount > 0 ? "\(node.hiddenCount)" : "−"
        Text(label)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(textColor)
            .padding(.horizontal, 5)
            .frame(minWidth: 18, minHeight: 18)
            .background(Capsule().fill(color))
            .overlay(Capsule().stroke(.white.opacity(0.8), lineWidth: 1.5))
            .contentShape(Capsule())
            .help(node.hiddenCount > 0 ? "Expand (Space)" : "Collapse (Space)")
    }
}

/// Click = select, double-click = edit, drag = re-parent.
struct NodeInteraction: ViewModifier {
    let node: LaidOutNode
    let actions: MapActions?

    func body(content: Content) -> some View {
        if let actions {
            content
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { actions.edit(node.id) }
                .simultaneousGesture(TapGesture().onEnded { actions.select(node.id) })
                .gesture(
                    DragGesture(minimumDistance: 6, coordinateSpace: .named("map"))
                        .onChanged { actions.dragChanged(node.id, $0.translation, $0.location) }
                        .onEnded { actions.dragEnded(node.id, $0.location) },
                    including: node.depth == 0 ? .subviews : .all)
        } else {
            content
        }
    }
}
