# Wingman handoff for Claude

**Repository:** `/Users/eric/wingman`  
**Primary product:** a platform-agnostic dating and friendship discovery app where user-controlled agents can recommend people, explain a mutual fit, and help with optional messaging. iMessage is an optional integration.

## Read before editing

- The working tree has substantial **uncommitted** work. Do not reset, clean, discard, or overwrite unrelated changes.
- Preserve the existing redesign in `App/WingmanApp/HomeView.swift`. It predates the onboarding work and remains intentionally uncommitted for visual review.
- Never put API keys, passwords, OAuth tokens, or raw private history in source, docs, logs, or the SQLite profile store.
- The local SQLite and LAN gateway are prototype infrastructure. They are not production identity, authorization, transport security, chat, or retention infrastructure.

## What changed most recently

The primary iOS entry flow is implemented and installed in the iPhone Simulator.

1. A clean launch shows the full-screen red-to-coral **Wingman** sign-in. This screen is settled — it was briefly restyled to a warm canvas and reverted at Eric's direction. Leave it alone unless he asks.
2. A valid local email moves the app to the AI-agent picker. From here on the surface is a warm off-white canvas (Hinge-referenced): white rows, black type, purple checkboxes, solid ink pill action.
3. The picker offers **ChatGPT** and **Claude** only.
4. Selecting ChatGPT marks the row selected and then presents `ChatGPTCrawlView`. Continuing unlocks the existing tab app.

So the onboarding deliberately spans two surfaces: `WingmanOnboardingBackground` (coral, sign-in only) and `WingmanPalette.warmCanvas` / `warmSurface` / `warmHairline` / `bloom` for everything after it, paired with the fixed `meshInk` pair. All are fixed rather than adaptive, since these screens commit to one look regardless of system theme.

`DemoAccounts.resolve(email:)` maps any signed-in address to an account, falling back to Eric. Without it an unlisted address left the session with no context and the ChatGPT import silently did not appear.

The sign-in is local prototype state. The provider picker records a local selection. No real ChatGPT, OpenAI, Claude, or Anthropic account is authorized yet.

## Current onboarding implementation

| File | Role |
|---|---|
| `App/WingmanApp/RootView.swift` | Routes `.login` to `LoginView`, `.connectAgent` to `AgentConnectionView`, then exposes the existing tab UI. |
| `App/WingmanApp/OnboardingView.swift` | Full-screen sign-in and provider-picker SwiftUI surfaces. It contains the visual system, back navigation, provider cards, and the clear prototype boundary copy. |
| `App/WingmanApp/AppModel.swift` | `completePrototypeLogin`, `returnToLogin`, provider selection, and provider-setup completion actions. |
| `App/Shared/WingmanCore/Models.swift` | `AgentProvider`, `OnboardingRoute`, persisted onboarding state, and `AgentProvider.onboardingProviders == [.openAI, .claude]`. |
| `Sources/WingmanCoreSelfTest/main.swift` | Eight focused core checks, including the login route, agent route, state round trip, and the two-provider list. |

### Route contract

```text
hasCompletedLogin == false                         -> .login
hasCompletedLogin == true, setup incomplete        -> .connectAgent
setup complete and at least one provider selected  -> .app
```

`returnToLogin()` intentionally clears local provider selections and setup completion. It preserves the typed email only in memory.

### Brand assets

The provider cards use bundled SVG vector marks:

- `App/Resources/WingmanApp/Assets.xcassets/OpenAILogo.imageset/openai.svg`
- `App/Resources/WingmanApp/Assets.xcassets/ClaudeLogo.imageset/claude.svg`

`Design/THIRD_PARTY_MARKS.md` records their LobeHub MIT source and trademark-use boundary.

The marks identify a connection option only. Before any release, check current provider brand-use rules and replace them with provider-distributed assets if required.

## Visual reference and verified UI

The supplied reference image is on this Mac:

```text
/Users/eric/Library/Application Support/Hermes/composer-images/composer_2026-08-09_21-47-36-070_769f1d.png
```

Its transferable patterns are the edge-to-edge warm gradient, large centered white product lockup, generous vertical spacing, small consent copy above outlined capsule actions, and a simple bottom support affordance. Wingman uses its own lockup, wording, and symbols.

**Visual proof completed:** a fresh install on the iPhone 17 Pro Simulator visibly rendered the updated sign-in screen. The email placeholder is white, avoiding the system-blue placeholder from the prior implementation.

