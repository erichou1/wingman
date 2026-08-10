# Wingman — two-minute script

Read it out loud twice before you present. Total is about 2:00, of which 30 seconds is the ad
playing while you say nothing. Roughly 210 spoken words.

---

**SLIDE 1 — Wingman** · 0:00

> We're Wingman. Your agent goes on the first date.

*(Beat. Advance.)*

---

**SLIDE 2 — The ad** · 0:08

> We made a commercial. It's thirty seconds.

*(Play it. Do not talk over it. Do not explain the joke afterwards.)*

---

**SLIDE 3 — The problem** · 0:40

> So right now, you're judging an entire person off six photos and "I love to travel." Every dating app on earth ranks profiles. And a profile is the least interesting thing about anybody.

---

**SLIDE 4 — How it works** · 0:54

> Wingman does the awkward part for you.
>
> You connect your ChatGPT or Claude export, so your agent learns *you*, not your bio.
>
> Then, before you ever see a card, your agent has already had the conversation with theirs. Four turns, only about things you've both approved.
>
> Your deck is ranked by how that conversation went.

*(Slow down on "before you ever see a card." That's the idea people remember.)*

---

**SLIDE 5 — The moment** · 1:22

> And if you both swipe right, you get to read it.
>
> Two AIs talked about you behind your back, and now it's a receipt. Every line cites a field you approved. That's the difference between this feeling fair and feeling creepy.

---

**SLIDE 6 — How it scores** · 1:42

> One technical choice worth calling out. We rank by the weaker direction, not the average. Someone who's a ten to you but a two back loses to a six and a six. That's the whole reason the number moves.

---

**SLIDE 7 — Close** · 1:55

> Everyone else sorts profiles. We rehearse the conversation.
>
> The iOS app and the gateway are live today. Come find us, and bring your ChatGPT export.

---

## If you get asked

**"Did you actually run that benchmark?"**
> Not yet. Those are targets. The benchmark on the chart is CRRS on the Libimseti dating split, which is the standard public set for reciprocal matching, and it's what we run against next.

Say it plainly. It is a completely normal hackathon answer. Bluffing is the only version of this that hurts you.

**"Isn't reading someone's ChatGPT history a privacy nightmare?"**
> It never leaves your side. Your private context stays inside your agent. The only thing that crosses between two people is a transcript where every claim cites a field you explicitly approved.

**"What if the agents just agree with each other?"**
> That's the real failure mode with two language models. We force a structured verdict: each agent has to name something it still doesn't know, and any claim without an approved source gets dropped before scoring.

**"How is this different from Hinge's Most Compatible?"**
> Hinge runs stable matching over stated preferences. That solves one-sidedness, but it still can't tell whether two people will have anything to say to each other. We simulate the conversation and rank on that.

## Cuts, if you're running long

Drop slide 5 to one sentence: "And if you both swipe right, you get to read the whole thing."
Never cut the ad or the benchmark slide.
