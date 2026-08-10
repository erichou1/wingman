# Wingman Product Specification

**Status:** Product direction v3

**Implementation note, 2026-08-09:** The first network slice is live in the repository. `gateway/src/profileStore.ts` persists approved discovery profiles in local SQLite, `WingmanSync.swift` sends only `HumanProfile.publicSnapshot`, and Settings triggers an explicit sync over a same-Wi-Fi gateway. Swipe state, matching, chat, agent ranking, and Match Reveal remain unimplemented.

**Authoritative direction:** Wingman is an agent-powered swipe app for dating and friendship. A user's Wingman agent recommends people, the user swipes, mutual interest opens chat, and the in-app assistant helps with messages. iMessage is optional.

**Repository state inspected:** `f1e8cbf`, plus the uncommitted reply-deck redesign in `App/WingmanApp/HomeView.swift`.

## 1. Product thesis

Wingman makes the familiar swipe experience materially smarter. Instead of a generic profile feed, every person has a user-controlled agent that understands their stated preferences, boundaries, interests, and private swipe feedback. The recommendation system brings the best candidate cards to the user. The user decides with a swipe. A mutual like opens an in-app chat with an optional message helper.

The agent-to-agent layer runs before a card is shown. It compares two narrowly scoped, discoverable agent cards and returns a short, grounded connection hypothesis. It never gets access to raw chat history, private memories, or unapproved personal fields.

### Core loop

```text
Create profile and agent preferences
  -> receive agent-ranked cards
  -> inspect “why this person”
  -> swipe like or pass
  -> mutual like
  -> in-app chat
  -> optional message helper and icebreaker
  -> private feedback improves future cards
```

### Product promise

| User need | Wingman behavior |
|---|---|
| “Show me people worth meeting.” | Rank eligible discovery profiles using reciprocal preferences, shared interests, agent-card reasoning, diversity, and feedback from my own swipes. |
| “Let me choose.” | Give me a simple like or pass decision with an explanation available on demand. |
| “Help when the conversation stalls.” | Offer editable in-app drafts, icebreakers, tone controls, and context I explicitly select. |
| “Keep my agent private.” | Limit pre-swipe reasoning to discoverable fields and preserve owner control over every later disclosure. |

### Safety and agency invariants

1. A person controls their profile, discovery visibility, agent preferences, and match decisions.
2. A pre-swipe agent exchange can use only fields approved for discovery and agent reasoning.
3. A score is an internal ordering signal. The product never presents a claim that two people are objectively compatible.
4. No agent sends messages, contacts someone, or changes a match state.
5. Users can pause discovery, delete data, block, pass, and report at any time.

## 2. What exists in the repository

The current Swift prototype contains useful interaction and data primitives. Its current iMessage framing is an integration experiment rather than the central product flow.

| Existing capability | Role in the swipe product | Source |
|---|---|---|
| Swipeable reply-deck UI | Strong visual starting point for the `For You` candidate-card deck. | `App/WingmanApp/HomeView.swift` |
| Reference-inspired sign-in and AI-agent picker | A pink-to-coral, full-screen entry flow. Sign-in precedes a two-option ChatGPT and Claude picker, which uses vector identification marks. The selection is local prototype state only. | `App/WingmanApp/OnboardingView.swift`, `App/Resources/WingmanApp/Assets.xcassets/`, `Design/THIRD_PARTY_MARKS.md` |
| Profile editor with per-field approval | Foundation for discovery profile visibility and agent-card construction. | `App/WingmanApp/ProfileEditorView.swift`, `App/Shared/WingmanCore/Models.swift` |
| Match engine and explanation text | Prototype for an auditable connection hypothesis. | `App/Shared/WingmanCore/MatchEngine.swift` |
| Reply drafts and fallback | Foundation for the in-app message helper. | `App/Shared/WingmanCore/NIMReplyAssistant.swift`, `ReplyAssistant.swift` |
| Memories and writing style | User-selected context for the message helper. It stays outside pre-swipe retrieval unless explicitly modeled as discoverable. | `App/WingmanApp/MemoriesView.swift` |
| Messages extension and card codec | Optional iMessage sharing and message-assist surface after a match. | `App/WingmanMessages/`, `MessagePayloadCodec.swift` |
| History graph builder | Optional local context experiment. It requires explicit review before any fact reaches agent reasoning. | `Sources/WingmanHistoryCore/` |
| Render and NIM backend path | Reusable inference pattern for agent-card reasoning and chat assistance. It needs authentication, safety, retention, and rate controls. | `gateway/src/server.ts`, `render/workflow/src/index.ts` |

