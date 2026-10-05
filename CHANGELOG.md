# Changelog

## 0.5.0 — 2026-10-05

### Added
- **Page actions**: Top of Page, Bottom of Page, Page Up and Page Down (Home / End /
  Page Up / Page Down in every browser). By default a 3-finger tap on the top edge
  goes to the top of the page, and taps in the bottom-left / bottom-right corners
  page up / down.
- **Tap zones in a 3 × 3 grid**: a 3-finger tap now also tells the top and bottom
  edges and the four corners apart, besides the left / right sides and the middle.
  Settings › Assignments shows the 3-finger taps as a grid laid out like the
  trackpad. An area without its own action falls back to its side (corners) or to
  the plain tap, so existing assignments keep working.
- Settings › Sensitivity: *Top / bottom zone height*, and a preview of the zones with
  your last 3-finger taps on it, to tune the zone sizes on your trackpad.

### Changed
- One-finger circles now reopen the last closed tab (clockwise) and close the tab
  (counter-clockwise) by default (were Forward / Back). Existing saved assignments
  are kept.
- Settings › Assignments lists the one-finger circles right below the 3-finger taps.

### 日本語
- **追加**: ページ操作「ページの先頭へ」「ページの最後へ」「1 画面上へ」「1 画面下へ」
  （どのブラウザーでも Home / End / Page Up / Page Down を送ります）。初期設定では、
  3本指タップの上端が「ページの先頭へ」、左下・右下の隅が「1 画面上へ」「1 画面下へ」です。
- **追加**: 3本指タップの区域を 3×3 にしました。左側・右側・中央に加えて、上端・下端と
  4 つの隅を区別します。設定の「割り当て」タブでは、3本指タップをトラックパッドと同じ並びの
  マスで選びます。割り当てがない区域は、隅ならその側（左側・右側）、それ以外は普通のタップと
  同じ操作になるので、今の割り当てはそのまま使えます。
- **追加**: 設定の「感度」タブに「上下の区域の高さ」と、最近の3本指タップの位置を区域の図に
  表示するプレビューを追加しました。お使いのトラックパッドに合わせて区域の大きさを調整できます。
- **変更**: 1本指の円の初期設定を、時計回りが「閉じたタブを開き直す」、反時計回りが「タブを閉じる」
  に変更しました（以前は進む／戻る）。保存済みの割り当てはそのまま残ります。
- **変更**: 設定の「割り当て」タブで、1本指の円を3本指タップのすぐ下に表示するようにしました。

## 0.4.1 — 2026-10-01

### Fixed
- **Open Link in New Tab** sometimes did nothing even with the pointer over the
  browser: Notification Center's transparent, click-through window was mistaken for
  the window under the pointer. rexTrackpad now asks the window server which window
  a click would reach.

### Changed
- The README now explains that the symbol shown for Open Link in New Tab means the
  click was sent; it also appears where there is no link (the browser then does
  nothing).

### 日本語
- **修正**: ポインターがブラウザーの上にあっても「リンクを新しいタブで開く」が効かないことが
  ありました。通知センターが置いている、クリックを素通りさせる透明なウィンドウを、ポインターの
  下のウィンドウと誤判定していたためです。クリックが実際に届くウィンドウをウィンドウサーバーに
  問い合わせるようにしました。
- **変更**: 「リンクを新しいタブで開く」で表示される記号は「クリックを送った」ことを表し、リンクの
  ない場所でも表示される（ブラウザー側では何も起きない）ことを README に書きました。

## 0.4.0 — 2026-09-30

### Added
- **Gesture feedback**: when a gesture sends an action to the browser, a small,
  slightly translucent symbol for the action appears near the pointer for about
  0.7 s. It never takes focus, lets clicks through and is shown after the shortcut
  is sent, so it does not delay the action. Turn it off in Settings › Assignments.

### Fixed
- The Close button of the settings window was cut off on some screens.

### 日本語
- **追加**: ジェスチャーが効いたことの表示。ブラウザーに操作を送ると、ポインターの近くに操作を
  表す半透明の小さな記号が約 0.7 秒表示されます。フォーカスを奪わず、クリックも素通りし、
  操作を送った後に表示するので操作は遅くなりません。設定の「割り当て」タブでオフにできます。
- **修正**: 画面によって、設定ウィンドウの「閉じる」ボタンがはみ出していた問題を直しました。

## 0.3.3 — 2026-09-30

### Changed
- The note in Settings › Permissions now explains what to do after an update (remove
  rexTrackpad from the Accessibility list, open it again and allow it), instead of a
  developer note about rebuilding.

### 日本語
- **変更**: 設定の「権限」タブの注意書きを、アップデートしたときの対処（アクセシビリティの一覧から
  削除して、rexTrackpad を開き直して許可し直す）に書き換えました。

## 0.3.2 — 2026-09-30

### Changed
- 3-finger taps on the left / right side of the trackpad now switch to the previous /
  next tab by default (were Back / Forward, which one-finger circles now cover).
  Existing saved assignments are kept.

### 日本語
- **変更**: 3本指タップの左側・右側の初期設定を、前のタブ／次のタブ（タブ移動）に変更しました
  （以前は戻る／進む。戻る・進むは1本指の円で操作できます）。保存済みの割り当てはそのまま残ります。

## 0.3.1 — 2026-09-30

### Changed
- One-finger circles are assigned by default: clockwise → Forward, counter-clockwise →
  Back. They work without changing any macOS settings. (Existing saved assignments are
  kept; use *Restore Default Gestures* to get the new defaults.)

### 日本語
- **変更**: 1本指の円に初期設定の操作を割り当てました（時計回り＝進む、反時計回り＝戻る）。
  macOS の設定を変えずに使えます。保存済みの割り当てはそのまま残るので、新しい初期設定に
  するには「ジェスチャーを初期設定に戻す」を押してください。

