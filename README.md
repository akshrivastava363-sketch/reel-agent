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