### Major gaps before a real network

- Accounts, identity, age gate, and discovery eligibility
- Server-backed profiles, swipes, matches, chats, and blocks
- A candidate corpus and mutual-like event model
- Agent profiles, consented agent-card generation, and provider connectors
- A recommendation service with two-sided preference modeling
- Moderation, report handling, deletion, export, and abuse prevention
- A real-time in-app chat service

## 3. Required product pages

### 3.1 Consumer app navigation

| Route | Purpose | Release |
|---|---|---|
| `/welcome` | Explain agent recommendations, user control, safety, and age gate. | MVP |
| `/sign-in` | First app screen. Create or recover a Wingman account with a supported identity method. | MVP |
| `/connect-ai` | Immediately follows sign-in. Ask the user to choose and authorize AI accounts, show the approved data scope, and provide disconnect and revocation controls. | MVP |
| `/build-my-agent` | Guided interview that creates profile, interests, preferences, boundaries, and the user's agent card. | MVP |
| `/discovery-settings` | Dating or friendship intent, location policy, age range, visibility, deal breakers, pause state, and recommendation controls. | MVP |
| `/for-you` | Main Tinder-like swipe deck of agent-ranked people. | MVP |
| `/profile/:id` | Full discoverable profile and detailed agent recommendation explanation. | MVP |
| `/why-this-person/:id` | Inspect the grounded recommendation brief, common ground, unknowns, and feedback controls. | MVP |
| `/matches` | Pending, new, active, closed, blocked, and expired matches. | MVP |
| `/match-reveal/:matchId` | Show the constrained agent-to-agent conversation, every shared fact, the grounded connection rationale, and the unknowns that remain before chat. | MVP |
| `/chat/:matchId` | Real-time match chat with an embedded Wingman message helper. | MVP |
| `/message-helper/:matchId` | Full-screen draft, tone, context, icebreaker, and edit flow. | MVP |
| `/my-profile` | Edit profile, photos, discovery card, and agent instructions. | MVP |
| `/agent-settings` | View agent sources, agent-card preview, personalization controls, connector status, and reset. | MVP |
| `/safety` | Block list, reports, visibility controls, help, and contact safety features. | MVP |
| `/privacy-and-data` | Data sources, approved agent facts, export, retention, deletion, and account closure. | MVP |
| `/reply-assist` | Optional standalone text-helper surface. | B |
| iMessage extension | Insert an approved intro card or editable message draft into Messages. | B |
| `/connected-apps` | Future optional messaging, social, or agent-provider connections. | B |

### 3.2 Future business app

| Route | Purpose | Release |
|---|---|---|
| `/organization` | Verify organization, owner roles, domains, and discovery visibility. | D |
| `/business-agent` | Set authorized business-agent capabilities and approved data policy. | D |
| `/capability-card` | Create a discoverable product, partnership, or buyer-seller card. | D |
| `/business-for-you` | Agent-ranked list of eligible organizations. | D |
| `/business-fit-brief/:id` | Explain a potential fit, evidence used, gaps, and proposed discovery call. | D |

## 4. Detailed page requirements

### 4.1 Build My Agent

**Goal:** create a high-signal discovery representation without asking the user to write a résumé.

**Flow**

1. User chooses dating, friendship, or both.
2. Wingman asks a short adaptive interview about interests, values, lifestyle, conversation style, desired connection, boundaries, and first-meet preferences.
3. The agent turns answers into structured fields and a plain-language discovery card.
4. The user approves each field's visibility and whether it can be used by the recommendation system.
5. The user previews what another person sees and what another agent may reason over.

**Required features**

