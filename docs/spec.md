# Spec v1: Poster over camcorder clips

## Vision
A full-screen page. Old camcorder footage plays in the background as quick random cuts, with heavy grain and VHS-era softness. The scanned party poster sits sharp and clean in the center, clearly the focus.

## Inputs (owner provides)
- `assets/poster.png`: the poster, 3091x4000 PNG (portrait, roughly letter-size ratio). Too heavy to serve as-is: make web-sized versions that stay crisp on retina screens. **This is a test poster.** The owner will swap in a final one (its aspect ratio may differ), so generating the web versions must be a rerunnable script step, and the layout must not hardcode this poster's dimensions.
- `raw/`: clips the owner already chopped from camcorder footage. Currently 40 .mp4 files, H.264 1440x1080 progressive at 29.97fps, with AAC audio, ~138MB total. Durations vary widely, from 0.19s to 8.4s.

## Requirements

### 1. Clip pipeline (build step, run locally)
- A script converts every clip in `raw/` into a web-ready clip. The owner already did the chopping, so there's no random cutting.
- **Length rules:** clips longer than **3s** are trimmed to 3s. Clips shorter than **1s** are skipped, because they'd look like glitches. Both numbers are settings at the top of the script.
- Web-ready: much smaller than the source (a lower resolution is fine since it's a grainy background), silent (audio removed), plays on iPhone Safari, Android Chrome, and desktop.
- Writes a list of clips the page can read, so adding footage means dropping files in `raw/` and rerunning the script, with no code edits.
- Rerunning it is safe (replaces old output, never touches `raw/`).

### 2. Background video
- Fills the whole viewport edge to edge (cropped to cover, never letterboxed).
- Plays clips one after another in **random order**, with no clip repeating until all have played.
- Cuts are instant like a camcorder edit: **no black frames or loading gaps** between clips.
- Muted, autoplays, loops forever, works inline on iPhone.

### 3. Camcorder look
- Strong **film grain/noise** that visibly moves (flickers frame to frame), not a static texture.
- Old-tape feel: slightly washed/shifted color, softness, light vignette. Scanlines are optional; the engineer decides.
- **v1 feedback:** the owner loves the static/grain but finds the overall effects "a bit much." Keep the grain as the signature. Dial the tape treatment (color wash, softness, chroma fringing, scanlines, vignette) way back so the footage reads more naturally. Effect strengths must be easy to tweak from settings.
- The look applies to the **video only**. The poster stays clean.
- Must stay smooth on a mid-range phone.

### 4. Poster
- Centered horizontally and vertically.
- As large as possible while keeping a **minimum 50px margin on every side** on desktop/tablet. **On phones the margin drops to 20px** (owner feedback: the poster was too small on mobile). Both margins are settings.
- Aspect ratio preserved, never cropped or stretched.
- "Highlighted": it has to stand out against busy footage (e.g. a shadow or glow). The engineer picks the treatment, and it should be subtle and tasteful.
- Has descriptive alt text. Suggested: "Porch Party poster: paper-cutout collage. 6:30pm at 907 North Pearl St., Denver. Join us for a porch party on the top floor balcony of our apartment. Snacks provided. BYOB. Plus-ones welcome." Add the date once the owner has it.
- Page title "Porch Party", plus link-preview tags (Open Graph) using the poster image, so the link looks good when texted.

### 5. Robustness
- If video can't autoplay or clips fail to load, the poster still shows over a dark background.
- Respects `prefers-reduced-motion` (e.g. slow or stop cuts, calm the grain).
- Deploys to Cloudflare Workers as static assets. Only site files are published, never `raw/`, scripts, docs, or the full-size poster.

### 6. Music (v1.2)
- Source: `assets/song.mp3` ("Lapis Lazuli (A1)", 4:52, 9MB, 259kbps stereo, with embedded cover art that must be stripped). Never serve the source file.
- **Starts at 0:55** on the first tap. The start point is a setting. When the song ends, it loops back to 0:55, not 0:00.
- One song plays when the visitor **taps/clicks anywhere** on the page. Browsers block sound until the visitor interacts, so it can't start on its own.
- Tapping again pauses it; the next tap resumes. Loops when it ends.
- A small, unobtrusive hint invites the tap. Suggested: camcorder on-screen-display style text, e.g. "▶ TAP FOR SOUND", that switches to a playing/paused state. It must not compete with the poster.
- Audio file is compressed for the web (small download, plays on iPhone Safari). Audio only starts downloading after the first tap or when idle, never blocking the page.
- Works alongside the iOS Low Power Mode tap-to-start-video behavior: one tap starts both.
- Under reduced motion, music behavior is unchanged (it's opt-in already).

## Backlog (later, not now)
- **Sign-up button → form** asking for name and email, styled the same way: a card hanging over the video like the poster. Where submissions go is still to be decided.

## Acceptance check (owner, by eye)
- Open on phone and laptop: poster is crisp and centered with ≥50px space all around.
- Background cycles random ~3s clips with no black flashes.
- Video clearly looks like old grainy camcorder footage.

## Out of scope for v1
RSVP form (see Backlog), animations on the poster.
