# Rehearsal Search

**Formal name:** Reciprocal Rehearsal Distillation (RRD)
**One line:** Wingman rehearses the conversation before you swipe, then teaches a fast model what the rehearsal learned.

This document specifies Wingman's recommendation algorithm. It replaces section 5 of
`WINGMAN_PRODUCT_SPEC.md`. It is a design document, not an implementation record. Nothing
here is built yet.

---

## 1. The thesis

Every dating app compresses a person into a point in a vector space and then sorts by
distance. That compression is where the product dies. A person is not a point. A person is
a policy: a thing that responds differently depending on who is asking.

Wingman already has the machinery to keep people as policies. Every user has an agent that
holds their private context, and the agent can be asked hypothetical questions. So the
compatibility oracle is not a dot product. It is an experiment:

> Put the two agents in a room under a consent brief, let them talk for four turns, and ask
> each one whether its owner would want a second conversation.

That oracle is good and completely unaffordable. Two LLM agents times every candidate times
every user is quadratic in the population and linear in tokens. So the algorithm is the
answer to one question: **how do you get the quality of an expensive simulation at the price
of a vector search?**

The answer is the same trick that makes modern retrieval stacks work, applied somewhere it
has not been applied. Run the expensive oracle on a few pairs. Use its verdicts as labels.
Distill it into a cheap model. Let the cheap model choose which pairs get the expensive
oracle next. The system bootstraps itself upward.

Three claims a judge can check:

1. **Ranking is not the unit of work. Rehearsal is.** The score of a pair is the outcome of
   a simulated interaction, not the similarity of two profiles.
2. **The expensive model teaches the cheap one.** Rehearsal verdicts are training labels for
   the retriever. Agreement rate between the two is a metric you can put on a slide.
3. **The private data never moves.** The oracle runs inside each person's agent boundary.
   What crosses the boundary is a field-cited transcript, not a profile dump and not an
   embedding of anybody's private context.

---

## 2. Notation

| Symbol | Meaning |
|---|---|
| `C_u` | User `u`'s private context. Never leaves `u`'s agent boundary. |
| `D_u` | User `u`'s approved discovery card. Public to eligible viewers. |
| `A_u` | User `u`'s agent. Reads `C_u` and `D_u`. Can be queried. |
| `q_u` | `u`'s **want** vector. What `u` is looking for. Derived from `C_u` and calibration. |
| `k_u` | `u`'s **offer** vector. What `u` is. Derived from `D_u` only. |
| `θ_u` | `u`'s personal preference head. The only per-user learned parameters. |

The asymmetry matters and is worth saying out loud in the pitch. `k_u` is built from public
approved fields, so it can be shared and indexed. `q_u` is built from private context, so it
stays home and is only ever used to query. Nobody's private data is ever in an index that
another user touches.

---

## 3. Stage 0: Calibration duels (the cold start)

**Problem.** On day one a user has zero swipes, so there is no preference signal. At a
hackathon the whole database has maybe fifty seeded profiles, so collaborative filtering has
nothing to filter. Every demo you will see solves this by not solving it.

**Mechanism.** The agent generates *hypothetical trait bundles*, not fake people, and asks
its owner to choose between them. Three lines each, no photos, no names, explicitly labelled
as hypothetical:

> **A.** Runs a small business. Books their weekends solid. Would rather host eight people
> than go out to meet eight people.
>
> **B.** Two years into a PhD. Free most evenings, unreachable for a week at a time. Prefers
> one long conversation to five short ones.

The owner picks. Six to twelve of these produce a usable `θ_u`.

**The novel part is which duels get generated.** Maintain an ensemble of `m` preference heads
(cheap: `m` random-init linear heads over frozen sentence embeddings). Generate a candidate
pool of trait bundles, and select the pair where the ensemble maximally *disagrees*:

```
duel* = argmax over pairs (a, b) of   Var over heads i of [ score_i(a) - score_i(b) ]
```

Every question is placed exactly on the current model's decision boundary. This is
Bayesian experimental design applied to onboarding: you are not asking what someone likes,
you are asking the one question whose answer you cannot currently predict.

**Why this is safe to ship.** Trait bundles are not synthetic humans. There is no generated
face, no invented name, no implied real account. A dating app that manufactures fake profiles
is a scandal. A dating app that asks calibration questions is a preference survey with better
question selection. Keep the distinction visible in the UI and say so on stage before a judge
asks.

**Why it demos well.** Six taps, ten seconds, and the want vector visibly moves. Project `q_u`
to 2D and animate it converging while the ensemble variance collapses. That is a real
learning curve on screen in the first fifteen seconds of the demo.

---

## 4. Stage 1: The fast path (retrieval)

Hard eligibility filters first, in the database, never in the model: intent, age policy,
geography bucket, language, availability, visibility, block state, report state, pause state.
Safety can only ever remove candidates, never add them.

Then a two-tower score over the surviving pool:

```
s(u → v) = <q_u, k_v>          how much u should want v
s(v → u) = <q_v, k_u>          how much v should want u
```

Combine them with a harmonic mean, not an arithmetic one:

