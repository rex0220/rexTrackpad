# rexTrackpad 設計メモ（調査結果と判断）

v0.1 実装時点（2026-09）の調査結果と設計判断をまとめたもの。
「確認済み」は一次情報（Apple / 各ブラウザーのドキュメント）またはコードで確認したもの、
「推定」は実機での検証が必要なもの。

## 1. トラックパッド入力方式の比較

| 方式 | 3/4本指の判定 | タップ | スワイプ方向 | 他アプリ前面時 | 通常操作を阻害 | 権限 | 非公開API | OS更新リスク |
|---|---|---|---|---|---|---|---|---|
| NSEvent（touches / gesture events） | 自ウィンドウ内のみ | 自ウィンドウ内のみ | 自ウィンドウ内のみ | ✗ | しない | 不要 | 公開 | 低 |
| NSGestureRecognizer | 自ビューのみ | 可 | 可 | ✗ | しない | 不要 | 公開 | 低 |
| CGEventTap | 指本数・接触点は取れない（gesture/scroll のみ） | ✗ | 慣性スクロールから推定のみ | ○ | listen only なら阻害しない | Input Monitoring / Accessibility | 公開（gesture 型は非文書化） | 中 |
| **MultitouchSupport.framework** | **○（接触点ごと）** | **○** | **○** | **○** | **しない（観測のみ）** | 追加権限不要（推定、下記） | **非公開** | 高 |
| IOKit HID 直接 | デバイス生レポートの解析が必要 | 理論上可 | 理論上可 | ○ | 排他オープンすると阻害 | Input Monitoring | 公開だがプロトコル非公開 | 高 |

**採用: MultitouchSupport.framework**。システム全体で指ごとの接触点を観測できる実用的な手段は
これしかない（MiddleClick 系・BetterTouchTool 系も同じ方式）。リスクは以下で緩和した。

- `Trackpad/Private/` の 2 ファイルに隔離。他は `TrackpadInputProvider` プロトコルのみに依存。
- リンクせず `dlopen` / `dlsym` で実行時ロード → 消えてもアプリは起動し「Unavailable」表示。
- `MTDeviceCreateList` の戻り値は所有権が不明確なので `takeUnretainedValue`（過剰解放でのクラッシュ回避）。
- スリープ復帰（`NSWorkspace.didWakeNotification`）と IOKit の `AppleMultitouchDevice` 追加/削除通知で再起動。

### 権限
- **Accessibility: 必須**。`CGEvent.post` で合成キーイベントを送るため。
- **Input Monitoring: 要求しない**。MultitouchSupport の接触フレーム取得と、
  マウスボタンの `NSEvent` グローバルモニタは Input Monitoring を必要としない（MiddleClick 等も Accessibility のみを案内）。
  ただし一部 OSS（OpenMultitouchSupport）は必要と記載しているため **推定**。
  Permissions 画面に「受信フレーム数」を出し、0 のままなら Input Monitoring を付与して切り分けられるようにした。

## 2. macOS 標準ジェスチャーとの競合

| rexTrackpad 既定 | macOS 既定設定での用途 | 判定キー（`com.apple.AppleMultitouchTrackpad` / `com.apple.driver.AppleBluetoothMultitouch.trackpad`） |
|---|---|---|
| 3本指タップ | 既定は「強めのクリックで調べる」なので空き。「3本指でタップ」に変更時は競合 | `TrackpadThreeFingerTapGesture`（0=空き, 2=調べる） |
| 4本指タップ | 標準ジェスチャーなし | — |
| 3本指 左右 | フルスクリーンアプリ間スワイプ / ページ間スワイプ（3本指設定時） | `TrackpadThreeFingerHorizSwipeGesture`（0 以外で競合） |
| 3本指 上 | Mission Control | `TrackpadThreeFingerVertSwipeGesture` + `com.apple.dock showMissionControlGestureEnabled` |
| 3本指 下 | App Exposé | 同上 + `showAppExposeGestureEnabled` |
| 4本指 左右 | フルスクリーンアプリ間スワイプ | `TrackpadFourFingerHorizSwipeGesture` |
| 3本指 全般 | 「3本指のドラッグ」有効時 | `TrackpadThreeFingerDrag` |
| （参考）親指+3本指 ピンチ | Launchpad / デスクトップ表示 | 本アプリはピンチ未対応なので競合なし |

**結論: 既定設定では 6 つのスワイプすべてが競合する。** MultitouchSupport は観測専用で
イベントを止められないため、競合スワイプは macOS 側の動作とブラウザー操作が**両方**起きる。

**判断**
1. ジェスチャー割り当ての既定値は依頼どおり（ユーザーが後で使えるように）。
2. **「Avoid macOS Gesture Conflicts」を既定 ON**。上表のキーを読み、macOS が使っているジェスチャーは無視する。
   キー未設定時は「macOS 既定＝使用中」とみなす（安全側）。
