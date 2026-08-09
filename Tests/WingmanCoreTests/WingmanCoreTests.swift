import XCTest
@testable import WingmanCore

final class WingmanCoreTests: XCTestCase {
  func testUnapprovedProfileFieldsNeverEnterMatchingSnapshot() {
    let profile = HumanProfile(
      displayName: "Alex",
      bio: "Private biography",
      lookingFor: [.friendship],
      values: ["Kindness"],
      interests: ["Climbing"],
      communicationStyle: "Direct",
      boundaries: ["No last-minute plans"],
      approvedFields: [.displayName, .lookingFor, .values]
    )

    XCTAssertEqual(profile.publicSnapshot.displayName, "Alex")
    XCTAssertEqual(profile.publicSnapshot.values, ["Kindness"])
    XCTAssertNil(profile.publicSnapshot.bio)
    XCTAssertTrue(profile.publicSnapshot.interests.isEmpty)
    XCTAssertNil(profile.publicSnapshot.communicationStyle)
    XCTAssertTrue(profile.publicSnapshot.boundaries.isEmpty)
  }

  func testIntroductionRequiresBothPeople() throws {
    let first = approvedProfile(named: "Alex")
    let second = approvedProfile(named: "Jordan")
    let insight = MatchEngine.compare(first.publicSnapshot, second.publicSnapshot)

    XCTAssertThrowsError(
      try IntroductionFactory.makeCard(
        first: first.publicSnapshot,
        second: second.publicSnapshot,
        insight: insight,
        consent: IntroductionConsent(matchID: insight.id, firstHumanApproved: true)
      )
    )

    let card = try IntroductionFactory.makeCard(
      first: first.publicSnapshot,
      second: second.publicSnapshot,
      insight: insight,
      consent: IntroductionConsent(
        matchID: insight.id,
        firstHumanApproved: true,
        secondHumanApproved: true
      )
    )
    XCTAssertEqual(try MessagePayloadCodec.decode(MessagePayloadCodec.encode(card)), card)
  }

  func testReplyAssistantReturnsThreeEditableDrafts() {
    let drafts = ReplyAssistant.suggest(
      for: ReplyRequest(
        incomingMessage: "Can we talk tomorrow?",
        relationship: .friendship,
        context: "We missed each other this week",
        goal: "Find a time"
      )
    )
    XCTAssertEqual(drafts.count, 3)
    XCTAssertEqual(Set(drafts.map(\.tone)), Set(ReplySuggestion.Tone.allCases))
    XCTAssertTrue(drafts.allSatisfy { !$0.text.isEmpty })
  }

  private func approvedProfile(named name: String) -> HumanProfile {
    HumanProfile(
      displayName: name,
      lookingFor: [.friendship],
      values: ["Kindness"],
      interests: ["Cooking"],
      approvedFields: [.displayName, .lookingFor, .values, .interests]
    )
  }
}
