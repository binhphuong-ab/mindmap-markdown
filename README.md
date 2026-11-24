<div align="center">

# Mindmap Markdown

**Beautiful mind maps for your Mac — saved as simple text files you'll never lose.**

<img src="docs/images/hero-aurora.webp" alt="A colourful mind map titled 'Trip to Japan' with branches for Before you go, Tokyo, Kyoto, Food to try, Budget and Packing" width="900">

### [⬇️ Download for Mac (Apple Silicon)](https://github.com/binhphuong-ab/mindmap-markdown/releases/latest)

<sub>Free · macOS 14 Sonoma or later · Apple M1/M2/M3/M4 · 0.5 MB</sub>

</div>

---

## What is it?

A **mind map** is a picture of your thoughts: one big idea in the middle, with related ideas
branching out around it. It's a great way to plan a trip, brainstorm a project, take notes in a
class, or untangle a busy week.

**Mindmap Markdown** is a free Mac app for making mind maps that look lovely and are quick to
build — mostly with the keyboard, so your ideas flow as fast as you can type them.

What makes it different: every map is saved as an ordinary **text file** (a "Markdown" file,
ending in `.md`). That means your maps are never locked inside one app. You can open them in
Notes-style apps like Obsidian, read them in any text editor, or email them to a friend — and
they'll still make sense.

## Why you'll like it

- 🎨 **Looks great out of the box** — smooth, colourful branches and five hand-picked themes.
- ⌨️ **Fast to build** — press **Tab** for a new idea, **Return** for the next one, and just type.
- 🧘 **Distraction-free** — the top bar disappears while you work and comes back when you need it.
- 📄 **Your notes stay yours** — plain text files, saved on your Mac, no account, no internet needed.
- ↩️ **No fear of mistakes** — every change can be undone with **⌘Z**.
- 🖼️ **Easy to share** — export your map as a picture (PNG) in one click.

---

## Pick your look

Five themes, from bright to calm to dark. Switch any time from the **palette** button in the top bar.

<table>
  <tr>
    <td align="center"><img src="docs/images/theme-midnight.webp" alt="Midnight theme: dark background with glowing coloured branches" width="420"><br><b>Midnight</b> — easy on the eyes at night</td>
    <td align="center"><img src="docs/images/theme-paper.webp" alt="Paper theme: warm cream background with soft, muted colours" width="420"><br><b>Paper</b> — warm and calm, like a notebook</td>
  </tr>
  <tr>
    <td align="center"><img src="docs/images/theme-ocean.webp" alt="Ocean theme: pale blue background with blue and green branches" width="420"><br><b>Ocean</b> — cool blues and greens</td>
    <td align="center"><img src="docs/images/theme-blossom.webp" alt="Blossom theme: soft pink background with pink, purple and coral branches" width="420"><br><b>Blossom</b> — soft pinks and corals</td>
  </tr>
</table>

The map at the top of this page uses **Aurora**, the default theme. You can also choose whether
branches spread out on **both sides** of the central idea (balanced) or all to the **right**.

---

## Your map is just a text file

Click the **document** button in the top bar to see exactly what gets saved. On the left is your
map; on the right is the same map as plain text.

<div align="center">
<img src="docs/images/markdown-panel.webp" alt="The app with the mind map on the left and its Markdown text on the right" width="900">
</div>

The file reads like a normal document, even without the app:

```markdown
---
created: 2026-11-24
modified: 2026-11-24
type: mindmap
---

# Trip to Japan

## Tokyo

- Shibuya crossing
- Senso-ji temple

## Food to try

- Ramen
- Sushi
```

The block between the `---` lines at the top records when the map was made and last changed,
so note apps such as Obsidian can sort and search your maps. The `#` line is the big idea in the middle. Each `##` heading is a main branch, and the `-`
lines under it are its ideas. Indenting a `-` line puts it *under* the one above. Open the file
in Notes, Obsidian, GitHub or any Markdown viewer and it looks like tidy notes with headings.

You can also write a map by hand in any text editor and open it in Mindmap Markdown. Plain
bullet lists work too.

---

## Getting started

### What you need

- A Mac with **Apple Silicon** — an M1, M2, M3, M4 or newer chip.
  Not sure? Click the Apple menu  ▸ **About This Mac**: the *Chip* line should start with "Apple".
- **macOS 14 Sonoma or newer.**

### Install — the easy way (download)

