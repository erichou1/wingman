# Render Workflow integration

Wingman now has a Render-backed reply path. The iOS app sends a reply request to the `wingman-gateway` web service. The gateway starts the `generateReplyDrafts` Render Workflow task. That task fans out three `draftReply` runs in parallel, one for each tone, and each run calls NVIDIA NIM. The Render API key and NVIDIA API key stay on Render.

## What is in this repo

- `render/workflow/` contains the Render Workflow task definitions.
- `gateway/` contains the small HTTP service that the phone calls.
- `render.yaml` provisions the gateway web service.
- `App/Shared/WingmanCore/RenderReplyClient.swift` calls the gateway when `RENDER_WORKFLOW_URL` is configured.
- `NIMReplyAssistant` keeps the existing direct-NIM path as a local fallback when that setting is left at its placeholder value.

The Render Workflows beta does not support workflow services in Blueprints. Create the workflow service separately in the Render Dashboard. The root `render.yaml` manages the gateway only.

## Local workflow run

Install the Render CLI and dependencies:

```sh
brew install render
cd render/workflow
npm install
```

Start Render's local task server:

```sh
NVIDIA_API_KEY=nvapi-your-key render workflows dev -- npm start
```

In another terminal, trigger the root task with the included request:

```sh
cd render/workflow
render workflows tasks runs start \
  wingman-replies/generateReplyDrafts \
  --local \
  --input="[$(python3 -c 'import json; print(json.dumps(json.load(open("demo-request.json"))))')]"
```

The local task server executes the same task graph used in production. It stores runs and results in memory while the server is running.

## Local gateway run

With the local task server still running, start the gateway in another terminal:

```sh
cd gateway
npm install
RENDER_API_KEY=local \
RENDER_USE_LOCAL_DEV=true \
RENDER_TASKS_URL=http://localhost:8120 \
RENDER_WORKFLOW_TASK=wingman-replies/generateReplyDrafts \
npm run dev
```

Then send a request:

```sh
curl -s http://localhost:10000/v1/reply-drafts \
  -H 'Content-Type: application/json' \
  --data-binary @../render/workflow/demo-request.json
```

The response contains three drafts and the Render task run ID.

To point an iOS Simulator build at this local gateway, set this in `Secrets.xcconfig`:

```xcconfig
RENDER_WORKFLOW_URL = http://127.0.0.1:10000
```

The client accepts HTTP only for `localhost` and `127.0.0.1`. A physical iPhone needs an HTTPS gateway URL, so use the deployed Render gateway for the hackathon demo.

## Production setup

1. Push this repository to GitHub.
2. In Render, create a new Workflow service from this repo with root directory `render/workflow`.
3. Use Node as the runtime, `npm install && npm run build` as the build command, and `npm start` as the start command.
4. Add `NVIDIA_API_KEY` to the Workflow service. Optionally add `NVIDIA_MODEL`.
5. Name the Workflow service `wingman-replies`, or set the resulting task slug in `RENDER_WORKFLOW_TASK`.
6. Apply `render.yaml` to create the `wingman-gateway` web service.
7. Add the Render API key to the gateway as `RENDER_API_KEY`.
8. Set the gateway's `RENDER_WORKFLOW_TASK` to the exact slug shown on the Workflow service's Tasks page.
9. Set `RENDER_WORKFLOW_URL` in `Secrets.xcconfig` to the gateway URL, run `xcodegen generate`, and rebuild the app.

The gateway accepts an optional `WINGMAN_GATEWAY_TOKEN`. If you set it, the phone client also needs a matching Authorization header implementation before requests will succeed. For a hackathon demo, keep the endpoint protected by an unguessable gateway URL or add authentication before sharing it publicly.

## Verification

Workflow type-check:

```sh
cd render/workflow && npm install && npm run build
cd ../../gateway && npm install && npm run build
```

The existing Swift checks remain unchanged:

```sh
cd /Users/eric/wingman
swift build
swift run wingman-core-selftest
swift run wingman-history-selftest
```
