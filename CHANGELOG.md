# Changelog

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