- Photo upload and ordering with explicit visibility choice
- Interest chips plus open-text self-description
- Relationship and friendship intent with distinct preferences
- Deal breakers and hard eligibility constraints
- Adjustable agent voice and recommendation priorities
- “Show me why” preview for the agent card
- Cold-start calibration cards that ask users to like, pass, or explain preference

**Acceptance criteria**

- The initial route is sign-in. A successful session always reaches the AI-account connection screen before profile setup or discovery.
- The connection screen names the provider, requests only an approved scope, and provides a visible disconnect path.
- The local prototype records provider selection only. It must never imply that ChatGPT, Claude, Gemini, Messages, or another external account has actually been authorized until a provider OAuth flow succeeds.
- Private notes never enter the discovery card or recommendation index.
- Editing a visibility setting immediately changes the generated agent card.

### 4.2 Discovery settings

**Goal:** make the feed obey user boundaries before relevance enters the picture.

**Required controls**

| Setting | Behavior |
|---|---|
| Intent | Dating, friendship, or both with separate profile text and filters. |
| Location | Broad region, radius, remote-only choice, and location precision. |
| Eligibility | Age policy, gender preferences where applicable, language, availability, and user-authored hard filters. |
| Visibility | Discoverable, hidden, friends-only future state, or paused. |
| Agent priorities | Adjustable importance of shared interests, lifestyle, conversation style, values, novelty, and practical availability. |
| Feedback mode | Decide whether swipes personalize future recommendations. |

**Acceptance criteria**

- Hard eligibility rules execute before vector retrieval, language-model reasoning, scoring, and card rendering.
- Paused users never appear in new recommendation pools.

### 4.3 For You swipe deck

**Goal:** deliver an immediate, high-quality card experience.

**Card contents**

- Primary photo or visual identity selected by the profile owner
- Name, age where permitted, broad location, intent, and compact discovery description
- Two or three owner-approved interests or values
- “Your agent noticed” statement grounded in specific discoverable facts
- One honest unknown or conversation question
- Like, pass, profile, why, report, and rewind actions

**Interaction model**

| Action | Result |
|---|---|
| Swipe right or Like | Records interest and waits for reciprocal action. |
| Swipe left or Pass | Removes the card from the current feed and records private feedback. |
| Tap Why | Opens the recommendation brief with evidence, uncertainty, and personalization controls. |
| Tap Profile | Opens the full discoverable profile. |
| Rewind | Restores the immediately previous card within a limited allowance. |
| Report or Block | Removes the card and applies the safety policy immediately. |

**Acceptance criteria**

- Cards only include discoverable, policy-approved data.
- The reason on each card maps to specific profile field IDs or approved interest IDs.
- A card cannot expose a hidden preference, raw vector text, private agent instruction, contact method, or raw conversation history.
- A swipe action is durable, idempotent, and recorded with a recommendation-version ID for evaluation.

### 4.4 Why This Person

**Goal:** turn an opaque recommendation into a credible, controllable one.

**Contents**

| Section | Requirement |
|---|---|
| Shared signals | Two to four precise, approved facts that produced the recommendation. |
| Agent view | A concise connection hypothesis using only those facts. |
| Unknowns | One or more things neither agent can establish from the profile. |
| Practical fit | Explicitly separated logistics, intent, and availability signals. |
| Feedback | “More like this,” “Less like this,” “Wrong reason,” and “Do not use this signal.” |
| Privacy | A visible list of the user's own fields that participated in the recommendation. |

**Acceptance criteria**

- The explanation model receives a structured evidence packet rather than the complete private profile database.
- “Wrong reason” disables that feature family for the user's future recommendations until changed in settings.

### 4.5 Matches

**Goal:** convert reciprocal interest into a clean handoff.

**Required features**

- New match celebration with mute option
- Match list with unread state, last activity, and safety status
- Pre-chat “agent connection brief” that gives a two-sentence shared-interest summary and a low-pressure opener
- Unmatch, block, and report from every match row
- Match-expiry rules only if clearly shown before the like action

**Acceptance criteria**

- A chat is created only after mutual interest.
- Unmatching closes chat access and prevents future recommendations between the two accounts unless a new consent flow exists.

### 4.6 Match reveal: “Our agents talked”

**Goal:** make the match feel earned and give both people a transparent explanation before they enter chat.

