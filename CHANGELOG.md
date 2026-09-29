# Changelog

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
