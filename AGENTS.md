# Dots — Agent Guide

Dots is a minimal, opinionated writing tool: capture ideas (dots), connect them, write, publish. macOS first. This file is the binding guide for anyone — human or agent — working in this repo. (`.docs/`, if present, is a local working scratchpad and is not tracked.)

## Workspace map

```
apps/macos/           # composition root only (@main, xcodegen project.yml)
apps/chrome/          # capture extension (MV3) → native messaging host
packages/DotsUI/      # design system: tokens, components, Metal shaders, gallery (zero deps)
packages/Dots/        # the product: Domain → Engine/Clients → Features → Root (strict layering)
tools/                # headless roots over Clients (dots-capture-host; dots-mcp later)
Scripts/closeout.sh   # build + test + lint + periphery — run before handing off work
```

## Commands

- Build: `swift build --package-path packages/Dots` (and `packages/DotsUI`)
- Test: `swift test --package-path packages/Dots`
- App: `cd apps/macos && xcodegen generate && xcodebuild -project Dots.xcodeproj -scheme Dots build`
- Everything: `Scripts/closeout.sh` — must exit clean before you consider work done

## Architecture

**Layering is one-directional and compile-enforced:**

```
App (apps/macos) → DotsRoot → DotsFeatures → { DotsEngine, DotsClients } → DotsDomain
```

- **DotsDomain** — pure value types (`Dot`, `Source`, `IdeaProposal`, `VaultDocument`, …). `Sendable`, no I/O, no dependencies.
- **DotsEngine** — pure algorithms over Domain: markdown styling/formatting/typing, prompt builders and parsers, file codecs, search ranking, canvas layout. Deterministic and fully unit-tested.
- **DotsClients** — every boundary (files, network, keychain, speech, models, time, randomness) is a client: a struct of `@Sendable` closures with a `live()` implementation and at least one mock (`inMemory`, `unavailable`). Live implementations are constructed only at composition roots and tests (lint-enforced).
- **DotsFeatures** — TCA26 features + their SwiftUI screens. `@MainActor` by default.
- **DotsRoot** — facade screens the app target composes; the only layer the app imports.
- **DotsUI** — leaf design system (tokens, components, shaders); imported by Features and above only; depends on nothing in the product.

**Data invariants:**

- The user's vault is plain markdown files + local git — the only source of truth. Anything derived is recomputed from files on demand; no derived store ever holds truth.
- Provenance is binary and automatic: `source:` present in an idea's frontmatter means someone else's words; absent means authored. Connections are directed `references:` (file ULIDs).
- Folders are real directories, never frontmatter. Publishing is structural: only `posts/` is ever built for the public site.
- Cross-process signals are distributed notifications (`blog.dots.captured`, `blog.dots.proposals-changed`, `blog.dots.settings-changed`); in-app surfaces subscribe via client streams.

## TCA26 (`ComposableArchitecture2`) rules

- All stateful logic lives in `@Feature` types named after the thing — **never** suffixed `Feature` (e.g. `Editor`, `Ideas`, `Intake`). Use the `pfw-composable-architecture-2` skill when writing feature code.
- No `Effect` returns: async work is `store.addTask` from update closures; cancellation via `@StoreTaskID`.
- Bindings over actions for simple mutations; actions are named literally after the user gesture or the data that returned (`dotTapped`, `proposalsLoaded`).
- Child features compose via `Scope`/`ifLet`; parents intercept child actions; cross-feature signals use `FeatureEventKey` + `store.post`/`.onEvent` (events flow child → ancestor only).
- **Send before you suspend further:** `TestStore.receive` has `timeout: .zero` by default and only observes actions sent ≤1 suspension deep — chain multi-fetch loads action-by-action, one client call per action; give load-sensitive receives an explicit timeout.
- Feature helpers that need the implicit store take `FeatureStore<State, Action>`, not `StoreOf<Self>`.

## Views

- Views are pure: read `store`, send actions — no I/O (lint-enforced: no `URLSession`, `FileManager`, `.shared`).
- Screens own stores; components own nothing (data + closures in, model-blind).
- `public import` only in facade files (`*Screen.swift`, Root) — everywhere else plain `import` (InternalImportsByDefault is on).
- Every Screen/Component ships a `#Preview` using mocks. Light + dark verified for UI work.
- Native mechanisms, custom surfaces: context menus are real menus, click counts come from `NSApp.currentEvent`, responder-chain actions for text-view commands (focus the target and retry when nothing claims the action).
- Chrome placement doctrine: window-scope controls in the native titlebar; pane chrome floats inside panes; selection actions live in context menus. Nothing permanent that's only sometimes relevant.

## Concurrency

- Swift 6 strict concurrency, no escape hatches — `@unchecked Sendable` and `nonisolated(unsafe)` are lint errors. Use `Mutex` (Synchronization) for audio-thread state.
- Domain/Engine/Clients are `Sendable` value types; Features/Root are `@MainActor` by default.

## Testing & hygiene

- Swift Testing (`@Suite`/`@Test`) with `TestStore` and mock clients. A feature without tests is not done.
- Engine/Domain get plain unit tests — they're pure.
- Dead-code honesty: periphery retains only DotsUI (design-system surface). Product packages must scan clean — delete dead code. Test-only fixtures the app scheme can't see carry `// periphery:ignore - <reason>` above their doc comment.
- Banned type names: `Manager`, `Service`, `Helper`, `Util`, `ViewModel`, `Network`, `API`.
- swiftlint caps: 900-line files, 360-line type bodies — split handlers/computed groups into extensions before you hit them.

## Working style

- Small, complete increments; `Scripts/closeout.sh` clean at every stop point.
- Do not add settings/configuration surface without explicit product sign-off — Dots is opinionated.
- The writing surface stays calm: shaders and motion live at thresholds (sign-in, capture, publish), never inside the editor while typing. Fades are one breath: slow out, quick in.
- API keys live in the Keychain only. Copy that sends user content to an external model says so where the choice is made.
