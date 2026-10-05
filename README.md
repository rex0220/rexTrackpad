# rexTrackpad

English | [日本語](README.ja.md)

Trackpad gesture utility for macOS.

rexTrackpad is a small menu bar app that turns multi-finger trackpad gestures into
browser commands for Google Chrome, Safari, Microsoft Edge and Firefox. It only
**observes** touches — it never blocks or consumes trackpad events — so normal
clicking, scrolling and macOS gestures keep working.

> Status: v0.5 (early development). See [CHANGELOG](CHANGELOG.md).

📘 **Introduction article (Japanese, with screenshots)**: [Qiita](https://qiita.com/rex0220/items/48411ca049dc6f3fc5e9)

## Features

- Browser reload
- Hard reload
- Previous / next tab
- Back / forward
- New tab
- Close tab
- Open the link under the pointer in a new tab
- Top / bottom of the page, page up / page down
- Position-aware taps: the trackpad is split into a 3 × 3 grid, so a 3-finger tap
  in a corner, on an edge or in the middle can each do something different
- Circle gestures: draw a circle with three fingers or one finger, clockwise or
  counter-clockwise
- Reopen the last closed tab
- Per-browser enable / disable
- Assign any action to any gesture in one settings window
- A small, translucent symbol near the pointer confirms each gesture (can be turned off)
- Automatic protection against collisions with macOS system gestures
- Launch at Login (`SMAppService`)
- Debug Monitor (Debug builds) showing live touches, direction, distance and duration
- English and Japanese UI (follows the macOS language)

## Supported Browsers

| Browser | Bundle identifiers |
|---|---|
| Chrome | `com.google.Chrome` (+ `.beta`, `.dev`, `.canary`) |
| Safari | `com.apple.Safari`, `com.apple.SafariTechnologyPreview` |
| Edge | `com.microsoft.edgemac` (+ `.Beta`, `.Dev`, `.Canary`) |
| Firefox | `org.mozilla.firefox`, `org.mozilla.firefoxdeveloperedition`, `org.mozilla.nightly` |

When any other app is frontmost, gestures do nothing.

## Default Gestures

| Gesture | Action | Works out of the box? |
|---|---|---|
| 3-finger tap (middle) | Reload | ✅ Yes (unless "Look up: Tap with three fingers" is on) |
| 3-finger tap (left side) | Previous Tab | ✅ Yes (same condition) |
| 3-finger tap (right side) | Next Tab | ✅ Yes (same condition) |
| 3-finger tap (top edge) | Top of Page | ✅ Yes (same condition) |
| 3-finger tap (bottom-left / bottom-right corner) | Page Up / Page Down | ✅ Yes (same condition) |
| 4-finger tap | Open Link in New Tab (link under the pointer) | ✅ Yes |
| 3-finger swipe left | Previous Tab | ⚠️ Only if macOS is not using 3-finger horizontal swipes |
| 3-finger swipe right | Next Tab | ⚠️ Only if macOS is not using 3-finger horizontal swipes |
| 3-finger swipe up | New Tab | ⚠️ Only if Mission Control is not on 3-finger swipe up |
| 3-finger swipe down | Close Tab | ⚠️ Only if App Exposé is not on 3-finger swipe down |
| 4-finger swipe left | Back | ⚠️ Only if macOS is not using 4-finger horizontal swipes |
| 4-finger swipe right | Forward | ⚠️ Only if macOS is not using 4-finger horizontal swipes |
| 3-finger circle, clockwise | Reopen Closed Tab | ⚠️ Only if macOS is not using 3-finger swipes (a circle starts like a swipe) |
| 3-finger circle, counter-clockwise | Hard Reload | ⚠️ Same condition |
| 1-finger circle, clockwise | Reopen Closed Tab | ✅ Yes — the pointer moves while you draw |
| 1-finger circle, counter-clockwise | Close Tab | ✅ Yes (same) |

### Why some gestures are "off" by default

With default System Settings, macOS already uses 3- and 4-finger swipes for
*Swipe between full-screen apps*, *Mission Control* and *App Exposé*. rexTrackpad
cannot stop those (it deliberately never blocks events), so a colliding swipe
would run **both** the macOS gesture and the browser action.

Because not interfering with normal Mac operation is the top priority,
**Avoid macOS Gesture Conflicts** is on by default: rexTrackpad reads your
trackpad settings and ignores any gesture macOS is currently using. The menu marks
those gestures with *(off: macOS gesture)*.

Taps have no system counterpart by default, so they work immediately.

**To enable the tab-switching swipes**, move the macOS gestures to four fingers:

1. System Settings › Trackpad › More Gestures
2. *Swipe between full-screen applications* → **Swipe Left or Right with Four Fingers**
3. *Mission Control* → **Swipe Up with Four Fingers**, *App Exposé* → **Swipe Down with Four Fingers** (or off)

The 3-finger swipes then become available; the 4-finger back/forward swipes stay
off while macOS uses them. Remap any gesture in menu › **Settings…** › *Assignments*
— Hard Reload is not bound by default but can be assigned there.

## Menu and Settings

The menu bar icon's menu:

| Item | |
|---|---|
| **Enabled** | Master switch. When off, trackpad monitoring stops completely. |
| **Launch at Login** | Start rexTrackpad when you log in. |
| **Settings…** (⌘,) | Opens the settings window (below). |
| **⚠︎ Accessibility Permission Needed…** | Shown only while Accessibility is not granted. |
| **About rexTrackpad** / **Quit** | |

The settings window has four tabs and closes with **Close**, esc or ⌘W:

| Tab | Contents |
|---|---|
| **Assignments** | One pop-up per gesture; the 3-finger taps are laid out as a 3 × 3 grid like the trackpad. Gestures that macOS also uses are marked *Also used by macOS* (hover for the macOS feature); the *Avoid macOS gesture conflicts* and *Show a symbol near the pointer when a gesture works* switches and *Restore Default Gestures* are here too. |
| **Sensitivity** | Tap, swipe and repeat-protection thresholds. The tap zone sizes come with a preview that shows where your last 3-finger taps landed and which area they counted as. |
| **Browsers** | Turn gestures on / off per browser; browsers that are not installed are marked. |
| **Permissions** | Accessibility / Input Monitoring status and whether touch frames arrive. |

## Requirements

- macOS 13 Ventura or later (developed against the current macOS release)
- Apple Silicon or Intel Mac (Release builds are Universal)
- A built-in trackpad or Magic Trackpad
- Xcode 16 or later to build

## Installation

1. Download `rexTrackpad-<version>.zip` from
   [Releases](https://github.com/rex0220/rexTrackpad/releases), unzip it and move
   `rexTrackpad.app` to `/Applications`.
2. Open it. The app is **not notarized** (see below), so macOS blocks the first launch:
   1. In the *“rexTrackpad” Not Opened* dialog, click **Done**.
   2. Open System Settings › Privacy & Security, scroll to *Security* and click
      **Open Anyway** next to the rexTrackpad message.
   3. Click **Open Anyway** again and authenticate.

   Or, in Terminal: `xattr -dr com.apple.quarantine /Applications/rexTrackpad.app`
3. A hand icon appears in the menu bar (no Dock icon). Allow **Accessibility** when
   asked (see [Permissions](#permissions)).
4. Optional: menu › **Launch at Login**.

### Why is it not notarized?

Notarized apps require a paid Apple Developer Program membership. Releases are
ad-hoc signed instead and built by GitHub Actions from the tagged source
(`scripts/release.sh`, `.github/workflows/release.yml`); each release includes a
SHA-256 checksum. You can also [build it yourself](#build).

### Updating

Quit rexTrackpad, replace the app in `/Applications` and open it (you may need
*Open Anyway* again). macOS treats every ad-hoc signed build as a new app, so
reset and allow Accessibility again:

```sh
tccutil reset Accessibility com.rex0220.rexTrackpad
```

### Uninstalling

1. Menu › turn off **Launch at Login**, then **Quit**.
2. Delete `/Applications/rexTrackpad.app`.
3. Remove the permission and settings:

   ```sh
   tccutil reset Accessibility com.rex0220.rexTrackpad
   defaults delete com.rex0220.rexTrackpad
   ```

## Build

```sh
git clone https://github.com/rex0220/rexTrackpad.git
cd rexTrackpad
open rexTrackpad.xcodeproj          # then Product › Run
```

Command line:

```sh
# Debug build + unit tests
xcodebuild -project rexTrackpad.xcodeproj -scheme rexTrackpad -configuration Debug test

# Universal Release build (arm64 + x86_64)
xcodebuild -project rexTrackpad.xcodeproj -scheme rexTrackpad -configuration Release \
  -derivedDataPath build ONLY_ACTIVE_ARCH=NO
open build/Build/Products/Release

# Release zip for GitHub (ad-hoc signed, Universal) → dist/
scripts/release.sh
```

### Code signing

By default the project signs "to run locally" (ad hoc), so it builds without an
Apple developer account. Signing settings live in `Config/Signing.xcconfig`.

Ad-hoc signatures change on every build, and macOS then drops the Accessibility
permission (see [Permissions](#permissions)). To keep the permission across
rebuilds, sign with your own **Apple Development** certificate. A free Apple
Account ("Personal Team") is enough:

1. Xcode › Settings › Accounts › **+** › sign in with your Apple Account.
2. Create the local override (git-ignored) and put your Team ID in it:

   ```sh
   cp Config/Signing.local.xcconfig.example Config/Signing.local.xcconfig
   ```

3. Build once with `-allowProvisioningUpdates` (or from Xcode) so the
   certificate is created, then grant Accessibility one last time.

If a command-line build fails with `errSecInternalComponent`, the keychain is
locked: run `security unlock-keychain ~/Library/Keychains/login.keychain-db`.

Public releases are built by `scripts/release.sh`, which always signs ad hoc so no
personal certificate ends up in a download. Pushing a tag such as `v0.1.0` runs it
on GitHub Actions and publishes the zip to Releases. To ship a notarized build
instead, sign with a Developer ID certificate, then archive and notarize.

The project uses Xcode 16 synchronized folders: new `.swift` files dropped into
`rexTrackpad/` or `rexTrackpadTests/` are picked up automatically.

## Localization

The menu and the settings window follow the macOS language:
English (default) and Japanese. Strings live in `rexTrackpad/Localizable.xcstrings`
(Xcode String Catalog); add a language there to translate the app. The Debug
Monitor and log messages stay in English.

## Permissions

| Permission | Needed? | Why |
|---|---|---|
| Accessibility | **Required** | Sending synthetic key presses (⌘R, ⌘T, …) to the browser with `CGEvent`. |
| Input Monitoring | Not requested | Reading trackpad contacts via MultitouchSupport and observing mouse clicks with a global `NSEvent` monitor do not require it. |

Settings › **Permissions** shows the current status, can trigger the Accessibility
prompt and opens the right pane of System Settings. It also shows whether touch
frames are actually arriving, which helps diagnose problems.

Without Accessibility the app keeps running; gestures are recognised and logged but
no shortcut is sent.

> **Rebuilding:** ad-hoc signed builds get a new code signature every build, and
> macOS ties the Accessibility grant to it. If gestures stop working after a
> rebuild, run `tccutil reset Accessibility com.rex0220.rexTrackpad`, relaunch the
> app and allow it again — or set up [Apple Development signing](#code-signing) once.

## Launch at Login

Menu › **Launch at Login** registers the app with `SMAppService.mainApp`
(macOS 13+). If macOS asks for approval, the item shows *(approve in System
Settings)* and opens *General › Login Items*. Legacy login-item APIs are not used.

## Settings

Stored in `UserDefaults` (`defaults read com.rex0220.rexTrackpad`):

| Key | Meaning |
|---|---|
| `Enabled` | Master switch. When off, trackpad monitoring is stopped completely. |
| `LaunchAtLogin` | Last requested state (the actual state comes from `SMAppService`). |
| `ChromeEnabled`, `SafariEnabled`, `EdgeEnabled`, `FirefoxEnabled` | Per-browser switches. |
| `GestureMappings` | JSON, e.g. `{"tap.3":"browser.reload","swipe.4.left":"browser.back"}` |
| `AvoidSystemGestureConflicts` | Ignore gestures macOS is using (default on). |
| `GestureConfiguration` | Recognition thresholds (also editable in Settings › *Sensitivity*). |

## Browser Shortcuts

Actions are resolved per browser (`BrowserCommandProvider`), so a browser with
different shortcuts only needs its own provider.

| Action | Chrome / Edge | Safari | Firefox |
|---|---|---|---|
| Reload | ⌘R | ⌘R | ⌘R |
| Hard Reload | ⇧⌘R | ⌥⌘R (Reload Page From Origin) | ⇧⌘R |
| Next Tab | ⌃⇥ | ⌃⇥ | ⌥⌘→ |
| Previous Tab | ⌃⇧⇥ | ⌃⇧⇥ | ⌥⌘← |
| New Tab | ⌘T | ⌘T | ⌘T |
| Close Tab | ⌘W | ⌘W | ⌘W |
| Reopen Closed Tab | ⇧⌘T | ⇧⌘T | ⇧⌘T |
| Back | ⌘[ | ⌘[ | ⌘[ |
| Forward | ⌘] | ⌘] | ⌘] |
| Open Link in New Tab | ⌘⇧-click at the pointer | ⌘⇧-click at the pointer | ⌘⇧-click at the pointer |
| Top of Page / Bottom of Page | Home / End | Home / End | Home / End |
| Page Up / Page Down | Page Up / Page Down | Page Up / Page Down | Page Up / Page Down |

Firefox uses ⌥⌘→/← because ⌃⇥ can be set to cycle tabs in recently-used order.
Character keys (`R`, `T`, `W`, `[`, `]`) are resolved against the active keyboard
layout when sent, so ⌘[ / ⌘] also work on JIS and other non-US keyboards.

The page actions send Home / End / Page Up / Page Down rather than Space / ⇧Space,
which would type a space into a focused text field. Like any key, they go to what
has keyboard focus: in a text field they move the cursor instead of the page, and
in a scrollable part of the page (a chat pane, say) they scroll that part.

Because the browsers' own shortcuts are sent (rather than reading the tab strip),
tab switching also works with vertical tabs (Chrome, Edge and Firefox vertical
tabs, Safari's sidebar).

**Open Link in New Tab** clicks where the mouse pointer is, with ⌘⇧ held, so the
link opens in a new tab that becomes active. rexTrackpad never reads page content,
so it cannot tell whether a link is under the pointer; the click is only sent when
the pointer is over a window of the frontmost browser (never onto the menu bar,
the Dock or another app). Only the owner of the window under the pointer is read
for this check. The symbol near the pointer therefore means the click was sent, not
that a link opened: over a spot without a link it still appears, and the browser
simply does nothing.

## Architecture

```
MultitouchTrackpadProvider   (private API, isolated)      Trackpad/
        │  TrackpadFrame / TouchPoint
        ▼
GestureEngine → GestureRecognizer (state machine, 1 per device)   Gesture/
        │  TrackpadGesture
        ▼
SystemGestureConflictDetector (skip gestures macOS uses)          Gesture/
        ▼
ActionDispatcher: GestureMapping → GestureAction                   Actions/
        ▼
BrowserDetector → BrowserCommandResolver (per-browser providers)  Browser/
        │  KeyboardShortcut
        ▼
CGKeyboardEventSender (+ KeyboardLayoutResolver)                   Keyboard/
```

Other folders: `App/` (entry point, composition root), `MenuBar/` (status menu,
Permissions / Settings windows), `Permissions/`, `Login/`, `Settings/`,
`Support/` (logging), `Debug/` (Debug-only monitor).

### Gesture recognition

- A *session* runs from the first finger down to the last finger up and fires **at
  most one gesture** (`idle → tracking → recognized / waitingForRelease → idle`).
- **Tap**: max finger count ≥ 3, all fingers land within 0.15 s, whole tap ≤ 0.35 s,
  no finger moves more than 0.05, and no physical click happened.
  - The centre of the landing points decides the area of a 3 × 3 grid: within 35 %
    of the width from the left / right edge is the *left* / *right side*, within 30 %
    of the height from the top / bottom edge is the *top* / *bottom edge*, both at
    once is a *corner*, and the middle cell is a plain tap (both sizes are adjustable
    in Settings › *Sensitivity*). An area without its own assignment falls back:
    corner → its side → plain tap, and top / bottom edge → plain tap.
- **Swipe**: average travel ≥ 0.12 (trackpad heights) within 0.6 s, dominant axis
  ≥ 2× the other (rejects diagonals), speed ≥ 0.4/s, and every finger moving the
  same way (rejects pinch/rotate).
  - When all fingers land together (within 0.15 s), travel is measured from each
    finger's landing point, and a short flick is judged once more when the fingers
    lift (landing point → last touching position). Fingers land ~30 ms apart, so a
    quick vertical flick is mostly over before the last finger settles.
  - When a finger joins later (e.g. a third finger added to a two-finger scroll),
    travel is only measured from that moment.
  - A recognised swipe **fires when the fingers lift**: shortcuts sent while fingers
    are still moving race with the trackpad's own events, and Chrome then
    intermittently ignored ⌃Tab.
- **Circle**: judged when the fingers lift, on the last 1.5 s of the fingers' centre.
  The shortest stretch at the end that turns at least 300° (one finger: 330°),
  consistently one way (≥ 90 %), around a roughly constant radius (spread ≤ 35 %) of
  at least 0.06 trackpad heights, in 0.25–1.5 s, is a circle — so moving the pointer
  first and then drawing without lifting works. A circle wins over the swipe its
  start may look like. Near misses (half a turn or more) are logged with the reason.
- A 0.35 s cooldown after each gesture plus a 0.2 s dispatcher debounce prevent
  double firing.
- **Shortcuts are typed like a person would**: modifier keys down one by one, the
  key down/up, modifiers up, with a few milliseconds between events. Some shortcuts
  (Chrome's ⌃Tab) check the live modifier state rather than the key event's flags.

Thresholds live in `GestureConfiguration` and can be tuned in Settings › *Sensitivity*.

## Logging & Debugging

```sh
log stream --predicate 'subsystem == "com.rex0220.rexTrackpad"' --level debug
```

In zsh, `log` clashes with a shell builtin; run it as `/usr/bin/log`.

Logged events include monitoring start/stop, gesture begin / recognized /
rejected, frontmost app and bundle identifier, browser matched / ignored, browser
action, keyboard shortcut sent, missing permissions and debounce.
High-frequency details (`Log.verbose`) are compiled out of Release builds.

Debug builds add **Debug Monitor…** to the menu: live finger count, touch
coordinates, direction, distance, duration, recognizer state and recent events.

## Known Limitations

- **System gesture overlap.** rexTrackpad observes but never blocks input. If you
  turn off *Avoid macOS Gesture Conflicts*, a colliding swipe runs both the macOS
  gesture and the browser action.
- **Setting changes made while the menu is closed** (e.g. in System Settings) are
  picked up the next time a gesture fires or the menu opens.
- **Physical clicks** with 3+ fingers cancel the tap; very light "tap-to-click"
  taps with 3 fingers are treated as taps.
- **Palm contact**: sessions with more than 5 contacts are ignored; there is no
  further palm rejection yet.
- **Open Link in New Tab** acts on whatever is under the pointer: on a button
  instead of a link it presses that button (with ⌘⇧ held).
- **Keyboard focus**: shortcuts go to the frontmost window. Web pages that capture
  keys (some editors, games) may intercept them.
- **Trackpad aspect ratio** is assumed to be 1.6:1 for direction/distance maths.
- **Sleep/wake & hot-plug**: monitoring restarts automatically after wake and when
  a Magic Trackpad connects; there may be a ~1–2 s gap.
- **Gesture mapping upgrades**: gestures added as defaults in future versions will
  not appear automatically in an existing custom mapping (use Settings › *Assignments* ›
  *Restore Default Gestures*).

## Private APIs

rexTrackpad uses Apple's **private `MultitouchSupport.framework`** to read raw
trackpad contacts. There is no public API that reports 3/4-finger taps and swipes
system-wide:

- `NSEvent` / `NSGestureRecognizer` only deliver touches to your own windows.
- `CGEventTap` sees gesture events but not per-finger contacts or finger counts,
  and needs Input Monitoring/Accessibility.

Consequences:

- **Not suitable for the Mac App Store** (private API use and no App Sandbox).
- **May break with macOS updates.** The framework is undocumented; Apple can change it at any time.
- The private code is isolated in `rexTrackpad/Trackpad/Private/`
  (`MultitouchTrackpadProvider.swift` + `MultitouchSupportBridge.h`). The
  framework is loaded with `dlopen` at runtime, so if it is ever missing the app
  still launches and reports trackpad input as *Unavailable*.
- Everything else depends only on the `TrackpadInputProvider` protocol, so the
  input source can be replaced without touching gesture or action code.

## Prior Art

Studied (not copied) while designing the recognizer:

- [MiddleClick](https://github.com/artginzburg/MiddleClick) — GPL-3.0. Only its
  documented behaviour was used as reference; no code from it is included.
- [MiddleDrag](https://github.com/NullPointerDepressiveDisorder/MiddleDrag) — MIT.
- [OpenMultitouchSupport](https://github.com/Kyome22/OpenMultitouchSupport) — MIT.

rexTrackpad's code is written independently.

## License

[MIT](LICENSE) © 2026 rex0220