## 0.3.0 — 2026-09-30

### Added
- **Position-aware taps**: a 3-finger tap on the left or right side of the trackpad
  (by default: Back / Forward) can differ from a tap in the middle (Reload). The side
  width is adjustable in Settings › Sensitivity. A side without its own assignment acts
  like the plain 3-finger tap, so assignments saved by earlier versions keep working.
- **Circle gestures**: draw a circle with three fingers (default: clockwise → Reopen
  Closed Tab, counter-clockwise → Hard Reload) or with one finger (not assigned by
  default; the pointer moves while drawing). Minimum size and required turn are in
  Settings › Sensitivity. If you saved gesture assignments in an earlier version, the
  new gestures start unassigned: pick actions in Settings › Assignments, or press
  *Restore Default Gestures*.
- **Reopen Closed Tab** action (⇧⌘T).

### Changed
- **One settings window** (menu › Settings…, ⌘,) with four tabs — Assignments,
  Sensitivity, Browsers, Permissions — replaces the Gestures / Supported Browsers
  submenus and the separate Permissions window. All gestures are assigned from one
  list of pop-ups, and gestures also used by macOS are marked.
- The settings window closes with **Close**, esc or ⌘W and has no minimise button.
- The menu is now: Enabled, Launch at Login, Settings…, About, Quit.
- Sensitivity settings now store only the values you changed, so improved defaults in
  later versions reach the other thresholds. If you moved a sensitivity slider in an
  earlier version, press *Restore Default Sensitivity* once.

### 日本語
- **追加**: 位置で分けるタップ。トラックパッドの左側・右側での3本指タップに、中央
  （再読み込み）とは別の操作を割り当てられます（初期設定は左側＝戻る、右側＝進む）。
  区域の幅は設定の「感度」タブで調整できます。左右に割り当てがない場合は普通の
  3本指タップと同じ動作なので、以前のバージョンで保存した割り当てもそのまま使えます。
- **追加**: 円のジェスチャー。3本指で円を描く（初期設定: 時計回り＝閉じたタブを開き直す、
  反時計回り＝強制再読み込み）、または1本指で円を描く（初期設定は割り当てなし。描いている
  間ポインターも動きます）。最小の大きさと必要な回転角は設定の「感度」タブで変えられます。
  以前のバージョンでジェスチャーの割り当てを保存していた場合、新しいジェスチャーは
  割り当てなしで始まります。設定の「割り当て」タブで操作を選ぶか、「ジェスチャーを
  初期設定に戻す」を押してください。
- **追加**: 「閉じたタブを開き直す」（⇧⌘T）。
- **変更**: 設定を 1 つのウィンドウ（メニューの「設定…」、⌘,）にまとめました。「割り当て」
  「感度」「ブラウザー」「権限」の 4 タブで、全ジェスチャーをポップアップの一覧から割り当て
  られます。macOS と重複するジェスチャーには印が付きます。「ジェスチャー」「対応ブラウザー」
  のサブメニューと、別になっていた権限のウィンドウはなくなりました。
- **変更**: 設定ウィンドウは「閉じる」ボタン、esc、⌘W で閉じられます（しまうボタンは廃止）。
- **変更**: メニューは「有効」「ログイン時に起動」「設定…」「rexTrackpad について」「終了」です。
- **変更**: 感度の設定は、変更した項目だけを保存するようになりました。今後のバージョンで
  初期値が改善されると、変更していない項目に反映されます。以前のバージョンで感度の
  スライダーを動かしていた場合は、一度「感度を初期設定に戻す」を押してください。

## 0.2.0 — 2026-09-29

### Added
- **Open Link in New Tab**: point at a link and tap with four fingers to open it in a
  new tab and switch to it (⌘⇧-click at the pointer; Chrome, Safari, Edge, Firefox).
  The click is only sent when the pointer is over the frontmost browser's window.

### Changed
- The default for the 4-finger tap is now *Open Link in New Tab* (was *Hard Reload*).
  Hard Reload can still be assigned from the menu › Gestures.
- If you changed gesture assignments in 0.1.0, your saved assignments are kept. Use
  menu › Gestures › *Restore Default Gestures* to switch to the new defaults.

### 日本語
- **追加**: リンクの上で4本指タップをすると、そのリンクを新しいタブで開いて移動します
  （ポインター位置での ⌘⇧＋クリック。Chrome・Safari・Edge・Firefox）。ポインターが前面の
  ブラウザーのウィンドウの上にあるときだけクリックを送ります。
- **変更**: 4本指タップの初期設定を「強制再読み込み」から「リンクを新しいタブで開く」に
  変更しました。強制再読み込みはメニューの「ジェスチャー」から割り当てられます。
- 0.1.0 でジェスチャーの割り当てを変更していた場合は、その設定が引き継がれます。新しい
  初期設定にするには、メニューの「ジェスチャー」›「ジェスチャーを初期設定に戻す」を選んでください。

## 0.1.0 — 2026-09-29

First release / 最初のリリース

- 3- and 4-finger taps and swipes for reload, hard reload, previous / next tab, new tab,
  close tab, back and forward in Chrome, Safari, Edge and Firefox
- Automatic avoidance of macOS system gestures, per-browser switches, Launch at Login,
  English and Japanese UI
- 3本指・4本指のタップとスワイプで、再読み込み・強制再読み込み・タブ移動・新しいタブ・
  タブを閉じる・戻る・進むを操作（Chrome・Safari・Edge・Firefox）
- macOS 標準ジェスチャーとの競合回避、ブラウザー別の有効/無効、ログイン時に起動、日本語表示
