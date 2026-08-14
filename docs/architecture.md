# DSH Island architecture

## Decision summary

DSH Island is a native macOS companion that consumes the published DeepSeek Harness HTTP/WebSocket API. It does not patch the Harness repository, inject model context, or register model-facing tools.

The native route is intentional. An in-page floating component disappears when the user returns to an IDE, while an Electron shell conflicts with the requirement for a small, low-overhead status surface. SwiftUI and AppKit provide a compact application bundle, a real always-on-top panel, accessibility, multi-Space behavior, and launch-at-login without bundling a browser runtime.

## Modules

```text
DSHIslandCore
  JSONValue             strict JSON decoding without DSH package dependencies
  DSHProtocol           RPC envelopes, session summaries, Host and mux events
  StatusEngine          pure state transitions, ordering, progress and redaction
  DSHClient             read-only POST baseline and downlink WebSocket transport

DSHIslandApp
  IslandViewModel       owns connection lifecycle and publishes UI snapshots
  IslandPanel           borderless floating NSPanel, positioning and resize anchoring
  IslandView            collapsed capsule, signal rail and expanded session list
  Preferences           endpoint, privacy, launch-at-login and reset-position controls
  AppDelegate           accessory-app lifecycle and menu-bar fallback
```

`DSHIslandCore` imports Foundation only. UI code never parses wire JSON and transport code never decides presentation priority.

## Data flow

```text
POST /api/session.list ───────────────┐
WS   /api/events.host ────────────────┼─> DSHClient -> StatusEngine -> IslandSnapshot -> SwiftUI
WS   /api/events.mux ─────────────────┘
                 reconnect + 2s baseline fallback
```

`session.list` is the reconnect baseline. The Host stream supplies session creation, removal, running edges, and host-level Agent failures. The mux stream supplies pending approvals/questions, projection updates, background jobs, and descriptive session events.

The client retains the outer WebSocket message `rpcId`; question requests use it as their stable identity, while approval requests carry their own `approvalId`.

## Engine invariants

- A blank session never appears in an island snapshot.
- A pending approval or question outranks failure and running for the same session.
- A failure outranks running but does not erase the authoritative running bit.
- A completion marker is created only from an observed running-to-idle transition or a completed `turn/end`, never from an initially idle baseline.
- Todo progress is absent unless the list is non-empty and every counted item has a known status.
- Projection updates are accepted only when their sequence is newer than the stored sequence for that key.
- Replaying a requested interaction with the same id is idempotent.
- A resolved interaction removes only its matching request.
- Remote text is treated as display data: titles and summaries are bounded and normalized before entering a snapshot.
- Privacy transformation occurs inside the engine snapshot boundary so no view can accidentally bypass it.

## Network behavior

The default endpoint is `http://127.0.0.1:3080`. The unary request uses the DSH client-request envelope and an `application/json` content type. The WebSocket client accepts text or binary messages, limits each message to 2 MiB, ignores unknown fields, and treats a malformed message as one dropped event rather than a stream-wide failure.

Each downlink WebSocket reconnects independently using exponential backoff capped at five seconds. A two-second list refresh is the recovery baseline and also expires recent-completion markers. A successful list response establishes connectivity even while either stream reconnects. Offline is published only after the baseline request fails; stale session details remain internally available but are not described as live.

## Endpoint trust

Loopback HTTP and HTTPS endpoints are accepted by default. A non-loopback host requires an explicit `allowRemoteEndpoint` preference. The app never sends DSH credentials because the shipped local Web API has no external-client authentication field. Users are warned that exposing DSH itself to an untrusted network exposes Agent capabilities beyond this app.

## Window lifecycle

The app uses accessory activation policy and a borderless `NSPanel` at floating level. It joins all Spaces and remains visible beside full-screen applications. The panel's top edge is invariant during expansion so the visual reads as a capsule unfolding downward.

Saved position records both the screen identifier and normalized coordinates. On launch the position is clamped to the selected screen's visible frame; a missing screen falls back to the primary display's top center.

The menu-bar item is a recovery surface for show/hide, open DSH, reconnect, and quit. It is not the primary status display.

## Verification strategy

### Unit tests

- JSON and RPC envelope decoding, including unknown fields;
- HTTP request envelopes, response identity checks, WebSocket URL conversion, malformed-message isolation, and size limits;
- every state-priority pair and interaction replay/resolution;
- Todo progress, projection sequence ordering and redaction;
- completion expiry and initial-idle behavior;
- parent/child ordering and stable aggregate counts;
- endpoint normalization and loopback policy.

### Integration tests

- URLProtocol-backed tests exercise the unary DSHClient transport, response identity, and endpoint construction;
- deterministic engine and demo fixtures drive multiple sessions through running, attention, completion, failure, privacy, and offline transitions;
- the built app runs in demo mode for screenshot and accessibility inspection;
- a real isolated DSH Web instance verifies the current `session.list`, `events.host`, and `events.mux` wire formats.

### Release checks

- `swift test`;
- release `swift build` with warnings treated as errors;
- application bundle construction and ad-hoc signature verification;
- launch smoke plus screenshot and accessibility-tree inspection;
- ZIP extraction and second launch from the packaged artifact;
- GitHub Actions build on a clean macOS runner.
