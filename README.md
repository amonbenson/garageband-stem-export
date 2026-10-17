# GarageBand Stem Export

Export every track of a GarageBand project as its own WAV file (a "stem") with one command.

GarageBand can only export the whole song. The usual workaround is to solo a track, choose
**Share > Export Song to Disk**, and repeat for every track. This script does exactly that for you,
automatically, and names each file after its track.

- One **16-bit, 44100 Hz WAV** file per track, named after the track
- Your solo and mute settings are put back the way they were when it finishes
- Optional project name or custom text in front of or behind each file name

```
$ osascript export_stems.applescript -P ~/Desktop/stems
Exporting Drums
Exporting Bass
Exporting Vocals
Exported stems to /Users/you/Desktop/stems
```

This produces `My Song - Drums.wav`, `My Song - Bass.wav`, `My Song - Vocals.wav`, and so on.

## Requirements

- A Mac with **GarageBand 10.4** (tested with 10.4.14 on macOS 26)
- GarageBand set to **English**, because the script clicks menus by name
- `python3`, which macOS installs together with the Xcode Command Line Tools. If macOS offers to
  install developer tools the first time you run the script, accept.

## Setup

1. Download this repository (green **Code** button, then **Download ZIP**) and unzip it.
2. Open your project in GarageBand and leave the window visible.
3. Open the **Terminal** app (press `Cmd + Space`, type "Terminal", press Return).
4. Go to the folder with the script. Type `cd ` (with a space), drag the unzipped folder into the
   Terminal window, and press Return.

## Allow the script to control GarageBand

macOS protects apps from being remote controlled, so you must give permission once. Everything
below is done for **Terminal**, because that is the app that starts the script.

**Accessibility (required).** Open **System Settings > Privacy & Security > Accessibility**, then
turn on **Terminal**. If Terminal is not in the list, click **+** and add it from
`/Applications/Utilities`. If you skip this, the script stops with the error
`osascript is not allowed assistive access`. Quit and reopen Terminal after changing it.

**Automation prompts.** The first run may show pop-ups such as *"Terminal wants to control System
Events"* or *"Terminal wants to control GarageBand"*. Click **OK** / **Allow** on each.

**Folder access prompt.** If you export to Desktop, Documents or Downloads, macOS may ask whether
Terminal may access that folder. Click **Allow**.

If you ran the script and clicked "Don't Allow" by mistake, you can turn the permission back on in
**System Settings > Privacy & Security > Automation** (or **Files and Folders**).

## Run it

```bash
osascript export_stems.applescript -P ~/Desktop/stems
```

`~/Desktop/stems` is the output folder. It is created if it does not exist. The `-P` option puts the
project name in front of each track name.

While it runs:

- GarageBand comes to the front and your **mouse pointer moves by itself**. Do not use the mouse or
  keyboard until it prints `Exported stems to ...`.
- Expect roughly 20 seconds per track for a four-minute song.
- Press `Ctrl + C` in Terminal to cancel. Check your solo buttons afterwards, because the script
  cannot restore them if you cancel.

Running it again with the same names replaces the existing files.

## Options

| Option | What it does | Example result |
| --- | --- | --- |
| *(none)* | Name files after the track | `Drums.wav` |
| `-P`, `--project-prefix` | Project name in front | `My Song - Drums.wav` |
| `-S`, `--project-suffix` | Project name behind | `Drums - My Song.wav` |
| `-p`, `--prefix TEXT` | Your own text in front | `-p 'Take2_'` gives `Take2_Drums.wav` |
| `-s`, `--suffix TEXT` | Your own text behind | `-s '_v2'` gives `Drums_v2.wav` |
| `-t`, `--track NAME` | Export only this track (repeat for more) | `-t Drums -t Bass` |
| `-h`, `--help` | Show the built-in help | |

Your own text is used exactly as typed, so include the separator yourself (`'Take2_'`, not
`'Take2'`). You cannot combine `-p` with `-P`, or `-s` with `-S`. Characters that are not allowed in
file names (`/` and `:`) are replaced by `_`, and tracks with the same name get a number added.

More examples:

```bash
osascript export_stems.applescript ~/Desktop/stems
osascript export_stems.applescript -S ~/Desktop/stems
osascript export_stems.applescript -p 'Take2_' -S ~/Desktop/stems
osascript export_stems.applescript -t Vocals -t Bass ~/Desktop/stems
```

## Troubleshooting

| Message or problem | What to do |
| --- | --- |
| `osascript is not allowed assistive access` | Turn on Terminal under **Accessibility** (see above), then restart Terminal |
| Nothing happens, or `Can't get ...` errors | Make sure the project window is open, visible and not in full screen with a dialog on top |
| `Window not found: Export Song to Disk` | GarageBand is not in English, or a different dialog was open |
| `No track named "X"` | The name after `-t` must match the track name exactly; the message lists all names |
| A track is still soloed after an error | Click its **S** button in GarageBand to turn it off |

## How it works

The script uses macOS UI scripting (System Events) to click through GarageBand like a person would:
select a track, press `S` to solo it, open **Share > Export Song to Disk**, pick the folder and
file name, choose WAV, and wait for the export to finish. Afterwards it re-encodes each file with
the macOS tool `afconvert` to make sure it is 16-bit at 44100 Hz. Nothing is uploaded and no extra
software is installed.

Not affiliated with or endorsed by Apple. GarageBand is a trademark of Apple Inc.

Developers and coding agents: see [AGENTS.md](AGENTS.md).