A mutual match first opens a full-screen reveal. It presents a readable, bounded agent-to-agent exchange built from the pair's discoverable agent cards. The transcript is a product artifact, not hidden model reasoning.

**Reveal layout**

| Surface | Requirement |
|---|---|
| Conversation timeline | Four to six short speech bubbles attributed to “Your Wingman” and “Their Wingman.” Every substantive line carries one or more evidence chips. |
| Shared facts panel | Lists exactly which approved discovery fields each agent used, grouped by owner. |
| Connection moment | States the grounded overlap that made the pair worth showing, with an explicit distinction between fact and agent hypothesis. |
| Honest unknowns | States what the agents could not establish from their cards. |
| Conversation starter | Offers one low-pressure opening prompt or shared activity idea, editable before use. |
| Controls | Start chat, view profile, hide transcript, unmatch, block, and report. |

**Transcript contract**

- Agent messages are generated from structured discovery-card facts, the fixed micro-dialogue task, and a deterministic transcript schema.
- The display contains no hidden chain-of-thought, private ranking weights, latent profile details, or raw model scratchpad.
- Each transcript turn stores its source field IDs and policy version. A user can tap an evidence chip to see the approved profile fact it represents.
- Both users see the same shared transcript. A person sees only profile fields that the other person approved for discovery.
- Editing, hiding, deleting, or expiring a source field removes it from later transcript views according to the retention policy.

**Acceptance criteria**

- Every displayed claim in the transcript resolves to an approved source fact or is labeled as a proposed conversation question.
- The match reveal completes even if the model service fails, using a deterministic evidence summary from the recommendation service.
- Chat remains available after a user hides the reveal. Hiding does not delete the audit record.

### 4.7 In-app chat

**Goal:** make the app useful after the swipe moment.

**Required features**

- Real-time human-to-human messaging
- Typing, delivery, read-state, mute, block, report, and unmatch controls
- Match header with profile preview and first-conversation context
- “Ask Wingman” button that never sends automatically
- Optional shared activity prompt generated from owner-approved overlapping interests
- Safety nudges based on user action, never secret sentiment scoring of the other person

**Acceptance criteria**

- The message helper receives the current draft and only the context explicitly selected by the user.
- Both human messages and AI drafts have clear visual distinction.
- The app logs no raw chat text into the recommendation index.

### 4.8 Message helper

**Goal:** help users move a conversation forward without substituting for them.

**Features**

| Feature | Requirement |
|---|---|
| Draft options | Generate several editable messages from current draft, user-selected tone, and approved match context. |
| Tone control | Direct, warm, playful, curious, concise, and user-authored instruction options. |
| Icebreaker lab | Offer context-grounded opening questions, playful forks, and low-pressure activity suggestions. |
| Explain draft | Show the prompt ingredients and selected facts behind a draft. |
| Rewrite | Shorten, soften, make clearer, add a question, or match a chosen tone. |
| Private memory picker | Let the user choose a personal fact for a single draft without adding it to the discovery profile. |
| Copy and insert | Insert into the chat compose field only. The user taps Send. |

**Acceptance criteria**

- Draft generation fails safely to deterministic local suggestions when the model service is unavailable.
- A private memory selected for a message is scoped to that one draft request unless the user saves a different preference.
- No agent-generated text is sent without a human action.

## 5. The hackathon showcase feature: Reciprocal Agent Recommender

The differentiator should be more than “LLM picks profiles.” Build a recommendation system that has a clear technical story, visible user benefit, and a demo judges can inspect.

### 5.1 Agent card model

Every discoverable user has two separate objects:

| Object | Contents | Who can access it |
|---|---|---|
| Discovery card | Photos, profile facts, approved interests, broad intent, broad location, and public agent summary. | Eligible users and recommendation service. |
| Private agent profile | Fine-grained preferences, private notes, negative feedback, personal memories, and connector configuration. | Owner and tightly scoped personal-agent tasks. |

The system creates a `DiscoverableAgentCard` from approved fields. It stores structured attributes alongside a semantic representation. The user can inspect this card from Agent Settings.

### 5.2 Candidate generation

