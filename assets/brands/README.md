# Bundled system and program logos

The app uses these logos only to identify an installed operating system or
program. Symbols share a rounded, theme-aware badge, consistent inset and
aspect ratio. Colored artwork keeps its brand colors; black/white symbols use
the app foreground color for contrast. Ubuntu and nginx use transparent symbol
variants rather than the banner/wordmark. Their official colors are applied.

Selected SVGs are vendored from **Devicon** (MIT), **font-logos** (Unlicense),
and **Simple Icons** (CC0-1.0). The three upstream license texts accompany this
file and are displayed in the app's open-source notices. These collection
licenses do not transfer ownership of third-party trademarks; each brand's
own use policies continue to apply. The logos do not imply endorsement.

- https://github.com/devicons/devicon
- https://github.com/lukas-w/font-logos
- https://github.com/simple-icons/simple-icons
- Python artwork: https://www.python.org/community/logos/
- Ubuntu artwork: https://design.ubuntu.com/brand
- Debian artwork: https://www.debian.org/logos/
- Arch artwork: https://archlinux.org/art/

`manifest.json` records **every file's original source, immutable commit and
SHA-256**. Any presentation adaptation records its source hash and transformation too. Only the
selected files are shipped, not the icon libraries or their fonts. The existing
four assets under `assets/distro` retain their own license notices.

Run `scripts/vendor-brand-icons.py` intentionally to refresh the selected
resources and their registry; review the resulting source/manifest diff.
The app never fetches a CDN for a bundled icon. Custom image links are chosen
by the user; failed links use the same fixed-size fallback as unknown programs.
