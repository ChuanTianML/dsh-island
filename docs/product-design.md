# DSH Island product design

## Product statement

DSH Island is a small, always-visible macOS status surface for people running several DeepSeek Harness sessions at once. It answers three questions without requiring the user to reopen the Web UI: whether any session needs attention, how many sessions are working, and which session most recently finished.

It is a professional status instrument, not a desktop pet and not a second chat client.

## Audience and situation

The primary user starts several long-running coding Agent sessions, then returns to an IDE, browser, or document. The DeepSeek Harness sidebar is no longer visible, browser notifications are transient, and repeatedly switching back to the Web UI breaks concentration.

The first release targets macOS 13 or later. It connects to a user-configured DSH Web endpoint, permits loopback hosts by default, and does not require changes to DeepSeek Harness.

## Visual direction

The interface follows an aeronautical-instrument aesthetic: an obsidian capsule, precise signal colors, restrained typography, and a thin segmented signal rail that summarizes the active fleet. The collapsed state deliberately contains one line of information. Detail appears only after expansion.

The memorable element is the signal rail. Each visible session contributes a short segment colored by its state; the highest-priority segment leads. It makes several concurrent Agents legible without turning the island into a dashboard.

### Visual tokens

| Role | Value |
| --- | --- |
| Surface | near-black glass with a subtle blue-black vertical gradient |
| Running | electric cyan `#55D7FF` |
| Attention | warm amber `#FFB84D` |
| Failure | coral red `#FF665E` |
| Completed | mint `#62E6A5` |
| Idle | cool gray `#8993A4` |
| Display type | New York where available; native serif fallback |
| Metrics type | SF Mono where available; native monospaced fallback |
| Motion | short, interruptible springs; no perpetual decorative motion |

## Interaction model

### Collapsed island

The island rests below the menu bar at the top center of the active display. It may be dragged elsewhere and remembers its position.

It shows the highest-priority aggregate:

- `1 needs you` when any approval or question is pending;
- `3 sessions working` while one or more sessions run;
- `1 completed` when a run has just settled and no higher-priority state exists;
- `DSH idle` when connected with no active work;
- `DSH offline` when the endpoint cannot be reached.

The signal rail shows the state mix even when the label reports only the highest-priority class.

### Expanded island

A click expands the capsule downward while preserving its top edge. Session families are ordered by the highest-priority visible member: attention, failure, running, recently completed, then idle. Within a family, the parent is followed by its indented subagents. Blank sessions are never shown.

Each row contains:

- title, falling back to the workspace folder name and then a shortened session id;
- state label and elapsed time when known;
- current in-progress Todo item, current tool category, or a plain phase label;
- a determinate Todo fraction only when the session publishes a non-empty Todo list;
- indentation for a subagent whose parent is also visible.

Clicking a row opens the DSH Web URL with `?session=<id>`. Exact navigation is provided when the community `dsh-deeplink` plugin is installed; without it, DSH still opens safely at its normal landing state.

The expanded toolbar provides refresh, endpoint settings, open DSH, and collapse controls. A menu-bar fallback provides show/hide and quit so the app never becomes impossible to control.

## State priority and progress semantics

Global priority is `offline > attention > failure > running > completed > idle` only when offline means there is no trustworthy live state. While connected, priority is `attention > failure > running > completed > idle`.

The product distinguishes execution state from progress:

- `running` is authoritative because it comes from `session.list` and `host/session-status`;
- Todo progress is authoritative only when the `todos` projection contains items;
- current activity is descriptive and derived from live session events;
- elapsed time is not converted into a percentage or ETA;
- token generation rate is not presented as task progress.

When no Todo list exists, the running indicator remains indeterminate. DSH exposes no general tool-progress event, so displaying an invented percentage would be misleading.

## Privacy and safety

The first release is read-only. It does not answer approvals, stop Agents, edit queues, or write session data. It connects to loopback endpoints by default and refuses a non-loopback endpoint unless the user explicitly enables remote connections in settings.

Session titles may contain sensitive project names. A privacy toggle replaces titles with `Session 1`, `Session 2`, and so on while keeping status counts and progress visible. The collapsed island never shows a session title by default.

No telemetry, analytics, cloud relay, or credential storage is included.

## Accessibility

- Every color state also has text and an icon.
- The collapsed island exposes one concise VoiceOver label with all aggregate counts.
- Rows are keyboard reachable after expansion.
- Reduced Motion disables pulsing and replaces spring morphs with short fades.
- Increased Contrast strengthens the border and removes translucent ambiguity.
- Text remains legible at the system's larger accessibility sizes; the expanded list grows rather than truncating the status label.

## Version 0.1 scope

Included:

- native macOS always-on-top capsule;
- all-session baseline plus live Host and mux streams;
- attention, failure, running, recently completed, idle, and offline states;
- real Todo progress and current-activity summaries;
- expandable session list, subagent indentation, deep-link handoff;
- endpoint, privacy, launch-at-login, position, and visibility settings;
- deterministic demo mode for screenshots and visual verification;
- ZIP application release built by CI.

Not included:

- approving, answering, steering, cancelling, or editing a session;
- transcript rendering;
- Windows or Linux native windows;
- fabricated ETA or percentage;
- pet skins, avatars, sounds, or gamification.

## Acceptance criteria

1. Given two running non-blank sessions, when the app receives the list baseline, then the collapsed island reports two working sessions and the expanded island contains two running rows.
2. Given one running session and one pending approval in another session, when the approval frame arrives, then attention becomes the aggregate state and its row sorts first.
3. Given a session whose Todo list has two completed, one in-progress, and one pending item, when its projection is applied, then the row reports `2/4` and names the in-progress item.
4. Given a running session without a Todo projection, when it remains active, then the row uses an indeterminate indicator and displays no percentage or ETA.
5. Given a running-to-idle edge, when no higher-priority state exists, then the island reports the session as recently completed for a bounded interval.
6. Given a Host agent error, when the corresponding session is visible, then the session enters failure state without suppressing a pending human interaction.
7. Given a stream disconnect, when polling still succeeds, then baseline status remains visible and the app reconnects the stream with bounded backoff.
8. Given an unreachable endpoint, when both polling and streams fail, then the island reports offline and continues retrying without blocking the UI.
9. Given privacy mode, when the island renders, then no session title, workspace path, tool argument, or error detail is visible.
10. Given a subagent with a visible parent session, when expanded, then the child is indented beneath the parent without changing the aggregate counts.
11. Given the island is dragged and the app relaunches, when the saved display still exists, then the island returns to the saved position within that display's visible frame.
12. Given Reduce Motion is enabled, when state changes or the island expands, then no repeating pulse or spring animation is used.
13. Given a local DSH Web instance at a non-default port, when the endpoint is saved, then the app reconnects without restart and persists the normalized URL.
14. Given the optional deep-link plugin is absent, when a session row is clicked, then the DSH Web UI still opens and the island remains operational.