The recommender begins with strict filtering. It removes the viewer, passed profiles, blocks, reported accounts, paused accounts, unavailable profiles, and candidates outside declared eligibility rules.

From the eligible pool, it performs filtered semantic retrieval using Qdrant's HNSW index over discovery-card embeddings. Filters stay in the database query: intent, age eligibility, location policy, language, availability, discovery visibility, and account safety status.

This produces a candidate pool. Retrieval does not decide card order.

### 5.3 Reciprocal pair evaluation

For each candidate pair, Wingman evaluates several explicit feature families:

| Feature family | Example signals | Constraint |
|---|---|---|
| Directional preference fit | Viewer preferences satisfied by candidate card. | Uses only the viewer's allowed personalization data. |
| Reciprocal fit | Candidate's stated preferences satisfied by viewer card. | Uses only candidate discovery preferences needed for eligibility. |
| Semantic resonance | Similar or complementary owner-approved interests and profile text. | Vector input comes only from discoverable agent cards. |
| Conversation potential | Grounded candidate opening themes and an explicit unknown. | LLM sees structured card facts, never private context. |
| Practical availability | Broad location, intent, availability, and first-meet preference overlap. | No precise live-location data. |
| Trust and safety | Account status, block state, report policy, rate limits, and verified policy fields. | Safety controls can only reduce eligibility. |

The ranker favors pairs where both directional preference signals are strong. This prevents a one-sided “best match” feed from dominating visibility.

### 5.4 Diverse, fair feed assembly

A deck should not show twenty versions of the same candidate. After ranking the pool, Wingman uses a constrained re-ranker:

- **Maximal marginal relevance** reduces repeated interests, repeated lifestyle patterns, and near-duplicate profiles in the next batch.
- **Reciprocal exposure constraints** prevent a small popular group from taking most feed impressions.
- **Freshness rules** limit repeated impressions and make space for new eligible people.
- **Exploration budget** reserves a small portion of cards for candidates whose appeal is uncertain, then learns from the user's response.
- **Contextual bandit updates** learn from likes, passes, profile opens, matches, chat starts, and the user’s “wrong reason” feedback. They update the viewer's feed weights without exporting private signals to another user.

The demo can show the ranker assembling a five-card deck, then update the next card after the judge presses “More like this” or swipes.

### 5.5 Bounded agent-to-agent micro-dialogue

For the strongest candidates, two agents run a short pre-swipe micro-dialogue. This is a compelling visual feature if it is strictly grounded.

**Input:** two `DiscoverableAgentCard` records, policy version, and fixed task.

**Task:** identify at most two grounded points of resonance, one meaningful unknown, and one respectful conversation hook.

**Output:** a `ConnectionHypothesis` with evidence field IDs and a `MatchRevealTranscript` that is held until mutual match.

**Hard limits:** two turns per agent, no external tools, no private fields, no inferred sensitive traits, no contact actions, no compatibility percentage, and no persistence of raw model reasoning beyond the approved transcript, evidence links, and audit metadata.

Before a match, the card displays only a compact recommendation reason. After mutual match, the full structured exchange appears in Match Reveal so both people can see what the agents said and why they connected.

### 5.6 Why this is hackathon-grade

Judges can see a real system rather than a generic chat wrapper:

- A swipe deck whose order changes from explicit user feedback
- A visible reciprocal-fit and diversity explanation for each recommendation
- A live agent-to-agent micro-dialogue that produces evidence-backed connection hypotheses
- A message helper that uses only selected match context and inserts editable drafts
- A privacy inspector showing which fields were used for a given card

## 6. Qdrant design

**Decision:** Qdrant is appropriate for the discoverable-agent-card retrieval layer. It should be introduced after the data model and server filters exist. It does not store raw chat history or generic private memories.

### Collection layout

| Collection | Point type | Payload filters |
|---|---|---|
| `discoverable_agent_cards` | User-approved semantic card embedding. | Account ID, intent, age policy band, broad geography bucket, language, availability, visibility, account status, embedding version, expiry. |
| `approved_interest_facets` | Optional field-level interest vectors for explanation support. | Owner ID, discoverability, allowed use, sensitivity, expiry. |
| `business_capability_cards` | Future organization-approved capability-card embedding. | Organization, sector, buyer or seller intent, visibility, commercial policy, expiry. |

