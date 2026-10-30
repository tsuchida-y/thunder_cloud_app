# 入道雲サーチ v2.0 コードレビュー（機能以外の品質）

2026-10-30、main（db468e9。PR #23 のマージ後）を読んで確認した。ファイルは変更していない（この REVIEW.md だけを足した）。

確かめたのは、リポジトリのコード、設定ファイル、Firestore / Storage のルール、Cloud Functions、pubspec、Info.plist、AndroidManifest。確かめられなかったのは、本番の Firebase コンソールの設定（API キーの制限、App Check、料金のアラート）、ストア側の申告の中身、実機での電池と通信量。そうしたものは「要確認」と書いた。

先に、よくできている点を書く。

- 秘密の合言葉（RevenueCat の webhook）は Secret Manager に入れていて、コードに書いていない。
- members と member_server を分けて、Plus かどうかはサーバーだけが書く作りになっている。本人が自分で Plus にはできない。
- 位置は約1kmに丸めて保存している。気象庁へのアクセスはサーバーから5分に1回で、アプリからは取りに行かない。
- 1年開いていない人の情報を消す関数がある。
- Plus の画面には、無料期間のあとの値段・自動更新・購入の復元・利用規約・プライバシーのリンクが揃っている。
- Cloud Functions 側のテストが11ファイルあり、判定の中心部は守られている。
- 画面を閉じたあとの処理（購読、タイマー）は、HomeController、Plus の画面、使い方の画面とも、dispose で止めている。

---

## 対応状況（2026-10-30、fix-review-2026-10-30 ブランチ）

直した。ただしデプロイは未実施。
- 高-3 プライバシーマニフェスト: ios/Runner/PrivacyInfo.xcprivacy と ios/CloudWidget/PrivacyInfo.xcprivacy を足し、Runner のプロジェクトに登録した。
- 高-4 全件読み取り: 通知の宛先（fcmToken）がある人だけを読み、member_server もその人の分だけ読む形にした（テストを足した）。サーバーのデプロイ後に効く。毎日の cleanupInactiveMembers の全件読みは、1日1回なので、このままにした。
- 中-2 Plus の TRANSFER: 移す元の Plus の状態を移す先にコピーして、元を外す（テストを足した）。デプロイ後に効く。実機での確認はこれから。
- 低 合言葉の比較: 一定時間で比べる形にした。
- 中-8 使っていないパッケージと画像: http、cloud_functions、uuid を外し、同梱していた画像（約6MB）を外した。README が使うので、assets/images のファイルは残した。
- 中-6 のうち、通知のボタンの答えを捨てていた箇所は、本番でもログに出るようにした。ほかの握りつぶしは、失敗しても困らないと確かめたので、そのまま。

2回目の対応（review-followup ブランチ）。
- 中-1 ルールの検証: members と reports に、書けるフィールドと大きさの検証を足した。Firestore エミュレータで確かめるテスト（functions/test_rules、`npm run test:rules`、Java 21 が要る）を作り、アプリが実際に書く内容が通ることを確かめた。**デプロイはまだ。**
- 中-3 データの削除: 設定に「データを削除」を足した。サーバーの `deleteMyData`（呼んだ本人の members と reports を消し、member_server は Plus の状態だけ残す）を作った。匿名ログインのアカウント（uid）は残す（消すと、購入を復元しても Plus を移せなくなるため）。プライバシーポリシーも書き換えた。**デプロイはまだ。**

直していない（理由つき）。
- 高-1 Storage のルール、高-2 Firestore の v1 の部分: 公開日に v1 の関数と写真を消したあとでないと、v1（1.0.4）が壊れる。公開日の手順に足した（docs/残りの作業と確認事項.md）。
- 中-1 の App Check、中-5 API キーの制限、中-7 Google Play の申告、中-9 依存の更新、中-10 アクセシビリティ: コンソールの操作、デプロイ、方針の決定が要る。docs/残りの作業と確認事項.md の 4-A に並べた。

---

## 重要度「高」

### 高-1. Storage のルールが全開放（storage.rules:3-6）

「一時的に全てのアクセスを許可（テスト用）」のまま、`allow read, write: if true`。インターネット上の誰でも、Storage の読み書き・削除ができる。

