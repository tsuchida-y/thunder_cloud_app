// functions/constants.js - Firebase Functions用定数管理

/**
 * 気象データ関連の定数
 */
const WEATHER_CONSTANTS = {
  // 監視方向と距離
  CHECK_DIRECTIONS: ['north', 'south', 'east', 'west'],
  CHECK_DISTANCES: [50.0, 160.0, 250.0],

  // 座標計算
  LATITUDE_PER_DEGREE_KM: 111.0,
  COORDINATE_PRECISION: 2, // 小数点以下桁数
  API_COORDINATE_PRECISION: 6, // API用の高精度座標

  // キャッシュ設定
  CACHE_DURATION_MS: 5 * 60 * 1000, // 5分
  CACHE_CLEANUP_RETENTION_HOURS: 2, // 2時間
  CACHE_CLEANUP_BATCH_SIZE: 100,

  // 夜間モード設定（20時〜8時）
  NIGHT_MODE_START_HOUR: 20,
  NIGHT_MODE_END_HOUR: 8,
  JST_OFFSET_MS: 9 * 60 * 60 * 1000, // 9時間をミリ秒で

  // デフォルト値
  DEFAULT_TEMPERATURE: 20,
  DEFAULT_WEATHER_VALUE: 0.0,
};

/**
 * 入道雲分析の閾値定数
 */
const ANALYSIS_THRESHOLDS = {
  // CAPE（対流有効位置エネルギー）閾値
  CAPE_VERY_HIGH: 2500,
  CAPE_HIGH: 1000,
  CAPE_MEDIUM: 500,
  CAPE_LOW: 100,

  // リフティドインデックス閾値
  LI_VERY_UNSTABLE: -6,
  LI_UNSTABLE: -3,
  LI_NEUTRAL: 0,
  LI_STABLE: 3,
  LI_VERY_STABLE: 6,

  // CIN（対流抑制）閾値
  CIN_LOW: 10,
  CIN_MEDIUM: 50,

  // 気温閾値
  TEMP_VERY_HIGH: 30,
  TEMP_HIGH: 25,
  TEMP_MEDIUM: 20,
  TEMP_LOW: 15,

  // 雲量閾値
  CLOUD_VERY_HIGH: 80,
  CLOUD_HIGH: 60,
  CLOUD_MEDIUM: 40,
  CLOUD_LOW: 20,

  // 総合判定閾値
  TOTAL_SCORE_HIGH: 0.5,
  TOTAL_SCORE_MEDIUM: 0.3,
  TOTAL_SCORE_LOW: 0.15,
};

/**
 * スコア重み定数
 */
const SCORE_WEIGHTS = {
  CAPE: 0.4,
  LIFTED_INDEX: 0.3,
  CIN: 0.05,
  TEMPERATURE: 0.1,
  CLOUD_COVER: 0.15,
};

/**
 * スコア値定数
 */
const SCORE_VALUES = {
  PERFECT: 1.0,
  HIGH: 0.8,
  MEDIUM_HIGH: 0.6,
  MEDIUM: 0.4,
  MEDIUM_LOW: 0.3,
  LOW: 0.2,
  VERY_LOW: 0.1,
  NONE: 0.0,
};

/**
 * タイムアウト設定
 */
const TIMEOUT_SETTINGS = {
  FUNCTION_TIMEOUT_SECONDS: 540, // 9分
  CACHE_FUNCTION_TIMEOUT_SECONDS: 300, // 5分
  CLEANUP_FUNCTION_TIMEOUT_SECONDS: 300, // 5分
  API_TIMEOUT_MS: 60000, // 60秒
};

/**
 * バッチ処理設定
 */
const BATCH_SETTINGS = {
  BATCH_SIZE: 100, // 一度に処理する座標数
  BATCH_DELAY_MS: 2000, // バッチ間の待機時間
  FALLBACK_DELAY_MS: 100, // フォールバック時の待機時間
};

/**
 * ユーザー監視設定
 */
const USER_MONITORING = {
  ACTIVE_USER_DURATION_MS: 24 * 60 * 60 * 1000, // 24時間
  CACHE_CHECK_DURATION_MS: 5 * 60 * 1000, // 5分
};

