// functions/constants.js - Firebase Functions用定数管理（入道雲サーチ v2.0）

/**
 * 気象庁ナウキャスト（高解像度降水ナウキャスト・雷ナウキャスト）の設定
 */
const JMA_NOWCAST = {
  BASE_URL: 'https://www.jma.go.jp/bosai/jmatile/data/nowc',
  TARGET_TIMES_RAIN: 'targetTimes_N1.json', // 降水の解析値（5分ごと）
  TARGET_TIMES_THUNDER: 'targetTimes_N3.json', // 雷の解析値と予測（10分ごと）
  ELEMENT_RAIN: 'hrpns',
  ELEMENT_THUNDER: 'thns',
  TILE_SIZE: 256,

  // 気象庁のタイルは偶数ズームだけ。z4 で日本全体を見て、雲がありそうな所だけ z6（約2km四方）で調べる
  COARSE_ZOOM: 4,
  DETAIL_ZOOM: 6,
  // 日本付近を覆う z4 のタイル範囲
  COARSE_TILE_X: [13, 14],
  COARSE_TILE_Y: [5, 7],

  // 雲とみなす目安（試作で「見えた」「見えなかった」を見ながら調整する）
  MIN_RAIN_MM_PER_HOUR: 30,
  MIN_THUNDER_LEVEL: 2,
  // z4 の見落としを防ぐため、当たりを付けるときは1段階弱い雨から拾う
  COARSE_MIN_RAIN_MM_PER_HOUR: 20,
  // 見張る場所でこれ以上の雨が降っていたら、雲の下か曇り空なので知らせない
  RAIN_HERE_MM_PER_HOUR: 1,
  // 雲の端（いちばん近い所）を出すために残す点の数の上限（Firestore の1件を大きくしすぎないため）
  MAX_EDGE_POINTS: 300,

  // 前回の雲から15km以内なら同じ雲として追いかける
  TRACKING_DISTANCE_KM: 15,
  // 見えなくなってから60分たった雲は終わりとする（そのあと同じ場所に出た雲は別の雲）
  CLOUD_EXPIRE_MS: 60 * 60 * 1000,

  // 続けて失敗したらエラーとしてログに出す回数（5分ごとなので15分）
  FAILURE_ALERT_COUNT: 3,
  // 気象庁の解析時刻がこれより古ければ、データが止まっているとみなす
  STALE_DATA_MS: 30 * 60 * 1000,
  REQUEST_TIMEOUT_MS: 15000,
  PARALLEL_REQUESTS: 6,
  USER_AGENT: 'NyudogumoSearch/2.0 (thunder-cloud-app)',

  CLOUDS_COLLECTION: 'clouds',
  STATUS_DOC_PATH: 'system/jma_nowcast',
};

/**
 * 気象庁ホームページのひまわりの赤外画像（バンド13）の設定
 *
 * 強い雨か雷の塊のうち、雲のてっぺんが冷たい（背が高い）ものだけを入道雲とし、てっぺんの高さも見積もる。
 * 雲の場所はナウキャストで決め、ひまわりは「背の高い雲か」と「高さ」にだけ使う。
 * 選んだ理由と、ほかのデータと比べた結果は docs/検知の精度を上げるデータの比較.md
 */
const HIMAWARI = {
  BASE_URL: 'https://www.jma.go.jp/bosai/himawari/data/satimg',
  TARGET_TIMES: 'targetTimes_jp.json',
  AREA: 'jp',
  BAND: 'B13',
  PRODUCT: 'TBB',
  // ナウキャストの z6 と同じタイルの並び（1ピクセル約2km）
  ZOOM: 6,
  // 白黒の明るさ（0〜255、冷たいほど白い）を温度（℃）に直す式: 温度 = OFFSET - 明るさ / SCALE
  // 気象庁は対応表を出していないので、晴れたアメダス地点の気温（明るさ約38で約+25℃）と、
  // 雲頂強調画像の赤（約-73℃）の明るさ（約225）の2点から見積もった（2026-10-22）。誤差は数℃ある
  GRAY_TO_TEMP_OFFSET: 45,
  GRAY_TO_TEMP_SCALE: 1.9,
  // てっぺんがこれより冷たい塊を入道雲とする（夏なら高さ約7〜8km。見えた/見えなかったで調整する）
  MAX_TOP_TEMP_C: -20,
  // 衛星から斜めに見るずれ（背の高い雲は北へ10km ほどずれて写る）と、時刻のずれの分、塊のまわりを広く見る
  SEARCH_MARGIN_PIXELS: 6,
  // 雲の中の気温は1km 上がるごとにこれだけ下がるとして、地上の気温との差から高さを出す
  LAPSE_RATE_C_PER_KM: 6.5,
  MIN_TOP_KM: 6,
  MAX_TOP_KM: 16,
  // 地上の気温が分からないときに使う値
  DEFAULT_SURFACE_TEMP_C: 25,
};

