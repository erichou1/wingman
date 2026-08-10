# ChatGPT context crawl

How Wingman turns a person's ChatGPT history into approved discovery-profile
facts. The pipeline is designed here in full; the MVP ships stages 1–2 as a
**hardcoded fixture** (see `DemoAccounts.swift`) and the real ingest lands later
without changing the contract.

## Why an export and not an API

OpenAI publishes no API that reads a consumer ChatGPT account's conversation
history. The Platform API (`api.openai.com`) is a separate product with separate
billing; it cannot see `chatgpt.com` conversations. Nothing in the ChatGPT
desktop or web client exposes a supported transcript endpoint either.

This is the same wall the iMessage spike hit — Apple exposes no transcript
enumeration to a Messages extension — and it gets the same answer:

| Source | Supported route | Wingman component |
|---|---|---|
| iMessage | User grants Full Disk Access; read local `chat.db` read-only | `wingman-history` (Mac companion) |
| ChatGPT | User requests their official data export; read the local `.zip` | `wingman-chatgpt` (this document) |

Both routes are explicit, user-initiated, revocable, and local-first. Neither
scrapes a session cookie or drives a logged-in browser. **Do not add a crawler
that authenticates as the user against `chatgpt.com`** — it breaks OpenAI's
terms, it breaks the moment the client changes, and it puts a live credential in
the product for data the user can hand over deliberately.

### Getting the export

ChatGPT → Settings → Data controls → Export data → confirm → OpenAI emails a
download link (valid 24 hours) → `.zip`.

```text
chatgpt-export.zip
├── conversations.json      <- the whole crawl target
├── user.json               <- account email; binds an export to a Wingman account
├── chat.html               <- rendered duplicate, ignored
├── message_feedback.json   <- ignored
├── model_comparisons.json  <- ignored
└── <media files>           <- ignored
```

## Stage 1 — Ingest

Read `user.json` for `email`, and refuse the import if it does not match the
signed-in Wingman account. That check is the only thing preventing someone from
seeding a profile with a stranger's export.

`conversations.json` is a single JSON array and routinely reaches hundreds of
megabytes on a heavy account. Parse it as a stream (`JSONDecoder` over a file
handle, or a SAX-style reader), never `Data(contentsOf:)` into memory.

The `.zip` is treated exactly like the NDJSON history export: gitignored, never
uploaded, deleted after derivation unless the user opts to keep it.

## Stage 2 — Linearize (the part that is easy to get wrong)

Each conversation object looks like this:

```json
{
  "title": "Erdős 1054 tightness",
  "create_time": 1754697600.0,
  "update_time": 1754784000.0,
  "conversation_id": "…",
  "current_node": "e4f1…",
  "mapping": {
    "a1b2…": {
      "id": "a1b2…",
      "parent": null,
      "children": ["c3d4…"],
      "message": { … }
    }
  }
}
```

**`mapping` is a tree, not a list.** Every edit and every regeneration forks a
new branch, and all branches stay in the export forever. Iterating
`mapping.values()` — the obvious implementation — yields abandoned drafts,
superseded prompts, and duplicate near-identical turns, which then get counted
as real signal and skew every frequency derived downstream.

The correct walk is:

```text
node := conversation.current_node
while node != nil:
    prepend node to path
    node := mapping[node].parent
```

That reconstructs the single branch the user actually last saw. Reverse it and
you have the conversation in order.

Then filter the path:

| Drop | Why |
|---|---|
| `message == nil` | Root/placeholder nodes carry no content. |
| `author.role != "user"` | Assistant text is the model's words, not the person's. It must not become profile signal. |
| `metadata.is_visually_hidden_from_conversation == true` | Injected system context the user never saw. |
| `content.content_type` outside `text` / `multimodal_text` | `code`, `execution_output`, `thoughts`, `reasoning_recap` are tool and model artifacts. |
| `recipient != "all"` | Tool calls, not conversation. |

Two content shapes to handle: `parts` is `[String]` for `text`, but for
`multimodal_text` its elements are objects (`{"asset_pointer": …}`) that must be
skipped rather than string-cast. `create_time` is a nullable Unix epoch float —
fall back to the conversation's `create_time`.