### Retrieval contract

1. The API authenticates the viewer and loads the effective discovery policy.
2. The policy service builds a mandatory Qdrant filter.
3. Qdrant returns a bounded candidate pool and similarity metadata.
4. The application ranker applies reciprocal fit, safety, diversity, freshness, and exploration rules.
5. The connection-hypothesis service receives only the final pair's structured discovery fields.
6. The client receives a card, grounded reasons, one unknown, and no raw embedding content.

### Privacy boundary

- Raw chat, iMessage transcripts, emails, documents, phone numbers, private memories, and unreviewed extracted facts never enter Qdrant.
- Deleting a profile, hiding discovery, blocking, or revoking a field deletes or disables relevant vector points immediately.
- Every vector point includes ownership, visibility, allowed-use, expiry, and embedding-version metadata.
- Similarity distance remains internal. It is never shown as a compatibility percentage or desirability score.

## 7. Data model

| Model | Required fields |
|---|---|
| `Account` | Account ID, identity subject, age-gate result, status, creation time, deletion state. |
| `DiscoveryProfile` | Owner ID, profile version, field values, visibility, allowed uses, effective time, expiry. |
| `DiscoverableAgentCard` | Owner ID, card version, approved field IDs, structured facets, summary text, vector ID, visibility, expiry. |
| `AgentPreferenceModel` | Owner ID, ranked preference dimensions, feedback mode, explicit overrides, model version, reset state. |
| `DiscoveryPolicy` | Intent, eligibility filters, location policy, visibility state, deal breakers, safety constraints. |
| `Recommendation` | Viewer ID, candidate ID, candidate-pool version, ranker version, reason field IDs, diversity state, display time. |
| `Swipe` | Viewer ID, candidate ID, action, recommendation ID, timestamp, undo state. |
| `MutualMatch` | Pair of account IDs, matching swipe IDs, state, creation time, unmatch time. |
| `ConnectionHypothesis` | Pair, approved card versions, evidence field IDs, resonance summary, unknown, opener, policy and model versions, expiry. |
| `MatchRevealTranscript` | Match or candidate pair ID, ordered agent turns, turn-level evidence IDs, viewer-safe display copy, transcript schema version, generation status, retention expiry. |
| `ChatThread` | Match ID, status, read state, mute state, message retention policy. |
| `MessageAssistRequest` | Match ID, user-selected context IDs, draft, tone, model route, retention and deletion state. |
| `SafetyCase` | Reporter, subject, category, evidence policy, status, action, audit timestamps. |

## 8. Backend architecture

| Service | Responsibility |
|---|---|
| Identity and safety service | Authentication, age gate, account state, blocks, reports, rate limits, deletion. |
| Profile service | Profile versions, photo storage, discovery-card generation, visibility enforcement. |
| Discovery service | Candidate filtering, Qdrant retrieval, recommendation caching, feed pagination. |
| Reciprocal ranker | Pair features, diversity re-ranking, fairness constraints, feedback learning. |
| Agent-hypothesis service | Bounded pre-swipe micro-dialogue and grounded explanation generation. |
| Swipe and match service | Idempotent swipes, mutual-match transaction, unmatch, and notification events. |
| Chat service | Real-time messaging, delivery state, block enforcement, retention. |
| Message-helper service | Drafts, tone, selected context, fallback, and audit-safe telemetry. |
| Optional channel service | iMessage card payloads, compose-field draft insertion, future connectors. |

### API families

