# Dots

*Read to collect dots. Write to connect them.*

Dots is a minimal, opinionated writing app for macOS. Capture ideas from everything you read, connect them into your own thinking, and write — distraction-free. Everything you make is a plain markdown file on your Mac, version-controlled with local git. Your words are yours, forever.

## The pipeline

**Collect.** See a tweet or an essay worth keeping? One keyboard shortcut from the menu bar (⌥Space), or one click on the Chrome extension, and the source is saved into your vault — even when the app is closed. On-device AI quietly reads what you captured and proposes its core ideas into your library. Accept the good ones; they're dots now. Every accepted idea keeps its provenance — your words and everyone else's never blur.

**Connect.** Ideas live in real folders as real files, cross-cut by tags, joined by references. Browse them as a calm three-pane library or as a canvas of connections. Select a few dots and send them to a draft — the draft holds references to your raw material, never pasted text. Search everything instantly with ⌘P.

**Write.** One markdown buffer, two presentations: Rich conceals the syntax while you write, Markdown shows every character — no lock, no mode, always editable. Paragraph focus (⌘D) dims everything but the thought you're on, and the room dims with it: chrome, counters, and controls fade until you reach for them. Typewriter scrolling keeps your eyes still. Dictate anywhere — speech is cleaned of filler, never rephrased.

**AI, on your terms.** The intelligence is on-device by default — nothing leaves your Mac unless you deliberately choose a cloud model with your own key. Select text and improve, expand, or shorten it; ask for anything in your own words; summon a completion with Tab when you want one. AI-assisted words count as writing. There is no engagement to optimize, nothing to configure, no feed.

## Principles

- **Files are the truth.** The vault is a plain folder of markdown + git. Any editor can open it; deleting the app loses nothing.
- **Opinionated, not configurable.** Strong defaults over infinite settings — the settings window has three sections and earns each one.
- **Calm is not a mode.** Motion and delight live at the thresholds — capture, publish, sign-in — never inside the editor while you type.
- **Provenance is automatic.** Extractions from sources are marked as someone else's words until you make them yours. No honor system.

## Roadmap

- **Agents (MCP).** Bring your own agents to capture sources, extract ideas, organize the library, and draft alongside you — every agent edit reviewable as a plain git diff: accept or revert.
- **Sync.** Invisible auto-commit and pull against your own GitHub repo. Multi-device, no server of ours.
- **Publishing.** One click from draft to your own blog — a beautiful, minimal default theme deployed to GitHub Pages on your domain. Only `posts/` is ever public, structurally.
- **Email.** Maybe Substack-style sending, to put your writing in front of the people who asked for it.
- **iOS.** Capture-first companion on the same vault.

## Requirements

macOS 27, Apple silicon. The on-device AI features use Apple's foundation models; the optional cloud model is Claude, with your own API key, stored in the Keychain.

## Status

Dots is early open-source software. The source is available under the MIT license, and the current distribution path is building from source. Signed and notarized app releases may come later.

## Build from source

Prerequisites:

- Xcode with the macOS 27 SDK
- XcodeGen
- SwiftLint and Periphery for the full validation loop

Install the command-line tools with Homebrew:

```sh
brew install xcodegen swiftlint periphery
```

Clone and validate the Swift packages:

```sh
git clone https://github.com/MitchForest/dots.git
cd dots
swift build --package-path packages/DotsUI
swift build --package-path packages/Dots
swift test --package-path packages/Dots
```

Generate and open the macOS app project:

```sh
cd apps/macos
xcodegen generate
open Dots.xcodeproj
```

The Xcode project is generated from `apps/macos/project.yml` and is intentionally not checked in. For the full local validation loop, run:

```sh
Scripts/closeout.sh
```

## Repository map

- `apps/macos/` - macOS app composition root and XcodeGen project
- `apps/chrome/` - Chrome capture extension and native messaging setup
- `packages/Dots/` - product domain, engine, clients, features, and root screens
- `packages/DotsUI/` - design system, components, and shaders
- `tools/dots-capture-host/` - native host used by the Chrome extension
- `Scripts/closeout.sh` - build, test, lint, and dead-code validation

## License

MIT. See `LICENSE`.

---

Built for people cultivating a body of thought — one dot at a time.
