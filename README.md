# Porch Party

A one-page party invite: the poster, centered over shuffled, grainy camcorder clips.
Plain HTML/CSS/JS with no build step, served as static assets on Cloudflare Workers.

- `public/`: the site, which is the only folder that gets deployed
  - `index.html`, `styles.css`, `main.js`: the page
  - `clips/`: web clips plus `clips.json`, the list the page shuffles (generated)
  - `images/`: web-sized poster images and the link-preview image (generated)
  - `audio/`: the web version of the song (generated)
- `scripts/`: the scripts that generate `public/clips/`, `public/images/` and `public/audio/`
- `assets/`: the full-size poster and the source song (source only, never deployed)
- `raw/`: original camcorder clips (not committed, never deployed)
- `wrangler.jsonc`: Cloudflare Workers config

The scripts need ffmpeg (`brew install ffmpeg`). Everything else they use ships with macOS.

## Add or change clips

1. Drop `.mp4` / `.mov` files into `raw/` (or remove some).
2. Run `scripts/process-clips.sh`.

For every video in `raw/` the script:

- skips clips shorter than `MIN_SECONDS` (they look like glitches),
- trims clips longer than `MAX_SECONDS`,
- removes audio, scales to 854x480 (16:9, square pixels), bakes in a light tape look
  (see the knobs below), and encodes H.264 that plays on iPhone Safari, Android Chrome
  and desktop browsers,
- writes `public/clips/clips.json`, the list the page shuffles through.

It's safe to rerun. It builds into a temporary folder and then replaces `public/clips/`,
and it only ever reads from `raw/`.

Settings at the top of `scripts/process-clips.sh`:

| Setting | Default | What it does |
| --- | --- | --- |
| `MAX_SECONDS` | 3 | Longer clips are trimmed to this length |
| `MIN_SECONDS` | 1 | Shorter clips are skipped |
| `WIDTH` / `HEIGHT` | 854 / 480 | Output size |
| `CRF` | 27 | Quality (lower is better and bigger) |

## Tune the look

The look has two parts. The tape colour is baked into the clips, so changing it means
editing `scripts/process-clips.sh` and rerunning it. The static and overlays are added
by the page, so you edit `public/styles.css` and reload. No rerun needed.

Baked into the clips (top of `scripts/process-clips.sh`):

| Setting | Now | Neutral | What it does |
| --- | --- | --- | --- |
| `CONTRAST` | 0.95 | 1 | Below 1 flattens the image, like worn tape |
| `BRIGHTNESS` | 0.015 | 0 | Above 0 lifts the blacks to a milky grey |
| `SATURATION` | 0.92 | 1 | Below 1 fades the colour |
| `WARMTH` | 0.02 | 0 | Shifts colour toward yellow (negative shifts it toward blue) |
| `CHROMA_SHIFT_PX` | 1 | 0 | Red/blue fringing around bright edges, in pixels (whole numbers) |
| `BLUR_SIGMA` | 0 | 0 | Extra softness (try 0.3 to 0.6). Off, since the 480p upscale is already soft |

Set any of these to its neutral value to turn that effect off.

On the page (`:root` in `public/styles.css`):

| Property | Now | What it does |
| --- | --- | --- |
| `--grain-opacity` | 0.3 | Strength of the moving static, the main effect (0 is off) |
| `--grain-speed` | 0.5s | Time for the static to cycle through 8 positions (lower flickers faster) |
| `--grain-tile` | 128px | Size of the noise tile (bigger makes coarser grain) |
| `--scanline-opacity` | 0.06 | Darkness of the horizontal scanlines (0 is off) |
| `--vignette-opacity` | 0.3 | How dark the corners get (0 is off) |
| `--vignette-start` | 55% | Where the corner darkening begins, measured from the centre |
| `--footage-dim` | 0.06 | Overall darkening of the video so the poster stands out (0 is off) |