被害は、知らない人が大きなファイルを無制限に置いて料金が増えること、v1 の写真の読み出し・消去、不適切なファイルの置き場にされること。v2.0 のアプリは Storage を使っていない（pubspec に firebase_storage がない）ので、v1（1.0.4）の写真が要らなくなる時点で閉じられる。

直し方は、v1 の写真を消したあと（公開日の作業）に `allow read, write: if false;` にしてデプロイすること。公開日の手順（docs/残りの作業と確認事項.md の4）に「Storage のルールを閉じる」を足しておくとよい。いまのリストには Firestore のルールしか書かれていない。

### 高-2. Firestore の v1 のコレクションが誰でも読み書き可（firestore.rules:61-100）

`_test_connection`、`users`、`photos`、`likes`、`comments`、`downloads`、`debug` が `allow read, write: if true`。ログインも要らない。docs に「公開時に締め直す」と書いてあるのは確認した。

被害は、`users`（v1 の利用者の情報。中身は要確認）が誰にでも読まれ、書き換えられること。`photos` や `comments` に荒らしの投稿を入れられ、読み書きの回数が増えて料金も増える。

直し方は、公開日に v1 の関数を止めて写真と users のデータを消したあと、これらの match を消す（最後の `match /{document=**}` が全部拒否にする）こと。v1 の関数を止める前に締めると 1.0.4 が壊れるので、順番を守る。

### 高-3. iOS のプライバシーマニフェスト（PrivacyInfo.xcprivacy）がアプリ側にない

ios 以下に PrivacyInfo.xcprivacy が1つもない（git ls-files で確認）。アプリ自身の Swift が UserDefaults を使っている。AppDelegate.swift:134 は `UserDefaults.standard`、CloudWidget.swift:36 は App Group の `UserDefaults(suiteName:)`。UserDefaults は、Apple が「理由の申告が必要な API」にしているもの。

被害は、App Store Connect にアップロードしたときや審査で、「API の使用理由の宣言がない」という警告（ITMS-91053）や差し戻しになる恐れがあること。ライブラリ側（Firebase、shared_preferences など）の分は、それぞれが持っていることが多い。ただしアプリ自身のコードの分は別。

直し方は、ios/Runner/PrivacyInfo.xcprivacy と、ウィジェットのターゲット（ios/CloudWidget）にそれぞれ PrivacyInfo.xcprivacy を足し、NSPrivacyAccessedAPICategoryUserDefaults と理由（アプリ内は CA92.1、App Group で共有する分は 1C8F.1 の見込み）を書くこと。Xcode の Target に追加するのを忘れない。理由コードは Apple の一覧で確かめる（要確認）。ビルド 10 までの TestFlight のアップロードでは止められていないが、審査では確認される。

### 高-4. 雲があるたびに、全利用者の members と member_server を全件読んでいる（cloud_watch_service.js:85-86、cleanup_service.js:48）

`updateNowcastClouds` が新しい解析を取るたび（5分ごと）、見えている雲が1つでもあれば、`members` と `member_server` の全ドキュメントを `.get()` している。通知を送らない人（トークンなし、通知オフ、雲が遠い人）も読む。毎日 4:00 の `cleanupInactiveMembers` も members を全件読む。

被害は、料金が利用者数に比例して増えること。概算では、雲が一日じゅう出ていると1人あたり 2 × 288 = 576 回の読み取りで、1,000 人なら一日約 58 万回（無料枠は一日 5 万回）。料金は読み取り10万回あたり数セントなので、1,000 人で月に数ドル〜10 ドル台、1万人で月に百ドル前後になる（概算。要確認）。いまの利用者数なら問題にならないが、広まったときに急に効いてくる。夏の雷の日は、雲が出る時間が長いので特に増える。

直し方は、読み取りを減らすこと。たとえば、(1) members から `fcmToken` が入っている人だけを `where('fcmToken', '!=', null)` で読む、(2) 雲のある地域（位置を粗い格子や geohash にして保存）の人だけを読む、(3) member_server は、通知の対象になった人だけを `getAll` で読む。同時に、Google Cloud の予算アラートを作っておく（要確認）。

---

## 重要度「中」

### 中-1. 不正な書き込みを防ぐ仕組みが薄い（firestore.rules:21-37、pubspec.yaml）

