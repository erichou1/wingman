import Foundation

/// Two hardcoded accounts so the swipe, match, and Match Reveal flows can be
/// demonstrated end to end before real identity exists.
///
/// Signing in with one account's email seeds that person's profile and their
/// ChatGPT context, and seeds the *other* account as a discovery candidate —
/// which is the minimum needed to show two agents meeting.
///
/// The split between the two data sources here is deliberate and is the thing
/// the demo is meant to make visible:
///
/// - `profile` is what the person filled in themselves, and its fields are
///   approved, so they flow to the gateway and into an agent card.
/// - `chatGPTContext.proposed*` is what the crawl inferred. It is **not** in the
///   profile. It arrives as memories and staged suggestions and stays out of
///   `publicSnapshot` until the person approves each field.
///
/// Replace a `chatGPTContext` literal with a packet decoded from a real export
/// and nothing else in the app changes. See `docs/CHATGPT_CONTEXT_CRAWL.md`.
public struct DemoAccount: Sendable, Identifiable {
  public var id: UUID { profile.id }
  public let email: String
  public let profile: HumanProfile
  public let chatGPTContext: ChatGPTContextPacket

  public init(email: String, profile: HumanProfile, chatGPTContext: ChatGPTContextPacket) {
    self.email = email
    self.profile = profile
    self.chatGPTContext = chatGPTContext
  }
}

public enum DemoAccounts {
  /// Stable IDs so the two accounts keep referring to each other across
  /// relaunches — a fresh `UUID()` per launch would orphan seeded candidates,
  /// insights, and consents in saved state.
  private static let ericID = UUID(uuidString: "E71C0000-0000-4000-A000-000000000001")!
  private static let julianID = UUID(uuidString: "3011A000-0000-4000-A000-000000000002")!
  private static let evanID = UUID(uuidString: "E7A40000-0000-4000-A000-000000000003")!

  private static func date(_ epoch: TimeInterval) -> Date { Date(timeIntervalSince1970: epoch) }

  public static let eric = DemoAccount(
    email: "eric@gmail.com",
    profile: HumanProfile(
      id: ericID,
      displayName: "Eric",
      bio:
        "Currently speed-running code in my Snoopy tee with 0ms delay. My headphones are strictly for blocking out merge conflicts. Swipe right if you want to pair-program our future.",
      lookingFor: [.friendship, .newConnection, .community],
      values: ["Precision", "Curiosity", "Follow-through"],
      interests: ["Competition math", "ML research", "Building tools", "Hackathons"],
      lifestyle: ["Long focused blocks", "Late-night debugging", "Small group dinners"],
      communicationStyle: "Direct, specific, allergic to hand-waving",
      boundaries: ["Deep work in the morning", "No pressure to reply instantly"],
      approvedFields: Set(ProfileField.allCases)
    ),
    chatGPTContext: ChatGPTContextPacket(
      accountEmail: "eric@gmail.com",
      exportGeneratedAt: date(1_786_233_600),  // 2026-08-09
      conversationCount: 412,
      userTurnCount: 3_847,
      earliestConversationAt: date(1_710_201_600),  // 2024-03-12
      customInstructions: [
        "I want precise, technical answers with the reasoning shown, not summaries.",
        "Tell me when something is wrong or uncertain instead of agreeing with me.",
      ],
      topics: [
        .init(name: "Erdős problems and additive combinatorics", conversationCount: 74, lastDiscussedAt: date(1_786_147_200)),
        .init(name: "Diffusion models and inverse problems", conversationCount: 51, lastDiscussedAt: date(1_785_974_400)),
        .init(name: "iOS and Swift app work", conversationCount: 38, lastDiscussedAt: date(1_786_233_600)),
        .init(name: "College applications and essays", conversationCount: 29, lastDiscussedAt: date(1_785_628_800)),
        .init(name: "Knowledge management and note systems", conversationCount: 22, lastDiscussedAt: date(1_785_456_000)),
        .init(name: "Olympiad and competition problems", conversationCount: 19, lastDiscussedAt: date(1_785_283_200)),
      ],
      recurringEntities: ["Erdős 1054", "AFDPS", "Obsidian", "InverseBench", "Wingman"],
      cadence: .init(conversationsPerWeek: 8.4, averageUserTurnLength: 340, mostActiveHour: 23),
      proposedInterests: ["Number theory", "Generative modeling", "Note-taking systems"],
      proposedValues: ["Rigor", "Independence"],
      proposedBio:
        "Spends most of his time on hard open problems and the tooling around them, and would rather be told he's wrong than agreed with."
    )
  )

