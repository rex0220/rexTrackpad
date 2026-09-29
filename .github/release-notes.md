## Install / インストール

1. Download `rexTrackpad-*.zip` below, unzip it and move `rexTrackpad.app` to `/Applications`.
   下の `rexTrackpad-*.zip` をダウンロードして展開し、`rexTrackpad.app` を `/Applications` に移動します。
2. Open it. The app is **not notarized**, so macOS blocks the first launch: click **Done**, then
   System Settings › Privacy & Security › **Open Anyway**.
   起動します。Apple の**公証を受けていない**ため初回はブロックされます。「完了」を押し、
   システム設定 › プライバシーとセキュリティ › **このまま開く** を選んでください。
3. Allow **Accessibility** when asked (needed to send ⌘R, ⌘T, … to the browser).
   求められたら**アクセシビリティ**を許可します（ブラウザーに ⌘R などを送るために必要）。

**Updating / アップデート:** replace the app, then run
`tccutil reset Accessibility com.rex0220.rexTrackpad`, open it and allow Accessibility again.
アプリを置き換えたら上のコマンドを実行し、起動してアクセシビリティを許可し直してください。

The zip is built from this tag by GitHub Actions (`scripts/release.sh`); verify it with the `.sha256` file.
zip はこのタグのソースから GitHub Actions でビルドしています。`.sha256` で検証できます。

Details: [README](https://github.com/rex0220/rexTrackpad#installation) / [日本語 README](https://github.com/rex0220/rexTrackpad/blob/main/README.ja.md#インストール)
