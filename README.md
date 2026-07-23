# Reel Agent — hirewithakshay

A script-driven Instagram Reel assembler. Upload your voiceover and visuals,
paste your script, and AI breaks it into timed on-screen caption beats. Your
visuals are auto-assigned and auto-trimmed to fit each beat, and you export a
finished 9:16 video — entirely in your browser. No server, no upload of your
media anywhere.

## AI backend: Google Gemini

This app's AI features (turning a script into timed caption beats) run on
**Google's Gemini API**, specifically `gemini-2.5-flash`, with automatic
fallback to the latest available Flash model if that one is ever retired or
unavailable.

The AI call is isolated behind an `AIProvider` interface (see `index.html`,
class `AIProvider` / `GeminiProvider`). Only one method matters:
`generateSegments(script, context)`, which returns the same JSON beat array
the rest of the app has always expected:

```json
[
  { "spoken": "", "caption": "", "weight": 1, "keyword": "" }
]
```

To switch to a different provider later, write a new class implementing
that same method and swap it in at the one call site in the "Generate &
Assemble Reel" button handler — nothing else in the app needs to change.

## Setting up your Gemini API key

1. Get a free key at **aistudio.google.com/app/apikey**.
2. Open the app → **Settings** card → paste it into **Google Gemini API Key**.
3. It's stored in your browser's `localStorage` under the key
   `reelAgentGeminiApiKey` and sent directly from your browser to Google's
   API — it never touches any server of ours, and never appears in this
   source code or in GitHub.

### Environment variable naming

Since this is a static, client-side app (plain HTML/JS hosted on Netlify),
there is no build step or server process that reads OS-level environment
variables at runtime — the browser can only use a value the user has
actually entered. For consistency with standard tooling and for a future
server-side setup, the key is conceptually named `GEMINI_API_KEY`
everywhere in code comments and docs. If you later add a Supabase Edge
Function (or any small server) to proxy these requests, that's where a real
`GEMINI_API_KEY` environment variable would live — set as a Supabase
secret, never shipped to the browser, with the Edge Function calling Gemini
on the app's behalf. The `AIProvider` layer described above is built so
that swap is a single new class, not a rewrite.

No API key is hardcoded anywhere in this repository. `GEMINI_API_KEY` is a
placeholder name used in documentation only.

## Error handling

Gemini errors are translated into short, readable messages instead of raw
API responses: `Invalid API key`, `Quota exceeded`, `Daily limit reached`,
`Network error`, `Model unavailable`, or a generic `Try again`.

## JSON reliability

Gemini sometimes wraps its JSON in markdown code fences or adds stray
whitespace/prose. The app automatically:
1. Strips ` ```json ` / ` ``` ` fences and trims whitespace.
2. Parses the result.
3. If parsing fails, attempts a best-effort repair (extracts the `[...]`
   array, removes trailing commas) before giving up.
4. If still unparseable, retries the request **once**, explicitly asking
   Gemini to "Return ONLY valid JSON," before failing with a clear error.
   No more than one retry is ever made per generation.

## Everything else, unchanged

Script parsing, caption generation, timeline, segment timing, visual
assignment, export, preview, autosave/resume (IndexedDB), and PWA
installability on desktop and mobile all work exactly as before — only the
AI backend changed.

## AI Voiceover (optional — no recording required)

The voiceover upload is no longer mandatory. If you don't have (or don't
want to record) audio, write or paste your script, then click **Generate
AI Voiceover** in the Voiceover audio card. Gemini's text-to-speech model
(`gemini-2.5-flash-preview-tts`) reads your script aloud with natural
pacing — brief pauses at commas, clear stops at periods, a longer beat
between paragraphs — aiming for a real human presenter's delivery, not a
robotic reading. Five voice options are offered (Kore, Charon, Aoede,
Puck, Fenrir), each with a different tone.

Technically, this reuses the exact same audio pipeline as an uploaded
recording: Gemini returns raw PCM audio, which gets wrapped in a standard
WAV header client-side and fed straight into the existing `handleAudio()`
flow — so preview, export, timeline sync, and autosave all work completely
unchanged, with zero special-casing anywhere else in the app.

If beats have already been generated from your script, the AI voiceover
reads the per-beat "spoken" text (so pauses land naturally between beats);
otherwise it reads your raw script. Generating a voiceover this way does
**not** trigger AI Voice Refinement (below) — that feature exists to
polish a *recording* you made; this one *is* the final, already-written
script being spoken, so there's nothing to transcribe or refine.

## AI Voice Refinement

After a voiceover is uploaded, the app automatically:
1. **Transcribes** the audio verbatim (Gemini's audio understanding — no
   separate speech-to-text service needed).
2. **Refines** the transcript into a polished, professional business
   voiceover — same meaning and facts, better delivery, stronger hook,
   tighter sentences, and an appropriate CTA where relevant.