  /// Placeholder pending Julian's real export. Every field below is invented
  /// scaffolding so the two-person demo runs; replace the whole
  /// `chatGPTContext` literal when his data arrives.
  public static let julian = DemoAccount(
    email: "julian@gmail.com",
    profile: HumanProfile(
      id: julianID,
      displayName: "Julian",
      bio:
        "Doing the classic \u{201C}thinking about my code, but mostly thinking about lunch\u{201D} pose. Black jacket energy, 100% focused on shipping the MVP before deadline. Let\u{2019}s exchange API keys.",
      lookingFor: [.friendship, .newConnection, .community],
      values: ["Openness", "Craft", "Showing up"],
      interests: ["Product design", "Startups", "Basketball", "Cooking"],
      lifestyle: ["Early mornings", "Gym most days", "Weekend projects"],
      communicationStyle: "Warm and quick, prefers a call over a long thread",
      boundaries: ["Weeknights are for family", "Say it straight"],
      approvedFields: Set(ProfileField.allCases)
    ),
    chatGPTContext: ChatGPTContextPacket(
      accountEmail: "julian@gmail.com",
      exportGeneratedAt: date(1_786_233_600),  // 2026-08-09
      conversationCount: 168,
      userTurnCount: 1_204,
      earliestConversationAt: date(1_725_148_800),  // 2024-09-01
      customInstructions: [
        "Keep answers short and practical. Give me the option you'd pick.",
      ],
      topics: [
        .init(name: "Product and UI design critique", conversationCount: 41, lastDiscussedAt: date(1_786_147_200)),
        .init(name: "Startup ideas and go-to-market", conversationCount: 33, lastDiscussedAt: date(1_785_974_400)),
        .init(name: "Workout programming", conversationCount: 24, lastDiscussedAt: date(1_786_060_800)),
        .init(name: "Cooking and recipes", conversationCount: 18, lastDiscussedAt: date(1_785_801_600)),
      ],
      recurringEntities: ["Figma", "Los Gatos", "Notion"],
      cadence: .init(conversationsPerWeek: 4.1, averageUserTurnLength: 145, mostActiveHour: 8),
      proposedInterests: ["Interface design", "Fitness", "Home cooking"],
      proposedValues: ["Practicality", "Consistency"],
      proposedBio:
        "Builds and ships quickly, asks for the recommendation rather than the survey, and keeps a steady weekly rhythm."
    )
  )

  /// Placeholder pending Evan's real export, same as Julian's above: the
  /// profile is invented scaffolding so a third person exists in the demo feed.
  public static let evan = DemoAccount(
    email: "evan@gmail.com",
    profile: HumanProfile(
      id: evanID,
      displayName: "Evan",
      bio:
        "Looking at you from an angle that optimizes my personal space. I can lock into code, lock eyes, or just stare into the void while my script finishes compiling. Swipe right if you like low-angle energy.",
      lookingFor: [.friendship, .newConnection, .community],
      values: ["Honesty", "Patience", "Doing the unglamorous part"],
      interests: ["Systems programming", "Rhythm games", "Bubble tea research"],
      lifestyle: ["Nocturnal", "Long hackathon weekends", "Walks to clear a bug"],
      communicationStyle: "Quiet until I have something worth saying, then a lot at once",
      boundaries: ["Let me finish a thought", "No calls before noon"],
      approvedFields: Set(ProfileField.allCases)
    ),
    chatGPTContext: ChatGPTContextPacket(
      accountEmail: "evan@gmail.com",
      exportGeneratedAt: date(1_786_233_600),  // 2026-08-09
      conversationCount: 233,
      userTurnCount: 1_915,
      earliestConversationAt: date(1_719_792_000),  // 2024-07-01
      customInstructions: [
        "Explain the underlying mechanism, not just the fix.",
        "If there is a simpler approach, say so before answering the question I asked.",
      ],
      topics: [
        .init(name: "Rust and memory models", conversationCount: 58, lastDiscussedAt: date(1_786_147_200)),
        .init(name: "Debugging build systems", conversationCount: 37, lastDiscussedAt: date(1_786_060_800)),
        .init(name: "Hackathon project scoping", conversationCount: 26, lastDiscussedAt: date(1_786_233_600)),
        .init(name: "Music and rhythm game charts", conversationCount: 21, lastDiscussedAt: date(1_785_715_200)),
      ],
      recurringEntities: ["Cargo", "Neovim", "Wingman", "boba"],
      cadence: .init(conversationsPerWeek: 5.6, averageUserTurnLength: 210, mostActiveHour: 2),
      proposedInterests: ["Low-level programming", "Developer tooling"],
      proposedValues: ["Thoroughness", "Directness"],
      proposedBio:
        "Goes deep rather than wide, prefers understanding the mechanism to memorising the fix, and does his best work late."
    )
  )

  public static let all: [DemoAccount] = [eric, julian, evan]

  public static func account(forEmail email: String) -> DemoAccount? {
    let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return all.first { $0.email.lowercased() == normalized }
  }

  /// Resolves any signed-in address to an account, falling back to the first
  /// one. Without this a typo or an unlisted address leaves the session with no
  /// profile and no context, which silently skips the ChatGPT import instead of
  /// failing visibly — the demo should never dead-end on the address typed.
  public static func resolve(email: String?) -> DemoAccount {
    guard let email, let match = account(forEmail: email) else { return eric }
    return match
  }

  /// The account seeded as a discovery candidate for `account`, so a single
  /// sign-in produces a two-person feed.
  public static func counterpart(of account: DemoAccount) -> DemoAccount? {
    all.first { $0.email != account.email }
  }

  /// Every *other* account, seeded as discovery candidates. `counterpart`
  /// returns only the first one, which silently hid the third person once the
  /// roster grew past two — it is kept for callers that genuinely want a single
  /// partner, but seeding should use this.
  public static func counterparts(of account: DemoAccount) -> [DemoAccount] {
    all.filter { $0.email != account.email }
  }
}