/**
 * HTTP ステータスコード
 */
const HTTP_STATUS = {
  OK: 200,
  BAD_REQUEST: 400,
  INTERNAL_SERVER_ERROR: 500,
};

/**
 * メモリ設定
 */
const MEMORY_SETTINGS = {
  DEFAULT: '256MiB',
  HIGH: '512MiB',
};

/**
 * リージョン設定
 */
const REGIONS = {
  ASIA_NORTHEAST: 'asia-northeast1',
  US_CENTRAL: 'us-central1',
};

/**
 * ログ用定数
 */
const LOG_CONSTANTS = {
  TOKEN_DISPLAY_LENGTH: 10, // FCMトークンの表示文字数
  COORDINATE_DISPLAY_PRECISION: 4, // ログ用座標表示精度
};

/**
 * API 設定
 */
const API_SETTINGS = {
  USER_AGENT: 'ThunderCloudApp/1.0',
  RETRY_STATUS_MIN: 200,
  RETRY_STATUS_MAX: 300,
};

/**
 * ヘルパー関数
 */
const HelperFunctions = {
  /**
   * 座標を指定精度で丸める
   */
  roundCoordinate: (coordinate, precision = WEATHER_CONSTANTS.COORDINATE_PRECISION) => {
    const factor = Math.pow(10, precision);
    return Math.round(coordinate * factor) / factor;
  },

  /**
   * 座標文字列をフォーマット
   */
  formatCoordinate: (coordinate, precision = WEATHER_CONSTANTS.COORDINATE_PRECISION) => {
    return coordinate.toFixed(precision);
  },

  /**
   * キャッシュキーを生成
   */
  generateCacheKey: (latitude, longitude) => {
    const roundedLat = HelperFunctions.roundCoordinate(latitude);
    const roundedLng = HelperFunctions.roundCoordinate(longitude);
    return `weather_${HelperFunctions.formatCoordinate(roundedLat)}_${HelperFunctions.formatCoordinate(roundedLng)}`;
  },

  /**
   * 高精度キャッシュキーを生成（API用）
   */
  generateHighPrecisionKey: (latitude, longitude) => {
    const latFormatted = HelperFunctions.formatCoordinate(latitude, WEATHER_CONSTANTS.API_COORDINATE_PRECISION);
    const lonFormatted = HelperFunctions.formatCoordinate(longitude, WEATHER_CONSTANTS.API_COORDINATE_PRECISION);
    return `${latFormatted}_${lonFormatted}`;
  },

  /**
   * 現在時刻が夜間モードかどうかを判定
   */
  isNightMode: () => {
    const now = new Date();
    const jstTime = new Date(now.getTime() + WEATHER_CONSTANTS.JST_OFFSET_MS);
    const currentHour = jstTime.getHours();

    return currentHour >= WEATHER_CONSTANTS.NIGHT_MODE_START_HOUR ||
           currentHour < WEATHER_CONSTANTS.NIGHT_MODE_END_HOUR;
  },

  /**
   * 夜間モード用のレスポンスを作成
   */
  createNightModeResponse: () => {
    const nightResponse = {
      analysis: { isLikely: false, totalScore: 0, riskLevel: '極めて低い' },
      temperature: WEATHER_CONSTANTS.DEFAULT_TEMPERATURE
    };
    return {
      north: nightResponse,
      south: nightResponse,
      east: nightResponse,
      west: nightResponse
    };
  },

  /**
   * FCMトークンを短縮表示用にフォーマット
   */
  formatTokenForLog: (token) => {
    if (!token) return 'N/A';
    return `${token.substring(0, LOG_CONSTANTS.TOKEN_DISPLAY_LENGTH)}...`;
  }
};

module.exports = {
  WEATHER_CONSTANTS,
  ANALYSIS_THRESHOLDS,
  SCORE_WEIGHTS,
  SCORE_VALUES,
  TIMEOUT_SETTINGS,
  BATCH_SETTINGS,
  USER_MONITORING,
  HTTP_STATUS,
  MEMORY_SETTINGS,
  REGIONS,
  LOG_CONSTANTS,
  API_SETTINGS,
  HelperFunctions
};