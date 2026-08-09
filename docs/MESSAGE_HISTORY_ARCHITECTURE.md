# Entire Message History Architecture

## Decision

Use a containing iOS app with an iMessage extension plus a separately installed macOS companion.

The macOS companion is the only component that ingests full Messages history. It reads `~/Library/Messages/chat.db` after the user explicitly grants Full Disk Access. The iPhone app and iMessage extension never attempt to scrape the transcript or use private iOS APIs.

## Why this is the viable route

Apple's `MSConversation` API exposes the active conversation, its participant identifiers, and the selected message only when that message belongs to the extension. It has no transcript enumeration API. An iPhone-only implementation cannot meet the full-history requirement through supported APIs.

On macOS, Apple documents that Full Disk Access can grant access to protected data from other apps, including Messages. The user must enable it in System Settings; it cannot be silently granted through an entitlement or code.

The importer uses the MIT-licensed `IMsgCore` package pinned to commit `be5b490531000000abc079e26512b23709e16d84`. It opens SQLite in read-only mode and handles schema variations and message text stored in `attributedBody`. Wingman does not use its sending, Automation, or optional private-framework features.

## Data flow

```text
Messages in iCloud
        |
        v
macOS Messages local cache (chat.db + attachments)
        |
        | explicit Full Disk Access, read-only
        v
Wingman Mac companion
        |
        +--> normalize messages, replies, reactions, attachments
        +--> build encrypted local relationship graph
        +--> generate user-reviewable context packets
        |
        | client-side encrypted sync; derived context only
        v
Containing iOS app <--> iMessage extension
```

## Privacy boundary

1. Full Disk Access is opt-in and revocable.
2. Database access is read-only. Wingman never edits or sends through `chat.db`.
3. Raw messages remain on the Mac by default.
4. Production ingestion writes directly to an encrypted local graph; the NDJSON exporter exists only to validate completeness during development.
5. The user reviews every profile fact or context packet before it can be shared with another person.
6. Reply suggestions are inserted into the Messages compose field for review. Wingman does not send autonomously.
7. Deleting Wingman data must remove the graph, cached context packets, keys, and any development exports without altering Messages.

## Prototype milestones

### P0: History ingestion — implemented

- Detect whether `chat.db` exists and whether access is granted (`wingman-history access-check`).
- Read all logical messages in stable batches (`wingman-history export`, one-shot).
- **Auto-detect new messages as they arrive** (`wingman-history watch`): wraps `IMsgCore.MessageWatcher` (kqueue file-watch over `chat.db`/`-wal`/`-shm` plus a fallback poll) so the daemon notices new messages without a manual export. `Scripts/install-history-watch-daemon.sh` registers it as a per-user LaunchAgent so it runs automatically at login and restarts if killed.
- Preserve chat, participant, sender, timestamp, direction, service, reply/thread links, reactions, read state, and attachment metadata.
- Never print message contents to logs (only row IDs and counts).
- **Resume incrementally from the last imported message row** — `HistoryWatchStore` persists a checkpoint under `~/Library/Application Support/Wingman/history-watch-state.json` so a killed/relaunched daemon (or a crash) resumes from where it left off instead of replaying history. `HistoryExporter`'s one-shot `export` still starts at row 0 each run by design — it's for manual dev/validation exports, not continuous ingestion.

Not yet implemented: message content redaction/normalization beyond the raw NDJSON record, and any pruning/retention policy for the watch log.

### P1: Private relationship graph — started, minimal

- Convert normalized events into people, conversations, topics, commitments, preferences, boundaries, and unresolved-thread nodes. **Only a first slice exists**: `wingman-history build-graph` (`RelationshipGraphBuilder` in `Sources/WingmanHistoryCore/`) reads the watch log and derives per-contact message counts/last-seen plus a purely frequency-based writing-style signal (common openers/sign-offs, emoji rate, repeated short phrases). No topic, commitment, boundary, or unresolved-thread extraction — that's genuine NLP/inference work, not attempted here, and everything produced today is deterministic counting, not model-derived.
- Attach provenance from every derived node back to local message row IDs. Not implemented — the graph output has no row-ID linkage back to source messages yet.
- Require user review before promoting inferred profile facts. Implemented at the import boundary: graph-derived facts land in the Memories screen tagged "From Mac" and are editable/removable like anything else, but there's no explicit per-fact approval step before they start feeding prompts.

The graph is built **on the Mac** (fully testable via the CLI, no simulator needed) and written to a local JSON file. Since P2 below is still unbuilt, getting that file onto the iPhone is a manual step: the user brings it over themselves (AirDrop/Files/iCloud Drive) and imports it in the Memories screen's file picker — not automatic sync.

### P2: iMessage reply assistance — partially blocked, now NIM-backed

- Sync a small encrypted context packet to the containing iOS app. **Still not implemented — this is the actual gap.** The iOS app and Messages extension only share state locally on the same device via an App Group (`SharedStateStore`); there is no transport (CloudKit or otherwise) that moves anything from the Mac watcher to an iPhone automatically (see the manual-import workaround in P1). Building real sync needs Apple Developer portal container setup and real-device testing.
- Open Wingman inside Messages and request a suggestion for the active relationship. Implemented, using only text the person pastes in — see the privacy boundary above.
- Present three editable responses and explain the relevant context. Implemented via `NIMReplyAssistant`, which calls the NVIDIA NIM API with the user's writing style and memories as context, three times (one per tone). Falls back automatically to the original deterministic `ReplyAssistant` template if the NIM call fails for any reason.
- Insert the selected draft into the compose field; never send it automatically. Implemented.

### P3: Meet My Human

- Compare only user-approved profile facts from two Wingman users.
- Explain potential resonance and friction without ranking compatibility.
- Share an introduction card only after both users opt into that introduction.

## Known constraints

- A Mac must be signed into Messages and allowed to finish syncing for the Mac database to represent the user's full iCloud history.
- Before the first import, set Messages → Settings → General → Keep messages to **Forever**, enable Messages in iCloud, and click **Sync Now**. Messages already deleted under an earlier retention policy cannot be recovered by Wingman.
- Full Disk Access is a high-trust permission and will be a conversion cost.
- `chat.db` is undocumented implementation detail. The pinned reader and fixture coverage must be updated when Apple changes the schema.
- Mac App Store sandbox review may not fit direct database access. Prototype distribution should use a signed, notarized download while App Store feasibility is tested separately.
- The current spike can normalize full history but has not read this Mac's live database because the Codex parent process lacks Full Disk Access.

## Primary references

- Apple Messages framework: https://developer.apple.com/documentation/messages
- Apple `MSConversation`: https://developer.apple.com/documentation/messages/msconversation
- Apple macOS App Sandbox file access: https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox
- Apple Full Disk Access settings: https://support.apple.com/guide/mac-help/change-privacy-security-settings-on-mac-mchl211c911f/mac
- `IMsgCore`: https://github.com/openclaw/imsg
