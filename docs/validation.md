# Validation record

This record captures the original 0.1.0 checks from 2026-08-14 and the 0.2.0 five-theme update verified on 2026-08-16. Commands are listed exactly; transient paths and process identifiers are intentionally omitted.

## Automated checks

- `swift test` passed 40 tests covering RPC decoding, response identity, endpoint trust rules, state precedence, first-run visibility, completion expiry, Todo progress, privacy redaction, subagent grouping, activity classification, theme resolution and metrics, palette invariants, and the official whale vector.
- `swift build -c release -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors` passed, and the universal packaging build produced one arm64/x86_64 executable.
- `codesign --verify --deep --strict "dist/DSH Island.app"` accepted the ad-hoc signed bundle.
- `lipo -archs "dist/DSH Island.app/Contents/MacOS/DSH Island"` reported `x86_64 arm64`.
- `shasum -a 256 -c DSH-Island-0.2.0-macOS-universal.zip.sha256` accepted the packaged ZIP from inside `dist/`.

## Native UI checks

The packaged application ran in deterministic demo mode under Computer Use. The accessibility tree exposed the aggregate capsule as one button, every session row as a button, and refresh, open, settings, and collapse controls with labels. Visual inspection covered the four simultaneous signal states, determinate and indeterminate progress, collapse and re-expansion, endpoint and privacy controls, all five Appearance radio options, immediate theme switching, and persistence after a quit and relaunch. The test restored Original Signal afterward.

The first visual pass found a truncated collapsed headline, excess expanded whitespace, and system-gray progress bars. The final pass used a wider collapsed capsule, content-sensitive expanded height, and state-colored progress rails.

## Theme-system release checks

`IslandThemeTests` passed for identifiers, fallback resolution, positive and nonnegative metric constraints, palette distinctions, the Editorial light-surface exception, the shared black whale fill, color opacity, and the official whale path. The same deterministic four-session fixture rendered in Original Signal, Quiet Glass, Orbital Deck, Editorial, and Pulse Garden while preserving row order, state text, progress values, actions, and accessibility labels.

The Pulse Garden collapsed completion headline was measured with its installed Avenir Next face: `1 session completed`, `12 sessions completed`, and `999 sessions completed` remain within the title's flexible allocation and 0.82 scale floor. Theme resize completions carry a generation identity so a superseded animation cannot resume position persistence while the current resize is still moving.

Native capture produced `500×454`, `440×384`, `500×398`, `500×436`, and `500×434` expanded images for Original Signal, Quiet Glass, Orbital Deck, Editorial, and Pulse Garden respectively. Every theme image, plus the Original Signal working, collapsed, and expanded compatibility images, passed the alpha-channel corner check before composition. The check compares every corner pixel outside the theme's continuous rounded path, with a 1.5-pixel allowance for Retina downsampling antialiasing, rather than assuming one fixed transparent square for every radius.

A negative PNG fixture kept the former six-pixel probe square transparent but inserted an opaque gray pixel at `(0,6)`, outside a 20-point continuous corner. The path-aware check rejected it before composition.

## Current DeepSeek Harness integration

The DeepSeek Harness checkout used for this integration validation was commit `47f943859bef60e4160492346772ded9b24f765a`. It ran with a fresh temporary `DSH_HOME` on loopback port 43080. The model base URL was forced to an unreachable loopback port so the check could not make an external model request.

The application established the two published downlink WebSockets plus an HTTP keep-alive connection, displayed the successful empty `session.list` baseline as connected idle, received a real session creation and running/error sequence, and changed to a visible failed-session row with the Host-provided title and bounded error summary. This exercised the current HTTP client-request envelope, response `rpcId` check, `events.host`, and `events.mux` carriers without changing the Harness checkout or the user's normal Harness home.

## Community-media privacy check

`./scripts/render-marketing-assets.sh` ran against repository-local fixtures and encoded four shared-interaction frames into a 1200×720, 7.5-second GIF. Product screenshots come from macOS window capture, retain transparent rounded corners, and pass an alpha-channel check that limits every sampled corner-region pixel to 0.01 alpha before composition. The five-theme board is 1600×1000 and the social preview is 1200×630; both compose all five native theme captures. The marketing template applies a second theme-specific rounded clip. The desktop and editor context is synthetic HTML; the DSH Island pixels come from deterministic demo modes with explicit theme identifiers. No live DSH Host, personal desktop, browser profile, home path, account, notification, or session is used.

The final GIF was decoded at one frame per second and representative working, attention, transition, and expanded frames were inspected. Local Vision OCR scanned the 12 publication images plus eight Computer Use evidence captures, covering 564 recognized text candidates with zero sensitive matches. Source, binary-string, and metadata scans found no local username, personal home path, messaging or conversation identifier, email address, credential, or live session text in material selected for publication or the private validation report.
