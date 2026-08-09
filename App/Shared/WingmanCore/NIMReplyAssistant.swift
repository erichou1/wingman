import Foundation

/// LLM-backed replacement for `ReplyAssistant`. Callers should catch any
/// thrown error and fall back to `ReplyAssistant.suggest(for:)` so a NIM
/// outage (missing key, network failure, non-2xx) never leaves reply
/// generation dead — see `AppModel.generateReplies()` and
/// `MessagesExtensionModel.generateReplies()`.
public enum NIMReplyAssistant {
  public static func suggest(
    for request: ReplyRequest,
    writingStyle: WritingStyleProfile,
    memories: [MemoryFact],
    client: NIMClient = NIMClient()
  ) async throws -> [ReplySuggestion] {
    let incoming = request.incomingMessage.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !incoming.isEmpty else { return [] }

    let system = systemPrompt(relationship: request.relationship, writingStyle: writingStyle, memories: memories)

    async let warm = draft(tone: .warm, request: request, system: system, client: client)
    async let direct = draft(tone: .direct, request: request, system: system, client: client)
    async let light = draft(tone: .light, request: request, system: system, client: client)

    let warmResult = try await warm
    let directResult = try await direct
    let lightResult = try await light
    return [warmResult, directResult, lightResult]
  }

  private static func draft(
    tone: ReplySuggestion.Tone,
    request: ReplyRequest,
    system: String,
    client: NIMClient
  ) async throws -> ReplySuggestion {
    let toneInstruction: String
    switch tone {
    case .warm:
      toneInstruction = "Warm and empathetic tone. Acknowledge feelings before anything else."
    case .direct:
      toneInstruction = "Direct and clear tone. State intent plainly and propose a concrete next step."
    case .light:
      toneInstruction = "Light and low-pressure tone. Keep it brief and easygoing."
    }

    let userPrompt = """
      Incoming message: "\(request.incomingMessage)"
      Context: \(request.context.isEmpty ? "none given" : request.context)
      Goal for this reply: \(request.goal.isEmpty ? "keep the conversation moving" : request.goal)

      \(toneInstruction)

      Write ONLY the reply text the user could send, nothing else — no quotes, no preamble, no explanation.
      """

    let text = try await client.complete(system: system, user: userPrompt)
    return ReplySuggestion(
      tone: tone,
      text: text,
      rationale: "Drafted by NVIDIA NIM in a \(tone.title.lowercased()) tone."
    )
  }

  private static func systemPrompt(
    relationship: RelationshipKind,
    writingStyle: WritingStyleProfile,
    memories: [MemoryFact]
  ) -> String {
    var lines = [
      "You are Wingman, a reply-drafting assistant. You draft a reply for the user to review and send themselves — you never send anything.",
      "This is a \(relationship.title.lowercased()) relationship.",
    ]

    let toneNotes = writingStyle.toneNotes.trimmingCharacters(in: .whitespacesAndNewlines)
    if !toneNotes.isEmpty { lines.append("The user's writing style: \(toneNotes)") }

    let grammar = writingStyle.grammarPreferences.trimmingCharacters(in: .whitespacesAndNewlines)
    if !grammar.isEmpty { lines.append("Grammar preferences: \(grammar)") }

    if !writingStyle.signaturePhrases.isEmpty {
      lines.append("Phrases the user likes to use: \(writingStyle.signaturePhrases.joined(separator: ", "))")
    }
    if !writingStyle.thingsToAvoid.isEmpty {
      lines.append("Avoid: \(writingStyle.thingsToAvoid.joined(separator: ", "))")
    }
    if !memories.isEmpty {
      let recalled = memories.prefix(8).map { "- \($0.text)" }.joined(separator: "\n")
      lines.append("Relevant context the user has saved:\n\(recalled)")
    }

    return lines.joined(separator: "\n")
  }
}
