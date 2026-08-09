# Wingman Product Plan

## Product contract

Wingman helps its human think and connect; it does not impersonate them, select partners, rank people, or send messages autonomously.

Every relationship type is supported. Every suggested reply is editable. Every profile field is private until its human approves it for matching. An introduction can be created only after both humans approve that specific introduction.

## Prototype vertical slice

The first beta proves this complete loop:

1. A person creates and approves a profile in the containing iOS app.
2. The prototype loads an invited second profile.
3. Wingman explains possible resonance, possible friction, and conversation starters without a compatibility score.
4. Both approval states are recorded for that specific comparison.
5. The Messages extension reads the approved local state through an App Group.
6. Wingman inserts an introduction card into the compose field.
7. The human reviews the card and taps Send.

The same extension also accepts a manually pasted incoming message and inserts one of three editable reply drafts.

## What is intentionally local in the first beta

- Profile, candidate, insight, and consent state
- Deterministic matching explanations
- Deterministic reply drafts
- Prototype simulation of the invited human and their approval

This lets the interaction and privacy boundaries be tested before accounts, networking, or paid model inference are introduced.

## Next production slices

### Accounts and real two-person consent

- Sign in with Apple
- Invite links and verified profile ownership
- Independent server records for each human’s approval
- Expiring, single-introduction consent tokens
- Block, report, revoke, and delete flows

### Context intelligence

- Signed Mac companion with explicit Full Disk Access onboarding
- Incremental, read-only Messages ingestion
- Encrypted local relationship graph with message-row provenance
- User-reviewed facts, preferences, boundaries, commitments, and unresolved threads
- End-to-end encrypted sync of small derived context packets; raw transcripts remain local by default

### Model-backed assistance

- Suggestions grounded only in user-approved context
- Explanation of which context influenced a draft
- Strict no-send tool boundary
- Evaluation for manipulation, stereotyping, sensitive inference, and relationship overreach
- Cost, latency, redaction, retention, and deletion controls

### Real matching network

- User-controlled discoverability by relationship type
- Mutual introduction requests instead of a swipe feed
- Resonance and friction narratives without a universal score
- Safety review, age gating, moderation, rate limits, and abuse response

## Release gates

- Unit and device tests prove unapproved fields cannot leave the profile boundary.
- Device tests prove the extension inserts but cannot autonomously send.
- Both humans approve the exact introduction payload.
- Delete and revoke paths work before real accounts are enabled.
- App Privacy answers match verified data flows.
- External TestFlight begins invite-only with a small trusted cohort.
