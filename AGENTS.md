# AGENTS.md

Single-file AppleScript, `export_stems.applescript`, that exports each GarageBand track as a
16-bit 44100 Hz WAV by driving the GarageBand GUI. User docs are in `README.md`; the CLI is defined
by `usageText` at the top of the script, so keep `README.md` and `usageText` in sync.

## Run and test

There is no test suite or build step. GarageBand has no scripting dictionary for this, so the only
real test is a run against an open project (tested: GarageBand 10.4.14, macOS 26, English UI).

```bash
osacompile -o /dev/null export_stems.applescript     # syntax check only
osascript export_stems.applescript -t TRACK /tmp/out  # smallest real test
```

The host app (Terminal, Claude, ...) needs Accessibility permission. After a run, check that:
- every file is `2 ch, 44100 Hz, Int16` (`afinfo`),
- stems differ from each other (compare RMS; identical RMS means solo did not take effect),
- no track is left soloed (the script restores the original solo states, also on errors).

Avoid full runs for quick checks: they take about 20 s per track.

## Structure

`run` -> `parseArguments` -> read tracks -> `exportRequestedTracks` -> per track:
`soloOnly` -> `exportStem` (open dialog, `chooseFolder`, `configureExportDialog`,
`confirmExportDialog`, `waitForExport`, `convertToCdFormat`).

The Accessibility path to the track headers is
`window > "Tracks" group > last split group of split group 1 > scroll area 1 > "Tracks header"`,
whose children are one layout item per track (name in the text field, `Mute`/`Solo` checkboxes).
Every UI lookup goes through `mainWindow`, `trackHeaderScrollArea`, `trackHeaderGroup` or
`exportDialogContent`; extend those instead of repeating paths.

## Hard-won GarageBand facts

- **AX clicks on header checkboxes do nothing.** `click` on `Solo`/`Mute` and synthetic
  System Events `click at` are ignored. Real HID mouse events work. The script therefore clicks the
  left edge (x + 4) of track 1's header via CGEvent (ctypes, embedded in `mouseClickSource`),
  presses Down arrow `trackIndex - 1` times, and types `s`. Arrow keys also scroll the track into
  view.
- **AX positions of scrolled-out tracks are stale.** Do not compute click coordinates for tracks
  that are not visible; that is why selection goes through the keyboard.
- **Use `tell application "GarageBand" to activate`, not `set frontmost to true`.** The latter
  leaves the host app in front and events go to the wrong window. `bringGarageBandToFront` waits
  until GarageBand is actually frontmost.
- **The export dialog is a separate `AXDialog` window, not a sheet.** Its controls live inside
  `UI element 1`. The Save panel does not remember the folder, so `chooseFolder` uses Cmd+Shift+G on
  every export. Putting a full path into the name field does not work (`/` is mangled).
- **Detecting export completion:** the file size is not monotonic (a temporary 74 MB file shrinks to
  39 MB at the end). Done means the size is stable and only the main window is open (the progress
  window is gone).
- **Cycle and the "export cycle area" checkbox did not change the exported length** in the tested
  project and are left alone.
- The Share menu item and dialog controls are matched by English names.
- GarageBand may need a moment after activation; `readTrackNamesWhenReady` retries the first read.

## AppleScript pitfalls seen here

- String comparison ignores case by default; option parsing uses `considering case` (`-p` vs `-P`).
- `value of x is 1` parses as `value of (x is 1)`; parenthesize.
- `item 2 of size of element` fails; store the size in a variable first.
- Inside `tell application "System Events"`, call own handlers with `my`.
- `before` and `number` are reserved words; do not use them as variable names.
- Merge records with `{key:value} & options`; the left record wins.

## Conventions

Plain full-word names, no comments (name things instead), minimal nesting with early `return`,
small handlers. Keep the whole file reading as one consistent style when you edit it.

## Ideas for extension

Skip muted tracks, a dry-run flag, other formats via `afconvert`, localized menu names, a progress
count (`Exporting 3/16`).