| Endpoint family | Purpose |
|---|---|
| `/v1/profiles` | Create, edit, preview, and publish profile fields. |
| `/v1/agent-card` | Generate, preview, publish, inspect, and reset the discoverable agent card. |
| `/v1/discovery-policy` | Manage intent, filters, visibility, priorities, and pause state. |
| `/v1/recommendations` | Fetch For You cards and grounded explanations. |
| `/v1/recommendations/:id/feedback` | Record more-like-this, less-like-this, wrong-reason, and do-not-use-signal feedback. |
| `/v1/swipes` | Record like, pass, rewind, block, and report actions idempotently. |
| `/v1/matches` | List matches, unmatch, mute, and retrieve match brief. |
| `/v1/matches/:id/agent-transcript` | Retrieve the evidence-backed Match Reveal transcript, field disclosures, reason, and unknowns. |
| `/v1/chats` | Real-time message transport, read state, block enforcement. |
| `/v1/message-helper` | Generate editable drafts from selected context. |
| `/v1/hypotheses` | Retrieve evidence-backed pre-swipe connection hypotheses. |
| `/v1/privacy` | Agent-card fields, retrieval participation, export, deletion, and reset. |
| `/v1/channels/imessage` | Optional iMessage introduction-card and draft payloads. |

## 9. Build order

| Priority | Deliverable | Demo value |
|---|---|---|
| P0 | Swift swipe deck built from local mock discovery cards and visible Why This Person sheets. | A polished, immediate Tinder-like experience. |
| P1 | Profile interview, discoverable agent card, onboarding, and privacy preview. | Makes the agent concept tangible. |
| P2 | Backend accounts, candidate corpus, swipes, reciprocal match transaction, chat. | Converts UI into a real social loop. |
| P3 | Qdrant filtered retrieval, reciprocal ranker, diversity batch, and feedback controls. | Gives a credible technical recommendation story. |
| P4 | Bounded agent micro-dialogue, evidence-backed Match Reveal transcript, and live connection-hypothesis trace. | The memorable hackathon moment after two users match. |
| P5 | In-app message helper with selected context and deterministic fallback. | Keeps users engaged after the match. |
| B | iMessage extension and optional channel handoff. | Extends distribution without defining the core. |
| D | Organization capability cards and business-fit discovery. | Future commercial path. |

## 10. Evaluation and release gates

### Offline recommendation evaluation

| Metric | Question |
|---|---|
| Eligibility violation rate | Did any card violate a hard filter, block, pause, or visibility rule? Target: zero. |
| Explanation grounding rate | Do displayed reasons map to approved field IDs? Target: 100%. |
| Reciprocal quality | How often do shown cards lead to a like from both sides? |
| Deck diversity | How repetitive are the next ten cards by interest, lifestyle, and profile cluster? |
| Cold-start quality | Do users find an acceptable card before enough swipe data exists? |
| Safety false-negative rate | Are blocked, reported, or unavailable accounts ever recommended? Target: zero. |

### Consumer beta gate

- Profile ownership, age gate, visibility, pause, block, report, export, and deletion work.
- Recommendation filtering runs before Qdrant retrieval and before agent-hypothesis generation.
- Each card has an approved-evidence explanation and a working report control.
- Likes and passes are idempotent; mutual match opens the evidence-backed Match Reveal, then human chat, only once.
- Every transcript turn maps to approved discovery-field IDs and contains no private model reasoning.
- The message helper requires user context selection and never sends a message.
- The recommendation system has a cold-start fallback for users with no feedback history.
- Rate limits, abuse tests, prompt-injection tests, and privacy-deletion tests pass.

### Optional iMessage beta gate

- The extension inserts editable text or an approved card into the compose field.
- The user taps Send in Messages.
- The extension does not enumerate a conversation transcript.
- Any imported Messages-derived fact is reviewed, scoped, and outside the default discovery index.

## 11. Source map

| Area | Repository source |
|---|---|
| Prototype contract | `README.md`, `docs/PRODUCT_PLAN.md` |
| Existing privacy and history boundary | `docs/MESSAGE_HISTORY_ARCHITECTURE.md` |
| Native app and current reply deck | `App/WingmanApp/`, `App/Shared/WingmanDesignSystem/Components/ReplyComposer.swift` |
| Core models, matching, reply logic | `App/Shared/WingmanCore/` |
| Messages extension | `App/WingmanMessages/` |
| Optional Mac history tooling | `Sources/WingmanHistoryCore/`, `Sources/WingmanHistoryCLI/` |
| Existing inference path | `gateway/src/server.ts`, `render/workflow/src/index.ts`, `docs/RENDER_WORKFLOW.md` |
| Existing core tests | `Tests/WingmanCoreTests/WingmanCoreTests.swift` |
