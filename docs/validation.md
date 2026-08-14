# Validation record

This record captures the release-candidate checks for DSH Island 0.1.0 on 2026-08-14. Commands are listed exactly; transient paths and process identifiers are intentionally omitted.

## Automated checks

- `swift test` passed 28 tests covering RPC decoding, response identity, endpoint trust rules, state precedence, first-run visibility, completion expiry, Todo progress, privacy redaction, subagent grouping, and activity classification.
- `swift build -c release -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors` passed, and the universal packaging build produced one arm64/x86_64 executable.
- `codesign --verify --deep --strict "dist/DSH Island.app"` accepted the ad-hoc signed bundle.
- `lipo -archs "dist/DSH Island.app/Contents/MacOS/DSH Island"` reported `x86_64 arm64`.

## Native UI checks

The packaged application ran in deterministic demo mode. The accessibility tree exposed the aggregate capsule as one button, every session row as a button, and refresh, open, settings, and collapse controls with labels. Visual inspection covered the four simultaneous signal states, determinate and indeterminate progress, the 400-point collapsed capsule, expanded sizing, endpoint validation, and privacy-mode redaction.

The first visual pass found a truncated collapsed headline, excess expanded whitespace, and system-gray progress bars. The final pass used a wider collapsed capsule, content-sensitive expanded height, and state-colored progress rails.

## Current DeepSeek Harness integration

The current DeepSeek Harness source checkout at commit `47f943859bef60e4160492346772ded9b24f765a` ran with a fresh temporary `DSH_HOME` on loopback port 43080. The model base URL was forced to an unreachable loopback port so the check could not make an external model request.

The application established the two published downlink WebSockets plus an HTTP keep-alive connection, displayed the successful empty `session.list` baseline as connected idle, received a real session creation and running/error sequence, and changed to a visible failed-session row with the Host-provided title and bounded error summary. This exercised the current HTTP client-request envelope, response `rpcId` check, `events.host`, and `events.mux` carriers without changing the Harness checkout or the user's normal Harness home.