- **App Check が入っていない。** firebase_app_check が pubspec にない。匿名ログインは、誰でも何度でも新しい uid を作れる。そのため、本物のアプリ以外からの書き込み（スクリプト）を止められない。
- **reports の create（firestore.rules:33-35）**は、`uid` と `seen` の型しか確かめていない。ほかのフィールドの型や大きさ、書き込みの回数の制限がない。
- **members（firestore.rules:21-23）**は、本人なら何でも書ける。`places` に巨大な配列を入れることもできる。サーバーは `places.slice(0, 上限)` で見る数を絞っている（cloud_watch_service.js:39）ので誤動作はしないが、ドキュメントが大きくなると毎回の読み取りが重くなる。Plus や通知の判断は member_server で行っているので、権限を上げられることはない。

直し方は、App Check（iOS は App Attest、Android は Play Integrity）を入れること。ルールで `request.resource.data.keys().hasOnly([...])` と、文字列・配列の大きさの上限を確かめること。reports は、cloudId が clouds に実在するかも確かめる（`exists`）。

### 中-2. Plus を復元したときに、サーバー側の Plus が付かない（revenuecat_webhook.js、member_service.dart:35-47）

匿名ログインなので、uid が変わる場面（Android の入れ直し、端末の買い替え）では、購入を復元すると、RevenueCat は権利を新しい uid に移し、TRANSFER イベントを送る。（2026-10-31 に実機で確かめたところ、iPhone はアプリを消して入れ直しても同じ uid が続いた。Firebase Auth がキーチェーンに保存するため。iPhone の入れ直しでは起きない。）webhook は TRANSFER を扱っていない（ファイル内に TRANSFER の記述がない）。そのため、新しい uid の member_server に isPlus が書かれない。アプリの画面は RevenueCat の権利を見て Plus と出すが、サーバーは無料として通知する（範囲30km、見張る場所1か所）。古い uid は期限まで Plus のまま残る。要確認（実機で、入れ直して復元し、member_server を見る）。

直し方は、webhook に TRANSFER を足し、`transferred_to` の uid に Plus を書き、`transferred_from` の uid から外すこと。

### 中-3. データの引き継ぎと削除（member_service.dart:35-47、docs/privacy_policy.html）

- **引き継ぎ**: 匿名ログインのため、uid が変わる場面（Android の入れ直し、端末の買い替え）では、見張る場所、設定、記録（reports）が失われる。iPhone は入れ直しても同じ uid が続く（2026-10-31 に実機で確認）。Plus は復元で戻るが、記録は戻らない。v1 の端末 ID（legacyUserId、member_service.dart:46）は、手がかりとして保存しているだけ。仕様として割り切るなら、設定や記録の画面に「入れ直すと記録は消えます」と一言あるとよい（要確認）。
- **削除**: アプリの中に、自分のデータを消す導線がない（lib を検索して該当なし）。プライバシーポリシーには、1年開かなければ消える、と書いてある。Apple のアカウント削除の規則は、アカウントを作るアプリが対象なので、匿名ログインだけなら該当しない見込み（要確認）。一方 Google Play は、データの削除の依頼方法を、アプリとストアの両方で示すよう求めている（要確認）。

直し方は、設定に「データを削除」を足し、`members`・`member_server`・自分の `reports` を消す Cloud Function と、`FirebaseAuth.currentUser.delete()` を呼ぶこと。

### 中-4. 集めている個人情報と、プライバシーの申告（member_service.dart:35-95）

保存しているのは、約1kmに丸めた位置、見張る場所（名前と座標）、FCM トークン、最後に開いた時刻、platform、「見えた」「見えなかった」の答え（方角と距離つき）、v1 の端末 ID（legacyUserId）、購入の状態（member_server）、匿名ログインの uid。

分析ツール（Firebase Analytics、Crashlytics）は入っていない。ログに位置や uid を出している箇所は見つからなかった。

要確認は、App Store のプライバシー申告と Google Play のデータセーフティに、次のものが漏れなく入っているか。位置（申告は「正確な位置」と決めてある）、ユーザー ID と端末の ID（uid、FCM トークン）、購入履歴、利用状況（最後に開いた時刻、見えた・見えなかった）。また、v1 の端末 ID を保存し続けるなら、1年の削除の対象に入っているかも確かめる（cleanup_service.js は members のドキュメントごと消すので入る見込み）。

### 中-5. Firebase の設定ファイルが git に入っている（.gitignore:52-53、android/app/google-services.json、ios/Runner/GoogleService-Info.plist）

