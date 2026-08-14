# Community media

The repository's screenshots and GIFs must never depend on a user's live DSH Host, desktop, home directory, account, notifications, or browser state.

`preview.html` renders a synthetic developer workspace around deterministic DSH Island fixtures. Its visible files, code, session titles, Todo text, status counts, and paths are invented for the demo. The source uses only repository-local assets and system fonts; it performs no network requests and contains no analytics.

Run `./scripts/render-marketing-assets.sh` on macOS with Google Chrome installed to create:

- `docs/assets/dsh-island-social-preview.png`
- `docs/assets/dsh-island-desktop.png`
- `.marketing/gif-frames/*.png`

Encode the four GIF frames in lexical order with durations `2.2,1.6,0.5,3.2` seconds. The published `docs/assets/dsh-island-demo.gif` is 1200×720, 7.5 seconds, and intentionally uses state-based frames rather than recording a personal desktop.

Before publication, visually inspect the final PNGs and decoded representative GIF frames, then confirm that metadata and OCR contain no username, home path, email address, token, live session title, or unrelated notification.
