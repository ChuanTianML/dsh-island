<div align="center">

# DSH Island

**A small, always-visible macOS status island for every DeepSeek Harness session.**

[![CI](https://github.com/ChuanTianML/dsh-island/actions/workflows/ci.yml/badge.svg)](https://github.com/ChuanTianML/dsh-island/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/ChuanTianML/dsh-island?display_name=tag)](https://github.com/ChuanTianML/dsh-island/releases/latest)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-111827?logo=apple)](https://support.apple.com/macos)
[![MIT](https://img.shields.io/badge/license-MIT-55d7ff)](LICENSE)

[简体中文](README.zh-CN.md)

<img src="docs/assets/dsh-island-expanded.png" width="500" alt="DSH Island expanded with attention, failure, working, and completed sessions">

</div>

DSH Island lets you return to your editor while several [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) Agents keep working. Its collapsed capsule answers what matters immediately: whether a session needs you, how many signals are active, and whether DSH is reachable. One click reveals the complete session list.

It is an independent community companion, not an official DeepSeek product.

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

1. Download `DSH-Island-0.1.0-macOS-universal.zip` from the [latest release](https://github.com/ChuanTianML/dsh-island/releases/latest).
2. Unzip it and move **DSH Island.app** to Applications.
3. Start DSH Web, then open DSH Island. The default endpoint is `http://127.0.0.1:3080`.

The 0.1 release is ad-hoc signed, not Apple-notarized. On first launch, macOS may require Control-clicking the app and choosing **Open**. The release runs natively on both Apple silicon and Intel Macs.

Typical DSH commands are:

```sh
dsh web

# From a DeepSeek Harness source checkout:
pnpm dsh --profile web
```

Use Settings if DSH runs on another port. Non-loopback endpoints are refused until you explicitly enable them; only connect to a remote DSH Host you trust.

Clicking a row opens `?session=<id>`. The Web UI opens safely without extra software; exact session selection is added by the optional community [dsh-deeplink](https://github.com/qyw233/dsh-deeplink) plugin.

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
swift run dsh-island --demo-expanded
```

See [product design](docs/product-design.md), [architecture](docs/architecture.md), and the [0.1 validation record](docs/validation.md) for the state semantics and verification evidence.

## Scope

Version 0.1 targets macOS. Windows/Linux surfaces, interactive approvals, transcripts, sounds, avatars, pet skins, fabricated ETA, and model steering are intentionally outside this release.

Contributions are welcome; start with [CONTRIBUTING.md](CONTRIBUTING.md). DSH Island is available under the [MIT License](LICENSE).
