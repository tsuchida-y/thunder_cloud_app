# App Store 用のスクリーンショット（2.0.0）

実際のアプリの画面だけを使い、見出しをつけた画像。値段や「無料」の言葉は入れない（審査 2.3.7）。通知・ウィジェット・Plus の絵は入れない（審査 2.3.3）。

- `iPhone_6.9インチ`（1320×2868）、`iPhone_6.5インチ`（1284×2778）、`iPhone_6.3インチ`（1206×2622）、`iPad_13インチ`（2064×2752）。どれも4枚（1_ホーム、2_方角ガイド、3_向きが合ったとき、4_設定）。透過なし。
- App Store Connect の「メディアマネージャー」で、全サイズの古い画像を消してから入れ替える。
- `作り方/` に、作る手順のスクリプト（promo.py、place_sets.py）。元の画面の撮り方は docs/引き継ぎメモ.md（store-screenshots ブランチ）。
- 2026-11-11: 設定の画像の見出しの下を「夜のあいだは、自動でお休みします」にした（以前は「Plus なら90kmまで」）。

## 英語（米国）用（2.0.1。2026-11-16）

`en-US/` に、日本語と同じ4枚（1_Home、2_Direction guide、3_Facing it、4_Settings）を、4つのサイズ（`iPhone_6.9inch`、`iPhone_6.5inch`、`iPhone_6.3inch`、`iPad_13inch`）で置いた。値段と「free」の言葉は入っていない（iPad の設定の Plus の帯は、日本語版と同じく背景で隠した）。

- 撮り方: 英語のシミュレーター（iPhone 18 Pro Max と iPad Pro 13-inch）で、デバッグ版を入れ、Mac の `/tmp/thundercloud_start_screen`（画面の名前）と `/tmp/thundercloud_fake_heading`（向き。100 で「右へ35°」、135 で「向きが合ったとき」）に書いて起動し、`xcrun simctl io <機器> screenshot` で撮る。時計は `simctl status_bar override --time 9:41`。
- 見出しは `作り方/promo_en.py`、書き出しは `作り方/place_sets_en.py`。
- App Store Connect の 2.0.1 の画面で「英語（米国）」を追加し、メディアマネージャーに入れる。