### The one node worth special-casing

`content_type == "user_editable_context"` holds the account's **custom
instructions** — the answers to "What would you like ChatGPT to know about you?"
and "How would you like ChatGPT to respond?". This is the single highest-signal
object in the export: self-authored, present-tense, already a self-description.
Extract `user_profile` and `user_instructions` verbatim. Everything else in the
crawl is inference; this is testimony.

## Stage 3 — Derive

Two tiers, kept strictly apart, matching the existing "no fabricated AI insight"
boundary in `docs/MESSAGE_HISTORY_ARCHITECTURE.md`.

**Deterministic (no model involved).** Reproducible from the export alone:

- **Topics** — conversation titles plus term frequency over user turns, stopworded, collapsed by stem. Carries a conversation count and a last-discussed date.
- **Recurring entities** — capitalized n-grams appearing across at least N distinct conversations, so one-off mentions do not become "interests".
- **Cadence** — conversations per week, hour-of-day histogram, average user turn length.
- **Custom instructions** — verbatim, from the node above.

**Proposed (model pass, through the existing gateway/NIM route).** Takes *only*
the deterministic summary above — never raw conversation text — and proposes
candidate `interests`, `values`, and a bio line. Output is labeled proposed and
lands unapproved. The model never sees a transcript, so a prompt injection
buried in someone's chat history has nothing to reach.

Both tiers write one object:

```swift
ChatGPTContextPacket(
  accountEmail:, exportGeneratedAt:, conversationCount:, userTurnCount:,
  earliestConversationAt:, customInstructions:, topics:, recurringEntities:,
  cadence:, proposedInterests:, proposedValues:, proposedBio:
)
```

`ChatGPTContextPacket` is defined in `App/Shared/WingmanCore/ChatGPTContext.swift`
and is the contract between the crawler and the app. The MVP's hardcoded demo
accounts construct it literally; the real crawler decodes it from a file. Nothing
downstream can tell the difference, which is the point.

## Stage 4 — Review and approve

Derived facts enter the app as `MemoryFact` with `source == .chatGPT`, replacing
any previous ChatGPT-sourced batch (same replace-in-place rule the Mac graph
import uses). They are visible and deletable in Memories.

Proposed profile fields are staged against `ProfileField` and are **unapproved by
default**. The existing approval gate does the rest: `HumanProfile.publicSnapshot`
only emits approved fields, so nothing derived from ChatGPT reaches the sync
gateway, another user's agent card, or a Match Reveal transcript until the person
ticks it.

```text
export.zip -> linearized user turns -> deterministic signals -> proposed fields
                                                                      |
                                                            per-field approval
                                                                      |
                                                        HumanProfile.publicSnapshot
                                                                      |
                                                       gateway / agent card / reveal
```

## Privacy boundary

1. Raw conversation text never leaves the device and never reaches the gateway, Qdrant, or another user.
2. Assistant turns are discarded at stage 2 and never become profile signal.
3. The model pass reads the deterministic summary only, so transcript content cannot inject into it.
4. An export is bound to one account email and rejected otherwise.
5. Re-import replaces the prior ChatGPT batch rather than appending, so removing a topic upstream removes it here.
6. Deleting Wingman data removes the packet, the derived facts, and any retained `.zip`.

## Incremental re-import

Exports are full snapshots, not deltas. Key the previous packet by
`conversation_id` → `update_time` and only re-derive conversations whose
`update_time` advanced. Conversations that disappear between exports were
deleted upstream and must be dropped locally too.

## MVP status

| Stage | MVP |
|---|---|
| 1 Ingest | Not implemented. Hardcoded packets stand in. |
| 2 Linearize | Not implemented. Algorithm specified above. |
| 3 Derive | Not implemented. Packet shape is final and in use. |
| 4 Review and approve | **Implemented** — reuses the existing per-field approval gate. |

Eric's packet is seeded from real project context. Julian's is placeholder text
pending his export; replace the literal in `DemoAccounts.swift` and nothing else
changes.
