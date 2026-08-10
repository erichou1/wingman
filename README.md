# Wingman

Wingman is an agent-powered dating and friendship discovery app. A person controls the profile facts their agent may use, reviews people in a swipe feed, and gets in-app help once a mutual match opens chat. The existing iMessage extension remains an optional reply-assistance channel.

The current prototype includes:

- **Profile sync gateway:** a SQLite database on the developer Mac that receives only approved profile fields and makes an on-LAN feed available to the iPhone app.
- **Help me reply:** paste a message, add relationship context and intent, review three editable drafts, then insert one into the Messages compose field.
- **My human:** build a profile and approve each field independently before it may enter the prototype sync gateway.
- **Meet My Human:** compare approved profiles locally while the swipe, reciprocal-match, chat, and agent-reveal flows are implemented.
- **Privacy:** Wingman never sends autonomously. The profile gateway never receives raw Messages history.

## Open the iOS prototype

Requirements:

- Full Xcode with the iOS 17 SDK
- An Apple Developer team for device signing
- An iPhone or iPad with Messages enabled

Generate the project after changing `project.yml`:

```sh
xcodegen generate --spec project.yml
open Wingman.xcodeproj
```

In Xcode, select the **Wingman** target, choose your Team under Signing & Capabilities, and ensure the App Group `group.com.naitikgupta.wingman` is registered for both Wingman bundle IDs. Run the containing app once, then open any Messages conversation, tap **+**, choose **More**, and open Wingman.

The Messages extension only inserts a reply or card into the compose field. The person must still tap Send.

## Verify without Xcode

The shared consent, matching, payload, persistence, and reply logic is also a Swift package so it can be verified from the command line:

```sh
swift build
swift run wingman-core-selftest
swift run wingman-history-selftest
```

## Full Messages history spike

Apple does not expose an iPhone conversation transcript API to iMessage extensions. The supported product route is a separately installed Mac companion: the user explicitly grants Full Disk Access, it reads the Mac’s local `chat.db` read-only, builds private derived context, and later syncs only encrypted context packets to the iPhone app.

```sh
swift run wingman-history access-check
swift run wingman-history export \
  --output ./wingman-history.ndjson \
  --acknowledge-sensitive-data
```

Raw exports contain private messages and identifiers. They are ignored by git and must never be uploaded.

### Auto-reading new messages (Mac watch daemon)

`export` is a one-shot manual snapshot. `wingman-history watch` instead runs continuously, using `IMsgCore`'s file-watch/poll pipeline to notice new messages as they arrive and append them to a local NDJSON log, persisting a checkpoint so a restart resumes instead of replaying history:

```sh
swift run wingman-history watch \
  --acknowledge-sensitive-data
# appends to ~/Library/Application Support/Wingman/history-watch.ndjson by default
# checkpoint: ~/Library/Application Support/Wingman/history-watch-state.json
```

To have it run automatically at login (a `launchd` LaunchAgent, restarted if killed):

```sh
Scripts/install-history-watch-daemon.sh    # builds a release binary and installs it
Scripts/uninstall-history-watch-daemon.sh  # stops and removes it
```

The installer prints a required manual step: granting Full Disk Access to the built binary in System Settings, since that permission cannot be granted through code or an entitlement.

**This only gets the Mac to notice new messages locally.** There is currently no transport that moves that context from the Mac to the iPhone app — see [Message history architecture](docs/MESSAGE_HISTORY_ARCHITECTURE.md) for what's implemented versus still aspirational.

### On-device relationship graph

`wingman-history build-graph` turns the watch log into a deterministic, frequency-based JSON summary (top contacts, common openers/sign-offs, emoji usage — no fabricated "AI insight"):

```sh
swift run wingman-history build-graph
# reads ~/Library/Application Support/Wingman/history-watch.ndjson by default
# writes ~/Library/Application Support/Wingman/relationship-graph.json by default
```

Bring that JSON file onto your iPhone yourself (AirDrop, Files, iCloud Drive) and import it from the **Memories** tab in the app — it merges in as Mac-derived memories alongside anything you type in directly, and both feed every drafted reply.

## Reply drafting via NVIDIA NIM

Replies are drafted by the NVIDIA NIM API (`meta/llama-3.1-8b-instruct` by default), using your writing style and memories from the Memories tab as context. Set up the key once:

```sh
cp Secrets.xcconfig.example Secrets.xcconfig
# edit Secrets.xcconfig, set NVIDIA_API_KEY to a real key from build.nvidia.com
```

`Secrets.xcconfig` is gitignored and wired into both the app and extension targets' Info.plist by `project.yml`'s `configFiles`; it's never committed or hardcoded in source. If a NIM request fails for any reason (no key, network error, non-2xx), Wingman automatically falls back to a deterministic offline draft rather than leaving reply generation dead — check **Settings → NVIDIA NIM** for key status and a manual connection test.

## Render Workflow reply path

For the hackathon deployment, Wingman can send reply requests through Render Workflows. The workflow runs the three tones in parallel through a Render gateway, keeping the Render and NVIDIA keys off the phone. Leave `RENDER_WORKFLOW_URL` at its placeholder to keep using the direct-NIM path. The full local and production setup is in [Render Workflow integration](docs/RENDER_WORKFLOW.md).

See:

- [Profile sync gateway](docs/PROFILE_SYNC.md)
- [Product plan](docs/PRODUCT_PLAN.md)
- [Message history architecture](docs/MESSAGE_HISTORY_ARCHITECTURE.md)
- [TestFlight checklist](docs/TESTFLIGHT_CHECKLIST.md)
- [Third-party notices](THIRD_PARTY_NOTICES.md)