.gitignore に「セキュリティのため除外」と書いてあるのに、この2ファイルは追跡されている（git ls-files で確認）。中の API キーは Firebase のクライアント用で、秘密ではないが、キーに制限がないと他のアプリから使われる恐れがある。config/revenuecat.json も追跡されている（公開用キーなので問題はないが、.gitignore には入っていない）。履歴には、使わなくなった Google マップの API キーも残っている（docs に記載済み）。

直し方は、Google Cloud コンソールで、各 API キーに「アプリの制限（iOS のバンドル ID、Android のパッケージ名と署名）」と「API の制限」をかけること（要確認）。履歴のマップのキーは無効にする。.gitignore と実態を合わせる（追跡をやめるか、コメントを直すか）。

### 中-6. 例外の握りつぶしと、本番で失敗に気づけないこと（logger.dart:19-60、各所）

`catch (_)` で何もしない箇所がある。cloud_notifications.dart:149, 164, 217、report_service.dart:80、sky_repository.dart:67, 83、current_place.dart:119、sky_widget.dart:107。とくに cloud_notifications.dart:217 は、アプリが閉じているときに通知のボタンで答えた「見えた」を、失敗しても何も残さず捨てる。

さらに、AppLogger の warning と info は本番では出ない設定（logger.dart の `if (!_isDebugMode) return`）で、Crashlytics のような仕組みもない。そのため、本番の端末で失敗しても、開発者には分からない。

直し方は、握りつぶす箇所にも、本番で出す `AppLogger.error` を足すこと。Crashlytics を入れると、どこで落ちているか分かる（その場合はプライバシーの申告に診断データを足す）。

### 中-7. Google Play: 常時の位置情報（AndroidManifest.xml:8）

`ACCESS_BACKGROUND_LOCATION` を宣言している。Google Play は、バックグラウンドの位置情報に、申告フォームと、アプリ内の目立つ説明（その前の同意）を求める。アプリには「常に」のお願いの画面（always_allow_sheet.dart）がある。Play Console の申告の文面と、この画面の文面が合っているか要確認（Android は後回しにしているので、提出の前に）。

### 中-8. 使っていないパッケージと、同梱している大きな画像（pubspec.yaml:14, 26, 37, 56-60）

- `http`、`cloud_functions`、`uuid` は、lib から1つも import されていない。
- `assets/images/`（約6MB。community_screen.png 2.1MB、main_screen.png 1.4MB など、v1 のスクリーンショット）を丸ごとアプリに同梱している。`image/` の4ファイルも、lib からの参照が見つからない（要確認。コードに文字列で書かれている場合は grep で見つかるはずだが、念のため実機で確認）。

被害は、アプリの容量が増えること、ダウンロードと起動が重くなること。

直し方は、使っていないパッケージを pubspec から外し、使っていない画像を削除して assets の指定も外すこと。

### 中-9. 依存パッケージが古い（pubspec.yaml）

firebase_core 3.15（最新 5.1）、firebase_auth 5.7（7.0）、cloud_firestore 5.6（7.1）、firebase_messaging 15.2（17.0）、geolocator 13（14）、purchases_flutter 10.17（11.0）。flutter_lints 4（6）。メジャーが1〜2つ遅れている。UIScene の対応が新しい版で進んでいる（docs にも記載）。既知の脆弱性があるかは確認していない（要確認: `flutter pub outdated` の結果ではなく、OSV などの脆弱性データベースで確かめる）。functions も、firebase-admin 12.7 など（`npm audit` は未実行。要確認）。

急いで上げる必要はない。公開後に、通知の動作を実機で確かめながら、1つずつ上げる。

### 中-10. アクセシビリティ（lib 全体）

- ダークモードの対応が見当たらない（darkTheme、ThemeMode の設定なし）。アプリは空のグラデーションの背景を使っていて、夜用の色は別にあるので、システムのダークモードには従っていない。方針として決めているなら問題はない（要確認）。
- 文字サイズの変更（textScaler）への対応を明示した箇所がない。大きい文字にしたとき、ホームの文字、チップ、ボタンが見切れないか、実機で確かめる（要確認）。
- 読み上げ（Semantics）は、使い方、Plus、ホームの部品などに入っている一方、ホームのレーダーなどの絵は、読み上げの対象外にしている箇所がある。内容を文で読み上げる補助があるか要確認。
- 白い文字を、背景の下側（明るい水色）に置く画面がないか、色のコントラストを確かめる（要確認）。