**Visual boundary:** the provider screen compiles and its route is covered by the core test. Hermes' simulator keyboard injection did not populate the email field, so the exact loaded provider screen was not visually stepped through by automation. Manually enter a valid email in the Simulator to inspect it before changing its design.

Simulator currently used:

```text
iPhone 17 Pro, iOS 26.5
UDID: 051E00A3-9C37-488E-B959-4F85C9B86B60
Bundle ID: com.naitikgupta.wingman
```

## Verified commands

These passed after the current onboarding changes:

```bash
cd /Users/eric/wingman
swift run wingman-core-selftest
xcodegen generate --spec project.yml
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun xcodebuild -project Wingman.xcodeproj -scheme Wingman \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=051E00A3-9C37-488E-B959-4F85C9B86B60' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

The core self-test reports `wingman-core self-test: 8 passed`.

An ad-hoc focused verifier also passed. It asserted the two-provider list, rendered strings, SVG titles and colors, successful Xcode asset compilation, and the generated Simulator app bundle.

## Broader work already in the tree

- `gateway/src/profileStore.ts` and `gateway/src/server.ts` add an approved-public-profile SQLite sync prototype.
- `App/Shared/WingmanCore/WingmanSync.swift` is the iOS client for that approved-profile-only sync path.
- `docs/PROFILE_SYNC.md` and `Scripts/run-profile-sync-gateway.sh` document local Mac and LAN setup.
- `docs/WINGMAN_PRODUCT_SPEC.md` is the primary product specification. It covers the agent-ranked swipe feed, mutual matches, the Match Reveal, consent boundaries, and production gaps.
- `docs/CHATGPT_CONTEXT_CRAWL.md` specifies how a ChatGPT data export becomes approved profile facts. Stages 1–3 are designed but not implemented; `DemoAccounts.swift` hardcodes two packets in their place.
- `App/Shared/WingmanCore/DemoAccounts.swift` holds the two hardcoded accounts (`eric@gmail.com`, `julian@gmail.com`). Signing in with either seeds that profile, its ChatGPT-derived memories, and the other account as a candidate. Julian's packet is placeholder text pending his real export.
- `App/WingmanApp/ChatGPTCrawlView.swift` is the import screen shown when ChatGPT is connected. Its six stage captions are the real pipeline from `docs/CHATGPT_CONTEXT_CRAWL.md` in order; the timeline in `run()` stands in until the ingest reports real progress into the same sequence. The mark is `PetalBloom`, six translucent ellipses whose overlap forms the darker core. Connecting ChatGPT only marks the provider connected once that screen finishes. No user-facing copy calls this seeded or hardcoded — that fact lives in these docs and in the source, deliberately.
- `App/Shared/WingmanDesignSystem/Components/WingmanMark.swift` draws the app-icon mark; the onboarding lockup uses it instead of an SF Symbol.
- `docs/CLAUDE_HANDOFF.md` is this document.

The sync payload must continue to be derived from `HumanProfile.publicSnapshot`. It must exclude raw chat history, arbitrary private memories, and unapproved fields.

## Immediate product boundaries

Do not describe the current UI as real authentication or real AI-account linking. A real connection requires provider-supported OAuth or another explicitly approved authorization mechanism, secure server-side credential handling, consent scopes, disconnect and revocation, failure states, and a privacy-manifest redesign.

The product must keep these constraints:

- Users approve profile data before agent reasoning or discovery exposure.
- Agents cannot disclose arbitrary private history, make commitments, send external messages, or contact other people without user approval. Match transparency can expose only approved, structured evidence and unknowns. It excludes chain-of-thought, raw private logs, unrestricted memories, and model weights.

## Suggested next work

1. Manually inspect the ChatGPT and Claude picker on the same simulator. Check the two SVG marks, selection state, back action, and safe-area spacing.
2. Decide the real identity provider and real AI-provider authorization model before wiring any OAuth UI. Do not fake a completed connection.
3. Continue the social vertical slice with persistent swipes, reciprocal match creation, bounded in-app chat, block/report controls, and the evidence-backed Match Reveal described in `docs/WINGMAN_PRODUCT_SPEC.md`.
4. Keep the physical iPhone-to-Mac sync verification open until a device is connected on the same Wi-Fi.

## Git status at handoff

`git diff --check` passed. The repository has many uncommitted modifications and untracked files across app UI, core state, local gateway, generated Xcode files, documentation, and tests. Treat this as an in-progress working tree. Review with `git status --short` and `git diff` before any edit or commit.
