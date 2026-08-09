import Foundation

public enum ReplyAssistant {
  public static func suggest(for request: ReplyRequest) -> [ReplySuggestion] {
    let incoming = request.incomingMessage.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !incoming.isEmpty else { return [] }

    let goal = request.goal.trimmingCharacters(in: .whitespacesAndNewlines)
    let context = request.context.trimmingCharacters(in: .whitespacesAndNewlines)
    let subject = shortSubject(from: incoming)
    let goalClause = goal.isEmpty ? "keep the conversation moving" : goal.lowercased()

    return [
      ReplySuggestion(
        tone: .warm,
        text:
          "Thanks for telling me. I hear you about \(subject). Want to talk it through together?",
        rationale: "Acknowledges the message before trying to solve it."
      ),
      ReplySuggestion(
        tone: .direct,
        text:
          "I want to \(goalClause). Can we talk about \(subject) and decide what makes sense next?",
        rationale: "States your intent and asks for a concrete next step."
      ),
      ReplySuggestion(
        tone: .light,
        text: context.isEmpty
          ? "Okay, I’m with you. Tell me a little more about \(subject)?"
          : "I’m with you. Given \(shortSubject(from: context)), should we figure out \(subject) together?",
        rationale: "Keeps the reply low-pressure while inviting more context."
      ),
    ]
  }

  private static func shortSubject(from text: String) -> String {
    let compact =
      text
      .replacingOccurrences(of: "\n", with: " ")
      .split(whereSeparator: \Character.isWhitespace)
      .prefix(12)
      .joined(separator: " ")
    if compact.count <= 90 { return compact }
    return String(compact.prefix(87)) + "…"
  }
}