3. その結果、**既定の macOS 設定では 3本指タップ（再読み込み）と 4本指タップ（強制再読み込み）だけが即動作**。
   System Settings でアプリ切替/Mission Control を「4本指」に変えると 3本指スワイプ（タブ移動・新規・閉じる）が有効になる。
4. イベントの consume / block は一切しない。

## 3. ブラウザーのショートカット（macOS）

| 操作 | Chrome / Edge | Safari | Firefox | 備考 |
|---|---|---|---|---|
| 再読み込み | ⌘R | ⌘R | ⌘R | |
| 強制再読み込み | ⇧⌘R | ⌥⌘R | ⇧⌘R | Safari は「ページをオリジンから再読み込み」 |
| 次のタブ | ⌃⇥ | ⌃⇥ | ⌥⌘→ | Safari 公式: ⌃⇥ / ⇧⌘] |
| 前のタブ | ⌃⇧⇥ | ⌃⇧⇥ | ⌥⌘← | Firefox の ⌃⇥ は「最近使った順」設定の影響を受けるため回避 |
| 新しいタブ | ⌘T | ⌘T | ⌘T | |
| タブを閉じる | ⌘W | ⌘W | ⌘W | |
| 戻る / 進む | ⌘[ / ⌘] | ⌘[ / ⌘] | ⌘[ / ⌘] | ⌘←/→ はテキスト欄でカーソル移動になるため不採用 |
| ページの先頭へ / 最後へ | Home / End | Home / End | Home / End | ⌘↑/↓ もページでは同じ動きだが、テキスト欄ではカーソル移動になる |
| 1 画面上へ / 下へ | Page Up / Page Down | Page Up / Page Down | Page Up / Page Down | Space / ⇧Space はテキスト欄で空白が入力されるため不採用 |

**JIS キーボード対策**: CGEvent は物理キーコードで送るため、ANSI の `[` 位置（0x21）を送ると JIS では `@` になる。
`KeyboardLayoutResolver` が `UCKeyTranslate` で現在の ASCII 対応レイアウトから「`[` を出すキー」を逆引きする。
取得できない場合のみ ANSI キーコードへフォールバック。⇧⌘] 系のタブ移動を採用しなかったのも同じ理由。

矢印キーは実機と同じく `maskSecondaryFn | maskNumericPad` を付与して送る。
Home / End / Page Up / Page Down は Mac のキーボードでは Fn＋矢印で入力されるため、`maskSecondaryFn` だけを付ける。

**ページ操作**: キー入力なのでフォーカスのある場所に届く。ポインター位置にスクロールホイールのイベントを送る案は、
フォーカスに関係なく動くが、1 画面分の量を決めるにはウィンドウの高さを読む必要があり、先頭・最後は大きな値で
代用することになるため不採用（v0.5）。

**リンクを新しいタブで開く**: ショートカットではなく、ポインター位置での ⌘⇧＋クリック
（4 ブラウザー共通。新しいタブで開いてそのタブに移る）。`BrowserCommand` を
`.shortcut` / `.click` の 2 種類にし、`PointerEventSender` が送る。ページ内容は読まないので
リンクかどうかは判定できない。代わりに「ポインター位置でクリックが届くウィンドウが前面の
ブラウザーのものか」を確認し、違えば送らない。ウィンドウは
`NSWindow.windowNumber(at:belowWindowWithWindowNumber:)`（ウィンドウサーバーのヒットテスト）で求め、
所有 PID だけを `CGWindowListCopyWindowInfo` で読む。ウィンドウ一覧の位置を前から順に比べる方式は、
通知センターが画面全体に置くクリック素通りの透明ウィンドウ（layer 21）を最前面と誤判定するため不採用（v0.4.1）。
2 本指タップ案は、この Mac の設定（タップでクリック＋2 本指で副ボタン）では右クリックと
競合するため不採用。初期設定は 4 本指タップ（強制再読み込みは割り当てなしに変更）。

**キーイベントの送り方**: 修飾キーを 1 つずつ押す → キーを押して離す → 修飾キーを逆順に離す、を
約 8ms 間隔で `hidSystemState` のイベントソースから送る。キーイベントの flags だけを付けて送る方式では、
修飾キーの実際の押下状態を見る Chrome の ⌃Tab（縦型タブ含む）が反応しなかった（実機で確認）。

## 4. Bundle Identifier

| ブラウザー | 安定版 | その他チャネル |
|---|---|---|
| Chrome | `com.google.Chrome` | `.beta` `.dev` `.canary` |
| Safari | `com.apple.Safari` | `com.apple.SafariTechnologyPreview` |
| Edge | `com.microsoft.edgemac` | `.Beta` `.Dev` `.Canary` |
| Firefox | `org.mozilla.firefox` | `org.mozilla.firefoxdeveloperedition`, `org.mozilla.nightly` |