```
R(u, v) = 2 · s(u→v) · s(v→u) / (s(u→v) + s(v→u))
```

This is a small choice with a large effect and it is very quotable. Under an arithmetic mean
a pair scoring (10, 2) beats a pair scoring (6, 6). Under a harmonic mean it loses, 3.3 to
6.0. The harmonic mean is hostile to one-sided attraction, which is the exact failure mode
that makes swipe apps miserable. **We rank by the worst direction, not the average one.**

Stage 1 returns a pool of roughly `K = 20`. It does not decide order.

---

## 5. Stage 2: Rehearsal (the expensive oracle)

For the top `K` only, run a bounded agent-to-agent rehearsal under the connection brief
already specified in the platform-agnostic agent network decision. Four turns total, two per
agent, no tools, no private fields, every claim cited to an approved discovery-field ID.

Each agent independently emits a structured verdict, never prose:

| Field | Meaning |
|---|---|
| `p` | Probability its owner would want a second conversation. |
| `confidence` | How much the rehearsal actually resolved. |
| `unknown` | One named thing the cards could not answer. |
| `hook` | One grounded, specific opener. |

The rehearsal score combines both verdicts, again by harmonic mean:

```
G(u, v) = H(p_{u→v}, p_{v→u}) · (1 − λ · unresolved(u, v))
```

### 5.1 The surprise term, which is the interesting bit

Before the rehearsal, each agent has a prior `p⁰` from the card alone. After, it has a
posterior `p¹`. Define

```
σ(u, v) = | p¹ − p⁰ |
```

`σ` is how wrong the profile was. High `σ` means the card and the conversation disagree,
which is precisely the case that every similarity-based recommender gets wrong and cannot
detect. So `σ` does two jobs:

- **It allocates compute.** Rehearse first where the fast model is least certain, because
  that is where rehearsal changes the answer. Pairs the towers already agree on do not need
  the expensive path.
- **It is the product's best line.** "The profile said 6. The rehearsal said 9. The deck
  reordered." Show that happening live and you have the demo.

### 5.2 Making the rehearsal not lie to you

Two LLMs asked to evaluate a match will agree with each other and rate everything highly.
This is the known failure mode and a sharp judge will ask about it. Four defenses, all cheap:

1. **Forced choice, not absolute scores.** Agents rank candidates against each other, not on
   a 1 to 10 scale. Relative judgments from language models are far better calibrated than
   absolute ones.
2. **A mandatory named unknown.** A verdict without a specific unresolved question is
   rejected and re-run. This makes agreeableness structurally expensive.
3. **Citation enforcement.** Every claim carries a field ID. A claim without a source is
   dropped before scoring, so the agent cannot invent common ground.
4. **Calibration check.** Rehearsal `p` versus realized mutual-match rate, plotted. If the
   curve is flat, the oracle is decorative and you should say so rather than ship it.

### 5.3 It pays for itself twice

The rehearsal transcript *is* the Match Reveal artifact. You are not building a scoring
system and a reveal feature. You are building one thing and showing it at two different
moments: withheld before the match, disclosed after. That is already the decided product
direction, and this algorithm makes it load-bearing rather than cosmetic.

---

## 6. Stage 3: Distillation (the loop that makes it a system)

Rehearsals produce labeled pairs. Train the towers to predict the oracle:

```
L = Σ over rehearsed pairs ( R(u,v) − G(u,v) )²
  + Σ over real outcomes  CE( R(u,v), mutual_match )
  + regularizer on θ_u
```

The cheap model chases the expensive one. Over time the towers learn the patterns that only
showed up in conversation, and rehearsal shifts from discovery to confirmation.

**The metric to put on the slide: oracle agreement@K.** The fraction of the rehearsal top-5
that the towers already had in their top-5. It starts near chance. It should climb. When it
is high, you can cut rehearsal volume and the system gets cheaper the more it is used, which
is the opposite of how LLM products normally scale. That inversion is a strong closing line.

---

## 7. Stage 4: Allocation, not sorting

Sorting each user's deck independently produces the 80/20 collapse that every dating app has:
a small set of profiles absorbs most of the attention, everyone else sees an empty inbox, and
the market fails on both sides.

Deck assembly is therefore a constrained allocation, solved across all viewers in a cycle:

```
maximize    Σ_{u,v} x_{uv} · G(u,v)
subject to  Σ_v x_{uv} = deck_size        each viewer gets a full deck
            Σ_u x_{uv} ≤ B_v              each candidate has an attention budget
            x_{uv} ∈ {0, 1}
```

A greedy auction solve is fine. The budget `B_v` is a congestion price: showing an
over-subscribed candidate costs more, so they only appear where `G` is genuinely high.

The line: **sorting maximizes impressions, allocation maximizes matches.** Ranking is a
one-sided objective in a two-sided market, and a two-sided market needs a clearing mechanism.
Nobody else in that room will be solving an assignment problem.

---

## 8. Stage 5: The curiosity budget

