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
 * v2.0 の通知のルール（docs/入道雲サーチ_決定事項.md の「3. 通知のルール」）
 */
const NOTIFY_RULES = {
  FREE_RANGE_KM: 30,
  PLUS_RANGE_KM: 90,
  // これより遠い雲は「見えるかもしれません」と控えめに書く
  MAYBE_VISIBLE_KM: 60,
  MIN_INTERVAL_MS: 30 * 60 * 1000,
  DAILY_LIMIT: 3,
  // アプリを開いてからこの時間内の人には送らない（もう画面で見ているため）
  RECENTLY_OPENED_MS: 10 * 60 * 1000,
  JST_OFFSET_MS: 9 * 60 * 60 * 1000,
  // Plus で見張れる登録済みの場所の数（いまいる場所は別）
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

module.exports = {
  JMA_NOWCAST,
  NOTIFY_RULES,
  COLLECTIONS,
  CLOUD_RETENTION_DAYS,
};
