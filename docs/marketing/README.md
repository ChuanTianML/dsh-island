# Community media

The repository's screenshots and GIFs must never depend on a user's live DSH Host, desktop, home directory, account, notifications, or browser state.

`capture-product-assets.sh` launches the deterministic app fixtures and uses macOS window capture so the product PNGs retain transparent rounded corners. The script rejects any capture without an alpha channel or with an opaque corner. `preview.html` adds a second rounded clip while rendering a synthetic developer workspace. Its visible files, code, session titles, Todo text, status counts, and paths are invented for the demo. The source uses only repository-local assets and system fonts; it performs no network requests and contains no analytics.

Run `./scripts/render-marketing-assets.sh` on macOS with Google Chrome and ffmpeg installed to recapture the product and create:

- `docs/assets/dsh-island-working.png`
- `docs/assets/dsh-island-collapsed.png`
- `docs/assets/dsh-island-expanded.png`

- `docs/assets/dsh-island-social-preview.png`
- `docs/assets/dsh-island-desktop.png`
- `docs/assets/dsh-island-demo.gif`
- `.marketing/gif-frames/*.png`

The script encodes the four GIF frames in lexical order with durations `2.2,1.6,0.5,3.2` seconds. The published `docs/assets/dsh-island-demo.gif` is 1200×720, 7.5 seconds, and intentionally uses state-based frames rather than recording a personal desktop.

Before publication, visually inspect the final PNGs and decoded representative GIF frames, then confirm that metadata and OCR contain no username, home path, email address, token, live session title, or unrelated notification.