Two of ten deck slots are chosen not by `G` but by expected information gain about `θ_u`:
the candidates where the preference ensemble disagrees most. These cards exist to learn you,
not to please you.

Wingman labels them in the UI. "This one is a guess. Tell us if we are wrong." Honest
exploration is better product and better ethics than silently spending a user's attention on
a bandit arm, and it converts a cost into a trust signal.

---

## 9. Privacy, stated precisely

Say this exactly, because it is the strongest technical claim in the system and it is true:

> There is no central index of anyone's private data. The want vector `q_u` is derived from
> private context and never leaves `u`'s agent boundary. The offer vector `k_u` is derived
> only from fields `u` approved for discovery. Matching happens by querying with a private
> vector against an index of public ones. The rehearsal runs inside the agent boundary and
> emits only a field-cited transcript.

Wingman gets the benefits usually claimed for federated learning without any federated
learning infrastructure, because the asymmetry falls out of the query-versus-key split rather
than being bolted on. That is a real architectural result, not a policy promise.

---

## 10. What is actually novel

The honest version, for the write-up and for a judge who works in the field:

| Component | Prior art | What is new here |
|---|---|---|
| Two-tower retrieval | Standard everywhere | The want/offer asymmetry as a privacy boundary, not just a modeling convenience |
| Reciprocal ranking | Studied in reciprocal recommender literature | Harmonic mean as an explicit anti-one-sidedness objective |
| Active preference elicitation | Dueling bandits, Bayesian experimental design | Applied to dating cold start via trait bundles instead of synthetic profiles |
| LLM-as-judge distilled into a retriever | Standard in search reranking and RLAIF | Applied to a two-sided social market, where the "judge" is a simulated interaction between two parties rather than a single evaluator |
| Exposure-constrained allocation | Fair ranking literature | Coupled to a simulated-interaction score rather than predicted click rate |

The genuinely new composition is **the expensive oracle being a two-agent simulation of the
relationship rather than a model scoring a document, and that simulation's own uncertainty
`σ` deciding where compute goes.** No recommender allocates its compute by "how wrong is the
profile likely to be." That framing is the paper, if you ever write one.

---

## 11. Where this is weak

Know these before a judge finds them.

- **Distillation needs data you will not have.** At fifty seeded profiles the towers are
  effectively untrained. In the demo, use frozen sentence embeddings plus the learned
  personal head, and describe the loop as designed and seeded rather than converged. Do not
  claim a trained model.
- **Allocation is a formality at demo scale.** Fifty users do not congest. Show it on a
  simulated population of ten thousand instead, side by side with sort-by-score, with a
  Gini coefficient on match distribution. That simulation is a two-hour build and it is the
  most convincing slide in the deck.
- **Rehearsal agreeableness is a real risk.** Section 5.2 mitigates it. It does not eliminate
  it. If the calibration curve comes out flat, say the oracle is currently decorative.
- **Latency.** Four turns of agent dialogue per pair is seconds, not milliseconds. Rehearse
  the top 3 live and the rest on a background queue, or pre-rehearse the demo accounts and be
  clear that you did.
- **Trait bundles can encode bias.** Generated calibration questions will drift toward
  stereotype unless the generator is constrained to the approved-field vocabulary. Constrain
  it, and audit the duel pool by hand before the demo.

---

## 12. Demo script, ninety seconds

1. **Calibration.** Six duels, ten seconds. The want vector visibly converges in a 2D
   projection while ensemble variance collapses. "It just asked me six questions and it
   already knows something."
2. **Deck.** Cards appear with a two-sided reciprocity bar, both directions visible. Point at
   a card that is 9 toward you and 3 back. "Every other app puts this one first. We bury it."
3. **Rehearse.** Tap one card. The agent dialogue streams, field chips light as they are
   cited, and it ends with a probability, a confidence, and one honest unknown. **The deck
   reorders.** "The profile said 6. The conversation said 9."
4. **Match.** Swipe, mutual match, Match Reveal shows the same transcript that produced the
   score. Nothing new is generated. The reveal is the receipt.
5. **Fairness.** Cut to the ten-thousand-user simulation. Sort-by-score versus allocation,
   Gini on match distribution. "Sorting maximizes impressions. We maximize matches."
6. **Close.** Oracle agreement@K climbing over the seeded run. "The expensive model is
   teaching the cheap one. This gets cheaper the more people use it."

---

## 13. Build order, if it gets built

| Order | Piece | Effort | Demo value |
|---|---|---|---|
| 1 | Calibration duels with ensemble disagreement selection | Low | Very high |
| 2 | Two-tower scoring with harmonic reciprocity | Low | High |
| 3 | Rehearsal with structured verdicts and `σ`-driven reorder | Medium | Very high |
| 4 | Allocation on a simulated population | Low | High |
| 5 | Curiosity slots with visible labels | Low | Medium |
| 6 | Distillation loop | High | Low live, high on the slide |

Items 1 through 4 are the demo. Item 6 is the story.

## Related

`WINGMAN_PRODUCT_SPEC.md`, `PROFILE_SYNC.md`, `CHATGPT_CONTEXT_CRAWL.md`