1. Go to the **[latest release](https://github.com/binhphuong-ab/mindmap-markdown/releases/latest)**
   and click **Mindmap-Markdown-…-AppleSilicon.zip** to download it.
2. Open your **Downloads** folder and double-click the zip to unzip it.
3. Drag **Mindmap Markdown** into your **Applications** folder.
4. Double-click it to open.

#### The first time you open it

The app is free and isn't sold through Apple's App Store, so macOS asks you to confirm it
**once**:

1. macOS says it *couldn't verify* "Mindmap Markdown". Click **Done** (don't move it to the Bin).
2. Open **System Settings ▸ Privacy & Security** and scroll down to the *Security* section.
3. Next to *"Mindmap Markdown" was blocked to protect your Mac*, click **Open Anyway**,
   then confirm with your password or Touch ID.

That's it — from now on it opens normally, like any other app.

<details>
<summary><b>Install — the other way (build it yourself)</b></summary>

If you'd rather build the app from the source code (for example to get the very latest
changes), it takes four commands you copy and paste.

1. **Open Terminal.** Press **⌘ Space**, type `Terminal`, and press **Return**.

2. **Install Apple's free developer tools.** Copy this line into Terminal and press **Return**:

   ```bash
   xcode-select --install
   ```

   A window pops up — click **Install** and wait until it finishes (a few minutes).
   If it says the tools are *already installed*, that's fine — go to the next step.

3. **Download the source code.** Copy these two lines into Terminal and press **Return**:

   ```bash
   git clone https://github.com/binhphuong-ab/mindmap-markdown.git
   cd mindmap-markdown
   ```