実機確認: `osascript -e 'id of app "Google Chrome"'` などで確認できる。
将来候補: Brave `com.brave.Browser` / Arc `company.thebrowser.Browser` / Vivaldi `com.vivaldi.Vivaldi` /
Opera `com.operasoftware.Opera` / Chromium `org.chromium.Chromium`（Chromium 系は `ChromiumCommandProvider` 流用可、Arc はショートカット差異に注意）。

## 5. ジェスチャー認識と二重発火防止

- セッション = 最初の指が触れてから全指が離れるまで。**1 セッション最大 1 ジェスチャー**。
- 状態: `idle → tracking → recognized / waitingForRelease → idle`。
- タップはリリース時に評価し、指本数は**セッション中の最大値**（4本指タップが 3本指と誤認されない）。
- スワイプは指本数が 30ms 安定してから基準点（anchor）を取り、指ごとの変位の平均で判定。
  - 最小距離 / 最大時間（スライディングウィンドウ）/ 方向比（2.0 = 約 26.6° 以内）/ 最小速度 / 全指の方向一致。
  - 1 本でも指が離れたらそのセッションではスワイプ不可（離す動作での誤発火防止）。
  - 指はまとめて置いても約 30ms ずつずれて着地し、短く速い上下スワイプは最後の指が落ち着く前に大半が終わる。
    そのため全指が 0.15s 以内に着地した場合は**各指の着地点**から移動量を測り、さらに**全指が離れた時点**で
    「着地点 → 最後の接触位置」でもう一度判定する（実機ログで上下スワイプの約半数が失敗していたため）。
    後から指が加わった場合（2本指スクロール中に 3 本目を置く等）は、その時点から測る（誤発火防止）。
  - 最小距離は 0.12（トラックパッド高さ比）。実機の上下スワイプは 0.12〜0.15 程度だった。
  - スワイプは認識しても**全指が離れた時点で発火**する。指の移動中にキーイベントを送ると
    トラックパッド由来のイベントと競合し、Chrome の ⌃Tab が時々無視された（実機で確認）。
- 物理クリックは `NSEvent` グローバルモニタで検出してタップを無効化。
- 認識後 0.35s のクールダウン（新セッションを丸ごと無視）+ ディスパッチャ側 0.2s デバウンス。
- 1 秒以上フレームが途絶えたセッションは破棄（リリースフレーム欠落対策）。
- 座標は正規化値。x はアスペクト比 1.6 を掛けて縦横同じ物理量で比較。
- **タップの区域（v0.5）**: 着地点の中心で 3×3 の区域を決める（左右は幅の 35%、上下は高さの 30%）。
  中央の区域は普通のタップ。割り当てがない区域は 隅 → 左右 → 普通のタップ の順に代わりを使うので、
  隅ができる前の「左側」「右側」の割り当ては隅でもそのまま効く。
  1 本指・2 本指はタップでクリック・副ボタンのクリックになり、rexTrackpad はそれを止められないので対象外。
  区域の大きさは実機で調整する前提で、設定の「感度」タブに最近の 3 本指タップの位置を表示する。

## 6. OSS 参考実装とライセンス

| プロジェクト | ライセンス | 扱い |
|---|---|---|
| artginzburg/MiddleClick | **GPL-3.0** | MIT プロジェクトに取り込めないため**コードは一切参照・流用しない**。README 記載の挙動（時間/距離しきい値、Accessibility 必須）のみ参考 |
| NullPointerDepressiveDisorder/MiddleDrag | MIT | README の設計方針のみ参考 |
| Kyome22/OpenMultitouchSupport | MIT | 接触状態の意味など公開情報を参考 |

`MTTouch` 構造体レイアウトは広く流通しているリバースエンジニアリング情報に基づき、独自に `MultitouchSupportBridge.h` として記述。

## 7. 未検証事項（実機で要確認）

- [ ] MultitouchSupport の y 軸が下原点であること（Debug Monitor で上下スワイプを確認）
- [ ] Input Monitoring なしでフレームが届くこと（Permissions 画面の frames 数）
- [ ] ⌃⇥ が Chrome / Edge / Safari で、⌥⌘→ が Firefox で期待どおりタブ移動すること
- [ ] JIS キーボードで ⌘[ / ⌘] が戻る/進むになること
- [ ] Magic Trackpad の抜き差し・スリープ復帰後の再開
- [ ] `defaults read com.apple.AppleMultitouchTrackpad` の実値と競合判定の一致
- [ ] 3 本指タップの区域の大きさ（上下 30%）で、隅・上端・下端を狙いどおりに打てること
- [ ] Home / End / Page Up / Page Down が 4 ブラウザーでページをスクロールすること
