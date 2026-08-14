<div align="center">

# DSH Island

**A small, always-visible macOS status island for every DeepSeek Harness session.**

[![CI](https://github.com/ChuanTianML/dsh-island/actions/workflows/ci.yml/badge.svg)](https://github.com/ChuanTianML/dsh-island/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/ChuanTianML/dsh-island?display_name=tag)](https://github.com/ChuanTianML/dsh-island/releases/latest)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-111827?logo=apple)](https://support.apple.com/macos)
[![MIT](https://img.shields.io/badge/license-MIT-55d7ff)](LICENSE)

[简体中文](README.zh-CN.md)

<img src="docs/assets/dsh-island-desktop.png" width="900" alt="DSH Island floating above a privacy-safe synthetic developer workspace">

<sub>Every screenshot and recording uses deterministic synthetic sessions—never a personal desktop, path, account, or live conversation.</sub>

</div>

DSH Island lets you return to your editor while several [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) Agents keep working. Its collapsed capsule answers what matters immediately: whether a session needs you, how many signals are active, and whether DSH is reachable. One click reveals the complete session list.

It is an independent native companion that connects to the published DSH Web API. It does not run inside the Harness process, so there is no `cordis.yml` entry to add. Start DSH Web, open DSH Island, and the two work together. It is a community project, not an official DeepSeek product.

<div align="center">
  <img src="docs/assets/dsh-island-demo.gif" width="900" alt="Privacy-safe demo: three sessions working, one session requests attention, and the island expands to show the fleet">
</div>

## What it shows

- All non-blank sessions from the authoritative `session.list` baseline.
- Live attention, failure, running, recently completed, idle, and offline states.
- Pending approvals and questions without exposing their contents in the collapsed capsule.
- Todo progress only when DSH publishes a non-empty Todo projection.
- Descriptive phases and coarse tool categories when no numeric progress exists.
- Parent/subagent families, background-job counts, elapsed time, and session deep links.
- A menu-bar recovery surface for show/hide, reconnect, privacy mode, settings, and quit.

The signal rail is a compact map of the visible fleet. Amber means human input, coral means failure, cyan means working, mint means recently completed, and gray means idle or offline.

<div align="center">
  <img src="docs/assets/dsh-island-collapsed.png" width="400" alt="DSH Island collapsed capsule">
</div>

## Truthful progress

DSH does not expose a universal percentage or ETA for an Agent run. DSH Island therefore keeps execution state and progress separate:

| Source | Presentation |
| --- | --- |
| `session.list` / `host/session-status` | Authoritative running state |
| Non-empty `todos` projection | Determinate completed/total rail |
| Session events | Descriptive activity such as reasoning or editing files |
| No Todo projection | Indeterminate working state; no invented percentage or ETA |

Connected priority is `needs attention → failure → running → completed → idle`. A failed baseline makes the whole island offline because its live state can no longer be trusted.

## Install

### Manual install

1. Download `DSH-Island-0.1.0-macOS-universal.zip` from the [latest release](https://github.com/ChuanTianML/dsh-island/releases/latest).
2. Optionally download the adjacent `.sha256` file and run `shasum -a 256 -c DSH-Island-0.1.0-macOS-universal.zip.sha256`.
3. Unzip it and move **DSH Island.app** to Applications.
4. Start DSH Web, then open DSH Island. The default endpoint is `http://127.0.0.1:3080`.

The 0.1 release is ad-hoc signed, not Apple-notarized. On first launch, macOS may require Control-clicking the app and choosing **Open**. The release runs natively on both Apple silicon and Intel Macs.

Typical DSH commands are:

```sh
npx @deepseek-ai/dsh web

# If dsh is already installed globally:
dsh web

# From a DeepSeek Harness source checkout:
pnpm dsh web
```

No configuration is required when DSH uses the default loopback endpoint. Open Settings from the island gear or menu bar when you need to change a preference:

| Setting | Purpose |
| --- | --- |
| DSH endpoint | Connect to a different local port or trusted Host |
| Allow a non-loopback endpoint | Required before any remote address is accepted |
| Privacy mode | Alias titles and hide Todo text, tool names, errors, and connection details |
| Launch at login | Register the app with macOS login items |
| Reset island position | Return the panel to its default display-relative position |

Non-loopback endpoints are refused until you explicitly enable them; only connect to a remote DSH Host you trust.

Clicking a row opens `?session=<id>`. The Web UI opens safely without extra software; exact session selection is added by the optional community [dsh-deeplink](https://github.com/qyw233/dsh-deeplink) plugin.

### Install with a coding agent

A coding agent can download, verify, install, launch, and configure the app. Paste this prompt into an agent running on the target Mac:

```text
Install DSH Island v0.1.0 from https://github.com/ChuanTianML/dsh-island/releases/tag/v0.1.0 on this Mac.

1. Require macOS 13 or later. Download the universal ZIP and its .sha256 file, then verify them with shasum -a 256 -c.
2. Check whether /Applications/DSH Island.app already exists. Ask me before replacing an existing installation.
3. Move the verified app to /Applications. Do not bypass Gatekeeper or change macOS security settings; if first launch requires Control-click → Open, hand that step back to me.
4. Start DeepSeek Harness Web with npx @deepseek-ai/dsh web unless it is already running.
5. Open DSH Island and use its Settings UI to keep the default http://127.0.0.1:3080 endpoint. Ask before enabling a non-loopback endpoint or changing privacy-related settings.
6. Confirm that the island reports a connected DSH state and show me the final configuration. Do not collect or upload any real session title, path, account detail, or desktop screenshot.
```

## Privacy and safety

- Read-only: the app cannot approve, answer, steer, cancel, queue, or edit a session.
- Loopback-only by default; remote endpoints require a deliberate settings change.
- Privacy mode aliases titles and removes Todo text, unknown tool names, errors, and connection details at the state-engine boundary.
- Tool arguments are never retained for presentation.
- No analytics, telemetry, cloud relay, credential storage, or model-context injection.

DSH itself can execute powerful Agent actions. Do not expose an unauthenticated DSH Host to an untrusted network.

## Build and test

Requirements: macOS 13 or later and Xcode 16 or a compatible Swift 6 toolchain.

```sh
swift test
swift build -c release -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
./scripts/build-app.sh
```

The packaging script builds a universal application, generates the icon, applies an ad-hoc signature, and writes the app and ZIP to `dist/`.

Run the deterministic visual fixture without a DSH Host:

```sh
swift run dsh-island --demo-working
swift run dsh-island --demo-expanded
```

The committed community media is rendered from the same synthetic fixtures. Run `./scripts/render-marketing-assets.sh` to regenerate the social preview, desktop scene, and GIF source frames. See [`docs/marketing/README.md`](docs/marketing/README.md) for its privacy rules.

See [product design](docs/product-design.md), [architecture](docs/architecture.md), and the [0.1 validation record](docs/validation.md) for the state semantics and verification evidence.

## Scope

Version 0.1 targets macOS. Windows/Linux surfaces, interactive approvals, transcripts, sounds, avatars, pet skins, fabricated ETA, and model steering are intentionally outside this release.

Contributions are welcome; start with [CONTRIBUTING.md](CONTRIBUTING.md). DSH Island is available under the [MIT License](LICENSE).