4. **Build and install the app.** Copy this line and press **Return**:

   ```bash
   ./build.sh
   ```

   After a minute or so you'll see `installed /Applications/Mindmap Markdown.app`. Done! 🎉
   (An app you build yourself doesn't need the "Open Anyway" step.)

</details>

### Open it

Double-click **Mindmap Markdown** in Applications. Choose **File ▸ New** to start a fresh map,
or **File ▸ Open…** to open an existing `.md` file.

> **Tip:** to open `.md` files with Mindmap Markdown by double-clicking them in Finder,
> right-click any `.md` file ▸ **Get Info** ▸ under *Open with* pick **Mindmap Markdown** ▸
> click **Change All…**

---

## Make your first map in one minute

<div align="center">
<img src="docs/images/editing.webp" alt="Adding a new idea called 'Ghibli Museum' under the Tokyo branch" width="900">
</div>

1. **Name your big idea.** A new map starts with *Central Idea* in the middle and a few example
   branches (rename or delete them as you like). The central idea is already selected — just
   start typing to replace it, then press **Return**.
2. **Add a branch.** Press **Tab**. A new box appears; type your idea and press **Return**.
3. **Add the next branch.** Press **Return** again for another idea at the same level.
4. **Go deeper.** With an idea selected, press **Tab** to add a smaller idea *under* it
   (that's how "Ghibli Museum" is being added under "Tokyo" in the picture above).
5. **Move around** with the arrow keys, or just click any idea.
6. **Save** with **⌘S**. The file is named after your big idea automatically
   (a map called *Trip to Japan* saves as `Trip to Japan.md`).

That's the whole rhythm: **Tab** to go deeper, **Return** for the next idea, and type.

---

## Cheat sheet

### Keyboard

| To do this… | Press |
|---|---|
| Add an idea **under** the selected one | **Tab** |
| Add an idea **next to** the selected one | **Return** |
| Rename the selected idea | just start typing (or double-click it) |
| Finish typing | **Return** (or **Tab** to finish *and* add an idea under it) |
| Cancel typing | **Esc** |
| Delete an idea (and everything under it) | **Delete ⌫** |
| Hide / show the ideas under one | **Space** |
| Move between ideas | **← → ↑ ↓** |
| Move an idea up / down in its list | **⌘↑** / **⌘↓** |
| Undo / redo | **⌘Z** / **⇧⌘Z** |
| Zoom in / out | **⌘ =** / **⌘ −** (or pinch on the trackpad) |
| Fit the whole map in the window | **⌘ 9** |
| Back to normal size | **⌘ 0** |
| Save | **⌘S** |

### Mouse & trackpad

| To do this… | Do |
|---|---|
| Select an idea | click it |
| Rename an idea | double-click it |
| Move an idea to a different branch | drag it onto its new parent |
| Hide / show the ideas under one | click the small bubble at the end of its branch (**−** on the selected idea, a number when ideas are hidden) |
| Scroll around a big map | two-finger swipe on the trackpad |
| Zoom | pinch on the trackpad |

---

## Handy features

- **Fold away detail.** Press **Space** on an idea to tuck its branches away. A small bubble shows
  how many ideas are hidden; press **Space** again (or click the bubble) to bring them back. Folding only changes the view,
  so a map always opens with every branch showing.
- **The top bar hides itself.** After about 3 seconds the title and buttons fade away so the map
  fills the window. Move your mouse to the **top edge** of the window to bring them back.
  Prefer it always visible? Palette button ▸ untick **Auto-hide Toolbar**.
- **File name follows your big idea.** Rename the central idea and the file on your Mac is renamed
  to match. (Turn this off with Palette button ▸ **Name File After Central Topic**.)
- **Save as a picture.** Click the **share** button in the top bar to export the map as a
  high-resolution PNG — perfect for slides, chats or printing.
- **Autosave.** Like other Mac apps, your work is saved as you go, and **File ▸ Revert To** lets
  you go back to an earlier version.
- **Shortcut reminder.** The little bar at the bottom of the window lists the main keys. Hide it
  with Palette button ▸ **Show Shortcut Hints**.

---

## Questions

**Where are my maps saved?**
Wherever you choose when you first save — just like a Word or Pages document. They're ordinary
`.md` files you can see in Finder, back up, or put in iCloud Drive or Dropbox.

**Is anything uploaded to the internet?**
No. The app works completely offline and never sends your maps anywhere.

**Can I open my maps in other apps?**
Yes. Any app that reads Markdown can open them — for example **Obsidian**, **Typora**,
**VS Code**, or plain **TextEdit**. They'll appear as a tidy outline.

**Can I open my existing notes as a mind map?**
Often, yes. Headings (`#`, `##`, `###`) and bullet or numbered lists all turn into branches.

**I deleted something by mistake!**
Press **⌘Z** to undo. You can undo many steps back.

**Why does the big idea in the middle not delete?**
Every map needs one central idea, so it can't be deleted — but you can rename it any time.

**How do I update to a newer version?**
Download the newest zip from the [releases page](https://github.com/binhphuong-ab/mindmap-markdown/releases/latest)
and drag the app into Applications again, choosing **Replace**. Your maps are separate files, so
they aren't touched. (If you built the app yourself: in Terminal run
`cd mindmap-markdown && git pull && ./build.sh`.)

**Does it work on Intel Macs?**
The download is for Apple Silicon Macs only. On an Intel Mac you can still build it yourself
(see *Install — the other way* above).

---

## For developers

<details>
<summary>Build options, file format details and code layout</summary>

### Build

```bash
./build.sh               # build + install to /Applications
./build.sh --no-install  # build "./Mindmap Markdown.app" only
```

Needs only the Xcode Command Line Tools (Swift 5.10+, macOS 14+). The app is ad-hoc signed.

### File format

Plain Markdown that reads like a document:

- A YAML front matter block comes first: `created` (kept from the file; for older files without
  one, the file's creation date), `modified` (the day of the save) and `type: mindmap`. Any other
  keys you add by hand, such as `tags`, are kept as written.
- `# Root` is the central topic.
- Main branches are `##` headings and their sub-branches `###` headings, but only for a group of
  siblings where at least one has topics under it. A group of one-liners stays a bullet list.
- Everything deeper is a nested `- ` list with two-space indent.
- Folding is a view setting and is not saved, so the file holds nothing but your content.

Markmap opens these files as they are. On input, any heading depth, `-`/`*`/`+`/`1.` lists,
task boxes and front matter are understood, so ordinary notes open too. Maps saved by 1.0.x
open unchanged, and their `<!-- markmap: fold -->` branches start folded.

```markdown
---
created: 2026-11-24
modified: 2026-11-24
type: mindmap
---

# Central Idea

## Branch

- Leaf
  - Smaller leaf

## Branch with one-line ideas

- Idea
- Another idea
```

### Code layout

| File | Role |
|---|---|
| `MindNode.swift` | value-type tree + edit operations (index-path addressed) |
| `MarkdownCodec.swift` | Markdown ⇄ tree |
| `MindMapDocument.swift` | `ReferenceFileDocument`, explicit undo |
| `MindLayout.swift` | measures text, places topics (balanced left/right tree) |
| `MapCanvas.swift` | tapered Bézier branches in one `Canvas`, topic views, fold badges |
| `FileNameSync.swift` | keeps the file name equal to the central topic (`NSDocument.move`) |
| `ChromeAutoHider.swift` | fades the whole title bar out / in on hover |
| `EditorField.swift` | AppKit text field for in-place renaming |
| `ContentView.swift` | selection, keyboard, zoom, drag, toolbar, export |

Note: the macOS 27 SDK implements SwiftUI's `@State` as a macro whose plugin ships only with
full Xcode, so view state lives in an `ObservableObject` (`EditorUIState`) instead.

</details>

---

## License

Free and open source under the [MIT License](LICENSE) — you're welcome to use, share and change it.