Nothing is silently replaced: a comparison view shows the original next to
the refined version, with **Use Original**, **Use Refined**, **Edit
Manually**, **Copy**, and **Regenerate** controls. Whichever version you
choose becomes the text in the existing Script field — the rest of the
pipeline (beat generation, timeline, export) is completely unaware anything
changed upstream.

Controls:
- **Auto-refine before generating** (checkbox, on by default) — turn off to
  keep your exact wording and skip refinement entirely.
- **Business tone** — Professional Business, Startup Founder, Corporate HR,
  Sales, Marketing, CEO, Luxury Brand, Motivational, Educational,
  Storytelling, LinkedIn Thought Leadership.
- **Rewrite intensity** — Minimal (grammar only), Balanced (professional
  rewrite, default), Strong Rewrite (maximum engagement).
- **Quick presets** — topic hints like Startup Hiring, HR Consultancy,
  Recruitment, etc., or Auto Detect.
- **History** — the last 10 refinements (original, refined, timestamp,
  tone, intensity) are saved and restorable with one click.

### Architecture

Built as an independent pipeline, matching the rest of the app's
`AIProvider` pattern:

```
Voice Upload → TranscriptionService → RefinementService →
generateSegments() (caption/beat generation) → Timeline → Export
```

`TranscriptionService` and `RefinementService` are thin wrappers around the
same `AIProvider` interface used for beat generation — they call
`provider.transcribeAudio()` and `provider.refineTranscript()`
respectively. `GeminiProvider` implements both today; swapping to a
different provider later means implementing those two methods on a new
class, same as `generateSegments()`.

## Saved Reels library

Every exported video is automatically kept in a persistent, on-device
library — separate from (and in addition to) the file the download button
saves to your system. It survives a refresh, closing the tab, or reopening
the installed app on desktop or mobile, using the same IndexedDB database
as session autosave (a second, dedicated store, so neither one interferes
with the other).

If cloud sync (below) is connected and you're signed in, every export is
*also* uploaded to your Supabase project automatically, so it shows up in
this same list — tagged "this device" or "cloud" — from any device you're
signed in on.

The library card shows each saved reel with a thumbnail, size, and
duration, plus Download and Delete actions, an approximate on-device
storage usage line (via the browser's Storage Estimate API where
supported), and a "Clear saved reels" bulk action (local reels only —
cloud reels are deleted individually).

## Cloud sync (cross-device)

Local storage (IndexedDB) keeps everything working per-device, which is
all this app needs by default. Cloud sync is optional, on top of that, for
when you genuinely want the same script/captions/exported reels visible on
both your PC and your phone under one account.

**What syncs to the cloud:** script text, refined voiceover, captions/
beats, and every exported video file.

**What stays device-only:** the raw audio/images/video clips you upload as
source material. Re-uploading multi-megabyte source files to the cloud on
every autosave would be slow and wasteful, so those stay local — you'd
add them once per device, same as today. This is a deliberate tradeoff,
not a limitation we plan to lift by default.

### One-time setup

1. Create a free project at **supabase.com** (or use an existing one).
2. In your project's **SQL Editor**, run the contents of
   `supabase/schema.sql` (included in this package). This creates:
   - `reel_drafts` — one row per user, holding script/context/voice/
     segments, upserted on every autosave.
   - `reel_videos` — one row per exported video, pointing at its file in
     Storage.
   - A public Storage bucket named `reel-agent-files` for the video files
     themselves, with row-level security so only each user can
     upload/delete inside their own folder.
3. In your project's **Settings → API**, copy the **Project URL** and the
   **anon public key** (not the service_role key — never use that one in
   a browser app).
4. In the app, open **Settings → Cloud sync**, paste both in, click
   **Save connection**.
5. Enter your email and click **Send sign-in link** — this uses
   passwordless (magic link) sign-in, no password to manage. Open the
   emailed link on any device to sign in there too; same email = same
   account = same synced data.

### How conflicts are handled

On load, the app compares your local saved session against your cloud
draft (if signed in) and offers to resume whichever is more recent —
clearly labeled "on this device" or "from the cloud" — never silently
picks one.

## Deploying updates

This app is hosted via Netlify with GitHub auto-deploy. To ship a change:
replace the relevant file(s) in your GitHub repo, commit, and Netlify
redeploys automatically within about a minute. Installed devices (desktop
and mobile) pick up the update the next time they're opened with an
internet connection, thanks to the app's network-first service worker.

## Files in this app

- `index.html` — the entire application (UI, logic, AI service layer)
- `manifest.json` — PWA manifest (name, icons, install behavior)
- `service-worker.js` — network-first caching for installability/offline shell
- `icon-192.png`, `icon-512.png` — app icons
