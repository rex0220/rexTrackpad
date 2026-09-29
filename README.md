# rexTrackpad

Trackpad gesture utility for macOS.

rexTrackpad is a small menu bar app that turns multi-finger trackpad gestures into
browser commands for Google Chrome, Safari, Microsoft Edge and Firefox. It only
**observes** touches — it never blocks or consumes trackpad events — so normal
clicking, scrolling and macOS gestures keep working.

> Status: v0.1 (early development).

## Features

- Browser reload
- Hard reload
- Previous / next tab
- Back / forward
- New tab
- Close tab
- Per-browser enable / disable
- Rebind any gesture to any action from the menu
- Automatic protection against collisions with macOS system gestures
- Launch at Login (`SMAppService`)
- Debug Monitor (Debug builds) showing live touches, direction, distance and duration

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
| 3-finger tap | Reload | ✅ Yes (unless "Look up: Tap with three fingers" is on) |
| 4-finger tap | Hard Reload | ✅ Yes |
| 3-finger swipe left | Previous Tab | ⚠️ Only if macOS is not using 3-finger horizontal swipes |
| 3-finger swipe right | Next Tab | ⚠️ Only if macOS is not using 3-finger horizontal swipes |
| 3-finger swipe up | New Tab | ⚠️ Only if Mission Control is not on 3-finger swipe up |
| 3-finger swipe down | Close Tab | ⚠️ Only if App Exposé is not on 3-finger swipe down |
| 4-finger swipe left | Back | ⚠️ Only if macOS is not using 4-finger horizontal swipes |
| 4-finger swipe right | Forward | ⚠️ Only if macOS is not using 4-finger horizontal swipes |

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
off while macOS uses them. Remap any gesture from **Gestures ›** in the menu.

## Requirements

- macOS 13 Ventura or later (developed against the current macOS release)
- Apple Silicon or Intel Mac (Release builds are Universal)
- A built-in trackpad or Magic Trackpad
- Xcode 16 or later to build

## Installation

There are no signed binary releases yet; build from source:

1. Build a Release copy (see below) and move `rexTrackpad.app` to `/Applications`.
2. Launch it. A hand icon appears in the menu bar (no Dock icon).
3. Grant **Accessibility** when prompted (see [Permissions](#permissions)).

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

To distribute, sign with a Developer ID certificate, then archive and notarize.

The project uses Xcode 16 synchronized folders: new `.swift` files dropped into
`rexTrackpad/` or `rexTrackpadTests/` are picked up automatically.

## Permissions

| Permission | Needed? | Why |
|---|---|---|
| Accessibility | **Required** | Sending synthetic key presses (⌘R, ⌘T, …) to the browser with `CGEvent`. |
| Input Monitoring | Not requested | Reading trackpad contacts via MultitouchSupport and observing mouse clicks with a global `NSEvent` monitor do not require it. |

Menu › **Permissions…** shows the current status, can trigger the Accessibility
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
| `GestureConfiguration` | Recognition thresholds (also editable in *Gesture Settings…*). |

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
| Back | ⌘[ | ⌘[ | ⌘[ |
| Forward | ⌘] | ⌘] | ⌘] |

Firefox uses ⌥⌘→/← because ⌃⇥ can be set to cycle tabs in recently-used order.
Character keys (`R`, `T`, `W`, `[`, `]`) are resolved against the active keyboard
layout when sent, so ⌘[ / ⌘] also work on JIS and other non-US keyboards.

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
- **Swipe**: finger count stable for 30 ms, average travel ≥ 0.20 (trackpad heights)
  within 0.6 s, dominant axis ≥ 2× the other (rejects diagonals), speed ≥ 0.4/s,
  and every finger moving the same way (rejects pinch/rotate). Once a finger lifts,
  no swipe can fire in that session.
- A 0.35 s cooldown after each gesture plus a 0.2 s dispatcher debounce prevent
  double firing.

Thresholds live in `GestureConfiguration` and can be tuned in *Gesture Settings…*.

## Logging & Debugging

```sh
log stream --predicate 'subsystem == "com.rex0220.rexTrackpad"' --level debug
```

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
- **Keyboard focus**: shortcuts go to the frontmost window. Web pages that capture
  keys (some editors, games) may intercept them.
- **Trackpad aspect ratio** is assumed to be 1.6:1 for direction/distance maths.
- **Sleep/wake & hot-plug**: monitoring restarts automatically after wake and when
  a Magic Trackpad connects; there may be a ~1–2 s gap.
- **Gesture mapping upgrades**: gestures added as defaults in future versions will
  not appear automatically in an existing custom mapping (use *Restore Default Gestures*).

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
