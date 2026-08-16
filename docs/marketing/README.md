# Community media

The repository's screenshots and GIFs must never depend on a user's live DSH Host, desktop, home directory, account, notifications, or browser state.

`capture-product-assets.sh` launches the deterministic app fixtures and uses macOS window capture so the product PNGs retain transparent rounded corners. It captures the Original Signal compatibility states and an expanded specimen for each of the five themes. The script rejects any capture without an alpha channel or with more than 0.01 alpha anywhere in its sampled corner regions. `preview.html` adds a second rounded clip while composing the real local captures into an editorial specimen board and a synthetic developer workspace. Its visible files, code, session titles, Todo text, status counts, and paths are invented for the demo. The source uses only repository-local assets and system fonts; it performs no network requests and contains no analytics.

Run `./scripts/render-marketing-assets.sh` on macOS with Google Chrome and ffmpeg installed to recapture the product and create:

- `docs/assets/dsh-island-working.png`
- `docs/assets/dsh-island-collapsed.png`
- `docs/assets/dsh-island-expanded.png`
- `docs/assets/dsh-island-theme-original.png`
- `docs/assets/dsh-island-theme-quiet.png`
- `docs/assets/dsh-island-theme-orbital.png`
- `docs/assets/dsh-island-theme-editorial.png`
- `docs/assets/dsh-island-theme-pulse.png`
- `docs/assets/dsh-island-social-preview.png`
- `docs/assets/dsh-island-themes.png`
- `docs/assets/dsh-island-desktop.png`
- `docs/assets/dsh-island-demo.gif`
- `.marketing/gif-frames/*.png`

The 1600×1000 theme board and 1200×630 social preview use all five native product captures. The script encodes the four Original Signal GIF frames in lexical order with durations `2.2,1.6,0.5,3.2` seconds. The published `docs/assets/dsh-island-demo.gif` is 1200×720, 7.5 seconds, and demonstrates the shared collapsed, attention, expansion, and expanded interaction states rather than a theme-specific workflow or personal desktop.

Before publication, visually inspect the final PNGs and decoded representative GIF frames, then confirm that metadata and OCR contain no username, home path, email address, token, live session title, or unrelated notification.
