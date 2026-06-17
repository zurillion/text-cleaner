# Project page

`index.html` is the standalone GitHub Pages site for TextMagician — one
file, no Jekyll, no build step.

## How to publish it

One-time setup, on github.com:

1. Open the repo's **Settings** → **Pages**.
2. Under **Build and deployment**, set **Source** to *Deploy from a
   branch*.
3. **Branch** → `main`, **Folder** → `/docs`. Save.
4. Wait ~1 minute. The page goes live at
   `https://zurillion.github.io/text-cleaner/`.

After that, every push to `main` that touches `docs/` republishes the
page automatically. No CI to configure.

## How the download button works

The CTA on the page points to:

```
https://github.com/zurillion/text-cleaner/releases/latest/download/TextMagician.dmg
```

GitHub redirects that URL to the most recent published Release's asset
**with that exact filename**. The user only sees a download dialog;
they never land on github.com.

For this to work, every release must contain a file named exactly
**`TextMagician.dmg`** (no version number). `Scripts/make-dmg.sh`
already produces one — alongside the versioned `TextMagician-<v>.dmg`
it keeps for the local archive. When you cut a new release, upload the
versionless one.

## Cutting a new release

After `make-dmg.sh` has produced the new DMG(s):

1. On github.com: repo → **Releases** → **Draft a new release**.
2. **Choose a tag** → type `v1.1` (or whichever version) and pick
   *Create new tag on publish*.
3. **Release title**: `v1.1 — short summary`.
4. **Description**: a short changelog. Bullets, plain text.
5. Drag the **`TextMagician.dmg`** file (the unversioned one) into the
   attachments box. Optionally drag the versioned one too as a
   secondary asset.
6. **Publish release**.

The next page load already serves the new DMG behind the Download
button — no edits to `index.html` needed.

## Screenshots

The page references files under `Screenshots/` at the repo root. The
filenames are URL-encoded in the HTML so spaces in the basenames
("Unicode Chars") are not a problem.

| File                                | Where it shows                       |
| ----------------------------------- | ------------------------------------ |
| `Screenshots/icon.svg`              | Hero icon + favicon + Open Graph     |
| `Screenshots/1. Transformations.png`| Popup screenshot (clipboard tool)    |
| `Screenshots/2. Unicode Chars.png`  | Unicode picker screenshot            |
| `Screenshots/3. Emojis.png`         | Emoji picker screenshot              |
| `Screenshots/4. Preferences 1.png`  | Preferences — general / shortcuts    |
| `Screenshots/5. Preferences 2.png`  | Preferences — actions list           |

`icon.svg` is a vector recreation of the app icon (same blue→purple
gradient, same rounded-square mask, same wand-and-sparkles shape).
Generated from `TextCleaner/AppIcon.swift`'s parameters, scales
losslessly to any size, no external image file needed.