Small steps work best: 0.02 to 0.05 for opacities, 0.02 for the colour settings.

For comparison, v1 used `CONTRAST` 0.88, `BRIGHTNESS` 0.03, `SATURATION` 0.8,
stronger warmth (0.05), `CHROMA_SHIFT_PX` 2, `BLUR_SIGMA` 0.5, grain 0.32, scanlines
0.16, vignette 0.6 starting at 45%, and dim 0.12.

## Swap the poster

1. Replace `assets/poster.png` with the new poster. Any size or shape works.
2. Run `scripts/make-poster.sh`.

That rebuilds `public/images/` with:

- `poster-<width>.jpg`, one per width in `WIDTHS` (800, 1200, 1600, 2400; never larger
  than the source), so the poster stays crisp from phones to large retina screens,
- `og.jpg`, the link-preview image (`OG_WIDTH`, 1200 wide).

It also updates the `srcset` / `sizes` on the poster image (`id="poster-image"`) in
`public/index.html` to match the new poster's aspect ratio, so the browser picks the
right file. JPEG has no transparency, so the script warns you if the poster has
transparent areas.

The 50px poster margin is set in two places: `--poster-margin` in `public/styles.css` and
`POSTER_MARGIN` in `scripts/make-poster.sh`. If you change one, change the other too.

If the event details changed, also update the `alt` text and the `description` /
`og:description` tags in `public/index.html`.

## Music

The first tap or click anywhere on the page starts the song. The next tap pauses it,
and the one after that resumes. A small camcorder-style label in the top-left corner
shows the state: `TAP FOR SOUND`, `SOUND ON` or `PAUSED`. Keyboard users can Tab to it
and press Enter or Space. The audio isn't downloaded until that first tap.

The web file is made from `assets/song.mp3` by:

```sh
scripts/make-audio.sh
```

It writes `public/audio/song.m4a`: AAC at 96 kbps stereo, which plays on iPhone Safari
and everything else. The cover art and tags are removed. The file is cut to begin at
the start point, so the browser just loops the whole file and every loop goes back to
the start point, not 0:00. The source mp3 is never deployed.

Settings at the top of `scripts/make-audio.sh`:

| Setting | Now | What it does |
| --- | --- | --- |
| `START_SECONDS` | 55 | Where the song starts and loops back to (0:55) |
| `FADE_IN_SECONDS` | 0.3 | Short fade at the start point so it doesn't click (0 is off) |
| `BITRATE` | 96k | Audio quality (128k sounds better and makes a bigger file) |

- **Change the start point:** edit `START_SECONDS` and rerun the script.
- **Swap the song:** replace `assets/song.mp3` (keep that name) and rerun the script.

Clips and audio go through the small Worker in `worker.js`
(`run_worker_first` in `wrangler.jsonc`), because Cloudflare's static assets don't
answer the partial (range) requests Safari needs to play video and audio.

## Preview locally

```sh
npx wrangler dev
```

Then open http://localhost:8787. This serves `public/` the way Cloudflare will.

A quick alternative is `python3 -m http.server 8000 --directory public`, then
http://localhost:8000. It's fine in Chrome and Firefox, but Safari and iPhone won't play
the clips from it, because Python's server doesn't support the partial (range) requests
Safari uses for video. Use `wrangler dev` to test Safari.

Opening `index.html` straight from Finder won't load the clips, because browsers block
reading `clips.json` from `file://`.

To check on your phone, run `npx wrangler dev --ip 0.0.0.0` and open
`http://<your-mac's-local-IP>:8787` with the phone on the same Wi-Fi.

## Deploy

```sh
npx wrangler deploy
```

This uploads only `public/` as the `porch-party` Worker (the first run asks you to log in
to Cloudflare). Commit `public/clips/` and `public/images/` along with the page, so the
repo always has what's live. Cloudflare limits each file to 25 MiB. The largest file
here is well under 1 MiB.