---

## 重要度「低」

- **Android の難読化なし（build.gradle:61）**: `minifyEnabled false`、`shrinkResources false`。リリースの容量が大きく、コードも読まれやすい。ただし入れると、動かなくなる箇所が出ることがあるので、Android を出すときに試す。
- **Android のバックアップ（AndroidManifest.xml:16）**: `android:allowBackup` を指定していない（既定は true）。端末のバックアップにアプリの設定が入る。members のデータは Firestore にあるので実害は小さいが、方針として決めて明示しておく。
- **webhook の合言葉の比較（revenuecat_webhook.js:78）**: `!==` で比べている。タイミングを使った推測が理論上は可能。`crypto.timingSafeEqual` にするとよい。
- **ローカルに残るデータ**: 通知のボタンで答えたものを SharedPreferences に一時保存している（cloud_notifications.dart、report_service.dart）。暗号化はない。位置は丸めた方角と距離なので、実害は小さい。
- **答えの重複（report_service.dart:153）**: `reports` を `add`（自動 ID）で送る。通信が途中で切れて再送されると、同じ答えが2つできうる。記録の画面は雲ごとに重複を除いているので、見た目は問題ない（report_service.dart:55-67）。
- **電池と通信量**: 「常に」を許可した Android は15分ごとに位置を更新する（current_place.dart）。ホームの1分ごとの再計算と、レーダーの回るアニメーションは、画面が開いている間だけか、要確認。
- **コードの長さ**: home_controller.dart 643行、home_parts.dart 581行、intro_screen.dart 470行、home_screen.dart 461行、plus_screen.dart 441行。画面の部品（_PlanButton、_FeatureCard など）は別ファイルに分けると読みやすい。
- **テストが少ない（test/）**: Dart のテストは5ファイル（使い方、読み込み、沖の名前、いまの空、空の計算）。MemberService、PlusService、通知の処理、HomeController には、テストがない。購入と通知は壊れたときの影響が大きいので、PlusService の判定（isPlusActive など）から足すとよい。
- **使っていないコード**: AppLogger に success、progress、ServiceLogger などの未使用のメソッドが多い（要確認）。functions の v1 用の関数（cleanupExpiredPhotos）は、公開後に消す（docs に記載）。
- **画面 PNG が古い**: docs/screens の PNG の一部が古い（docs/残りの作業と確認事項.md に記載済み）。
- **iPad を対象にしたこと**: 2026-10-30 に iPad を対象に残した。App Store には iPad のスクリーンショット（13インチ）が必要。iPad では画面が横幅いっぱいに広がる。提出の前に、iPad のシミュレータで主な画面を確かめる（使い方の1枚目だけ確認した）。
- **通信**: アプリから使う通信は HTTPS だけで、気象庁へはサーバー経由（CLAUDE.md の決まりどおり）。ローカルの保存先は SharedPreferences（共有設定）と Firestore のオフラインキャッシュ。

---

## 今日直すべき上位5つ

1. **iOS のプライバシーマニフェストを足す**（高-3）。Runner と CloudWidget に PrivacyInfo.xcprivacy を作り、UserDefaults の使用理由を書く。審査に直結し、小さく安全に直せる。
2. **公開日の手順に、Storage と v1 の Firestore を閉じる作業を足す**（高-1、高-2）。順番は、v1 の関数を止める、写真と users を消す、ルールを閉じる。ルールのファイルは、公開日にすぐデプロイできる形で用意しておく（デプロイは確認をもらってから）。
3. **全件読み取りを減らす**（高-4）。まず `fcmToken` のある人だけを読む絞り込みと、Google Cloud の予算アラートの作成。
4. **webhook の TRANSFER を扱う**（中-2）。入れ直して復元した人の Plus が、サーバー側で付かない問題。直す前に、実機で再現を確かめる。
5. **使っていないパッケージと、古い画像を外す**（中-8）。http、uuid、cloud_functions と `assets/images/`（約6MB）。アプリの容量が減り、リスクも小さい。

次に取り組むなら、App Check とルールの検証（中-1）、アプリ内のデータ削除（中-3）、本番のエラーの記録（中-6）。
