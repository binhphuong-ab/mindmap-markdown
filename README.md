# Mindmap Markdown

A native macOS mind-map editor whose file format is plain Markdown.

```markdown
# Central Idea

- Branch
  - Leaf
- Folded branch <!-- markmap: fold -->
  - Hidden leaf
```

The `.md` file *is* the document, and its **file name follows the central topic**: rename
the root and the file is renamed on disk (⌘Z renames it back); a new map's Save dialog
suggests the root's text. Toggle it under Style ▸ "Name File After Central Topic".

The Markdown opens unchanged in Obsidian, Markmap, GitHub
or any text editor. Mindmap Markdown also reads ordinary notes: `##`/`###` headings, `-`/`*`/`+`/`1.`
lists, task boxes and front matter all become topics.

## Build

```bash
./build.sh               # build + install to /Applications
./build.sh --no-install  # build "./Mindmap Markdown.app" only
```

Needs only the Xcode Command Line Tools (Swift 6+, macOS 14+).

## Keys

| Key | Action |
|---|---|
| Tab | add child (also while typing: commit + new child) |
| Return | add sibling (while typing: commit) |
| just start typing / F2 / double-click | rename |
| Esc | cancel rename |
| ⌫ | delete topic |
| Space | fold / unfold |
| ← → ↑ ↓ | move selection |
| ⌘↑ / ⌘↓ | reorder among siblings |
| drag a topic onto another | re-parent |
| ⌘= ⌘- ⌘0 ⌘9 / pinch | zoom in / out / 100% / fit |
| ⌘Z / ⇧⌘Z | undo / redo |

The top bar auto-hides: move the mouse to the top edge to reveal it; it hides again 5 s after
the mouse leaves (Style ▸ "Auto-hide Toolbar" to turn off).

Toolbar: themes (Aurora, Midnight, Paper, Ocean, Blossom), balanced or right-only layout,
PNG export (2×), and a live Markdown source panel.

## Layout of the code

| File | Role |
|---|---|
| `MindNode.swift` | value-type tree + edit operations (index-path addressed) |
| `MarkdownCodec.swift` | Markdown ⇄ tree |
| `MindMapDocument.swift` | `ReferenceFileDocument`, explicit undo |
| `MindLayout.swift` | measures text, places topics (balanced left/right tree) |
| `MapCanvas.swift` | tapered Bézier branches in one `Canvas`, topic views, fold badges |
| `FileNameSync.swift` | keeps the file name equal to the central topic (`NSDocument.move`) |
| `ChromeAutoHider.swift` | hides/reveals the whole title bar on hover |
| `EditorField.swift` | AppKit text field for in-place renaming |
| `ContentView.swift` | selection, keyboard, zoom, drag, toolbar, export |

Note: the macOS 27 SDK implements SwiftUI's `@State` as a macro whose plugin ships only
with full Xcode, so view state lives in an `ObservableObject` (`EditorUIState`) instead.
