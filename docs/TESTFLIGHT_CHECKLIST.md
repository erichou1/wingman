# TestFlight Checklist

Wingman is structurally ready for an Xcode archive. Uploading a build and creating App Store Connect records are external release actions and should happen only after the owner confirms the Apple Developer team and bundle identifiers.

## Local prerequisites

- Install the current full Xcode release and select it with `xcode-select`.
- Open Xcode once to install platform components and accept its license.
- Sign into the intended Apple Developer account in Xcode.
- Connect and trust a physical iPhone for the final Messages-extension test.

## Developer portal configuration

Register these identifiers, or replace them consistently in `project.yml` and `WingmanConfiguration` before registration:

- App: `com.naitikgupta.wingman`
- Messages extension: `com.naitikgupta.wingman.messages`
- Shared framework: `com.naitikgupta.wingman.core`
- App Group: `group.com.naitikgupta.wingman`

Enable the same App Group for the app and Messages extension. Use automatic signing initially.

## Required pre-upload verification

1. Regenerate with `xcodegen generate --spec project.yml`.
2. Build the Wingman scheme for an iPhone simulator.
3. Run `WingmanCoreTests`.
4. Run on a physical iPhone and open the containing app once.
5. In Messages, find Wingman in the app drawer.
6. Test compact and expanded presentation styles.
7. Insert each reply tone and confirm nothing sends automatically.
8. Build two approved profiles, test one-sided consent cannot insert a card, then test two-sided consent can.
9. Send a card to another test device and confirm it renders when selected.
10. Test Dynamic Type, VoiceOver labels, dark mode, rotation on iPad, relaunch persistence, and local data deletion.
11. Archive with the Release configuration and run Xcode’s Validate App action.

## App Store Connect draft

- Name: **Wingman**
- Subtitle: **Your relationship copilot**
- Category: **Social Networking**
- Beta description: **Wingman helps you draft thoughtful replies and create consent-based “Meet My Human” introductions inside Messages. It never sends on your behalf.**
- Feedback email: owner must supply
- Privacy policy URL: required before external testing; owner must supply a public URL
- Export compliance: verify again after any encryption or networking dependency is added
- App Privacy: the current beta stores profile and prototype context on-device and does not track; re-audit before upload

## Suggested first cohort

Start with internal testers, then an invite-only external group of 10–25 trusted testers. External groups may require Apple’s TestFlight App Review before invitations become available.

## Build and upload

In Xcode:

1. Set a non-empty Team for all targets.
2. Select **Any iOS Device (arm64)**.
3. Choose **Product → Archive**.
4. In Organizer, choose **Distribute App → App Store Connect → Upload**.
5. Wait for processing, answer export-compliance prompts, attach the build to an internal group, and add beta test notes.

Do not upload until the owner has confirmed the Apple team, final bundle IDs, privacy policy URL, and beta notes.

## Current blockers on this Mac

- `/Applications/Xcode.app` is not installed; only Command Line Tools are selected.
- No trusted iPhone is connected.
- Apple Developer team, App Group registration, and App Store Connect record are not yet configured.
