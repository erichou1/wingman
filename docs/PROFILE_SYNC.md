# Profile Sync Gateway

This is the first live network vertical slice for Wingman. It lets the iOS app upload a person's **approved profile snapshot** to a SQLite database running on the developer Mac, then download other approved profiles as discovery candidates.

It supports physical-phone testing on the same Wi-Fi network. It does not yet provide accounts, swipe persistence, reciprocal matches, chat transport, agent ranking, or a cloud database.

## Data boundary

The gateway accepts only these profile fields:

- display name
- dating or friendship intent
- bio, values, interests, lifestyle, communication style, and boundaries when the user approved those fields

The client constructs the request from `HumanProfile.publicSnapshot`. Raw Messages history, private memories, replies, and unapproved profile fields do not enter this API.

## Start the local database and server

From the repository root:

```sh
./Scripts/run-profile-sync-gateway.sh
```

The server listens on port `10000` by default and persists data at `gateway/data/wingman.sqlite`. That database is ignored by Git.

If another process already uses port 10000:

```sh
PORT=10001 ./Scripts/run-profile-sync-gateway.sh
```

The script prints a simulator URL and a same-Wi-Fi phone URL such as:

```text
http://Erics-MacBook-Pro-2.local:10001
```

Keep the process running during a device test.

## Configure the iOS app

Add these values to your local, Git-ignored `Secrets.xcconfig`:

```xcconfig
WINGMAN_SYNC_BASE_URL = http:/$()/Erics-MacBook-Pro-2.local:10001
WINGMAN_GATEWAY_TOKEN = wingman-REPLACE_ME
```

Use the exact hostname and port printed by the script. The simulator can instead use `http:/$()/127.0.0.1:10000`.

Then regenerate and build:

```sh
xcodegen generate --spec project.yml
```

In Wingman, complete the profile approvals, open **Settings**, and tap **Sync approved profile**. The app uploads its public snapshot and replaces the local candidate list with profiles returned by the gateway.

## Optional prototype token

The server accepts unauthenticated requests when `WINGMAN_GATEWAY_TOKEN` is absent. That is acceptable only for a short-lived private LAN test.

To require a shared bearer token, set the same non-placeholder value in the app's `Secrets.xcconfig` and in the server environment before starting it:

```sh
WINGMAN_GATEWAY_TOKEN='your-prototype-token' PORT=10001 ./Scripts/run-profile-sync-gateway.sh
```

Do not commit `Secrets.xcconfig`, the SQLite database, or a real token.

## Device troubleshooting

- Keep the Mac and iPhone on the same Wi-Fi network.
- Use the `.local` hostname printed by the script instead of a changing private IP address.
- If macOS asks whether Node may accept incoming network connections, allow it only for this private development test.
- Ensure another process is not already occupying the configured port.
- The app's Info.plist permits local networking for the prototype. A public deployment must use HTTPS, real account authentication, server-side authorization, rate limits, deletion controls, and a managed database.

## API contract

```text
GET  /healthz
PUT  /v1/profiles/:id
GET  /v1/profiles?exclude=:id
```

`PUT` stores a complete approved snapshot. `GET` returns profiles except the specified viewer. The current server binds to `0.0.0.0` so a phone can reach it over the LAN.