/**
 * 気象庁ホームページのアメダスの設定
 *
 * 見張る場所の空が一面の曇りか（日照時間）と、遠くまで見通せるか（視程）を調べる。
 * 雲のてっぺんの高さを出すための地上の気温にも使う。
 */
const AMEDAS = {
  BASE_URL: 'https://www.jma.go.jp/bosai/amedas',
  LATEST_TIME: 'data/latest_time.txt',
  STATION_TABLE: 'const/amedastable.json',
  // 地点の一覧はめったに変わらないので、この時間は覚えておく
  STATION_TABLE_TTL_MS: 24 * 60 * 60 * 1000,
  // 見張る場所からこの距離までの地点の日照を見る
  SUNSHINE_RADIUS_KM: 20,
  // 太陽がこれより低いと、晴れていても日照計が日照なしになるので、日照は使わない
  SUNSHINE_MIN_SUN_ALTITUDE_DEG: 15,
  // 視程は気象台など約150地点だけなので、この距離までのいちばん近い地点を使う
  VISIBILITY_RADIUS_KM: 40,
  // 視程計はこれ以上を同じ値（20km）で出すので、これ未満のときだけ使う
  VISIBILITY_MAX_M: 20000,
  // 雲のてっぺんの高さを出すときの地上の気温は、この距離までのいちばん近い地点を使う
  TEMP_RADIUS_KM: 50,
  // アプリのホームの「いまの空」用に、最新の観測をまとめて置く場所（アプリは気象庁に直接行かず、ここを読む）
  LATEST_DOC_PATH: 'system/amedas_latest',
};

/**
 * v2.0 の通知のルール（docs/入道雲サーチ_決定事項.md の「3. 通知のルール」）
 */
const NOTIFY_RULES = {
  FREE_RANGE_KM: 30,
  PLUS_RANGE_KM: 90,
  // これより遠い雲は「見えるかもしれません」と控えめに書く
  MAYBE_VISIBLE_KM: 60,
  // 雲の端がこれより近いと、真下か近すぎて形が見えないので知らせない（離れてから知らせる）
  MIN_DISTANCE_KM: 10,
  MIN_INTERVAL_MS: 30 * 60 * 1000,
  DAILY_LIMIT: 3,
  // アプリを開いてからこの時間内の人には送らない（もう画面で見ているため）
  RECENTLY_OPENED_MS: 10 * 60 * 1000,
  JST_OFFSET_MS: 9 * 60 * 60 * 1000,
  // 見張れる登録済みの場所の数（いまいる場所は別）。無料でも1か所（2026-10-27）
  FREE_MAX_PLACES: 1,
  PLUS_MAX_PLACES: 3,
};

/**
 * v2.0 の Firestore の置き場所
 *
 * members/{uid}        アプリが書く: 位置、見張る場所、設定、最後に開いた時刻、FCM トークン
 * member_server/{uid}  サーバーだけが書く: Plus かどうか、通知の記録
 * reports/{自動ID}     アプリが書く: 「見えた」「見えなかった」の答え
 * uid は Firebase Authentication の匿名ログインの ID
 */
const COLLECTIONS = {
  MEMBERS: 'members',
  MEMBER_SERVER: 'member_server',
  REPORTS: 'reports',
};

/**
 * 終わった雲を残しておく日数（夜の画面の「きょう見えた入道雲」に使うので、少なくとも当日分は残す）
 */
const CLOUD_RETENTION_DAYS = 3;

// 最後にアプリを開いてからこの日数がたった利用者の情報を消す（プライバシーポリシー）
const INACTIVE_MEMBER_DAYS = 365;

module.exports = {
  JMA_NOWCAST,
  HIMAWARI,
  AMEDAS,
  NOTIFY_RULES,
  COLLECTIONS,
  CLOUD_RETENTION_DAYS,
  INACTIVE_MEMBER_DAYS,
};
