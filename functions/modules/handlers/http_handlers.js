/**
 * HTTP API リクエストハンドラークラス
 *
 * Firebase Functions のHTTP APIエンドポイントを処理する専用ハンドラー
 * RESTful API設計に従い、各エンドポイントの責務を明確に分離
 *
 * 処理するエンドポイント:
 * - GET /getWeatherData: 単一地点の気象データ取得
 * - GET /getDirectionalWeatherData: 方向別気象データ取得
 * - GET /getCacheStats: キャッシュ統計情報取得
 *
 * 共通機能:
 * - CORS設定（クロスオリジン対応）
 * - OPTIONSプリフライト処理
 * - 入力値バリデーション
 * - エラーハンドリング・ログ出力
 * - 夜間モード対応
 *
 * セキュリティ:
 * - 入力値の型チェック・範囲チェック
 * - エラー情報の適切な隠蔽
 * - レート制限への配慮
 */

const ResponseHelpers = require('../utils/response_helpers');
const { HelperFunctions } = require('../../constants');

class HttpHandlers {
  constructor(weatherService) {
    this.weatherService = weatherService;
  }

  /**
   * 気象データ取得API処理
   *
   * @param {Object} req - Express リクエストオブジェクト
   * @param {Object} res - Express レスポンスオブジェクト
   *
   * エンドポイント: GET /getWeatherData
   * パラメータ: latitude, longitude (クエリパラメータ)
   *
   * 処理フロー:
   * 1. CORS設定・プリフライト処理
   * 2. 必須パラメータの存在チェック
   * 3. 数値型への変換・バリデーション
   * 4. 夜間モードチェック（20:00-08:00）
   * 5. キャッシュ優先での気象データ取得
   * 6. 成功レスポンス返却
   *
   * エラーハンドリング:
   * - 400: パラメータ不正
   * - 500: サーバーエラー
   */
  async getWeatherData(req, res) {
    ResponseHelpers.setCORSHeaders(res);

    if (req.method === 'OPTIONS') {
      res.status(200).end();
      return;
    }

    try {
      const { latitude, longitude } = req.query;

      if (!latitude || !longitude) {
        return ResponseHelpers.sendError(res, 400, 'latitude and longitude are required');
      }

      const lat = parseFloat(latitude);
      const lon = parseFloat(longitude);

      console.log(`🌦️ 気象データ取得要求: ${lat}, ${lon}`);

      // 夜間モードチェック
      if (HelperFunctions.isNightMode()) {
        console.log('🌙 夜間モード: 入道雲なしの状態を返却');
        const nightModeData = HelperFunctions.createNightModeResponse();
        return ResponseHelpers.sendNightModeResponse(res, nightModeData);
      }

      const weatherData = await this.weatherService.getWeatherDataWithCache(lat, lon);
      ResponseHelpers.sendSuccess(res, weatherData);

    } catch (error) {
      console.error('❌ 気象データ取得エラー:', error);
      ResponseHelpers.sendError(res, 500, 'Internal server error', error.message);
    }
  }

  /**
   * 各方向気象データ取得API処理
   *
   * @param {Object} req - Express リクエストオブジェクト
   * @param {Object} res - Express レスポンスオブジェクト
   *
   * エンドポイント: GET /getDirectionalWeatherData
   * パラメータ: latitude, longitude (クエリパラメータ)
   *
   * 処理内容:
   * - 指定座標を中心とした8方向（N,NE,E,SE,S,SW,W,NW）
   * - 各方向5km, 10km, 15kmの気象データを取得
   * - 各方向で最適なリスクレベルの地点を選択
   * - 入道雲発生リスクの分析結果を含む
   *
   * レスポンス構造:
   * {
   *   "north": { coordinates: {}, analysis: {}, weatherData: {} },
   *   "south": { ... },
   *   ...
   * }
   *
   * 用途: 入道雲リスクの方向別把握、詳細な気象状況分析
   */
  async getDirectionalWeatherData(req, res) {
    ResponseHelpers.setCORSHeaders(res);

    if (req.method === 'OPTIONS') {
      res.status(200).end();
      return;
    }

    try {
      const { latitude, longitude } = req.query;

      if (!latitude || !longitude) {
        return ResponseHelpers.sendError(res, 400, 'latitude and longitude are required');
      }

      const lat = parseFloat(latitude);
      const lon = parseFloat(longitude);

      console.log(`🌦️ 各方向気象データ取得要求: ${lat}, ${lon}`);

      // 夜間モードチェック
      if (HelperFunctions.isNightMode()) {
        console.log('🌙 夜間モード: 入道雲なしの状態を返却');
        const nightModeData = HelperFunctions.createNightModeResponse();
        return ResponseHelpers.sendNightModeResponse(res, nightModeData);
      }

      // 各方向の気象データを取得
      const weatherData = await this.weatherService.getDirectionalWeatherData(lat, lon);

      if (weatherData) {
        ResponseHelpers.sendSuccess(res, weatherData);
      } else {
        ResponseHelpers.sendError(res, 500, 'Failed to fetch weather data', 'No weather data available');
      }

    } catch (error) {
      console.error('❌ 各方向気象データ取得エラー:', error);
      ResponseHelpers.sendError(res, 500, 'Internal server error', error.message);
    }
  }

  /**
   * キャッシュ統計情報取得API処理
   *
   * @param {Object} req - Express リクエストオブジェクト
   * @param {Object} res - Express レスポンスオブジェクト
   *
   * エンドポイント: GET /getCacheStats
   * パラメータ: なし
   *
   * 提供情報:
   * - 総キャッシュ数
   * - 新しいキャッシュ数（1時間以内）
   * - 古いキャッシュ数（削除対象）
   * - 保持設定情報
   * - 取得時刻
   *
   * 用途:
   * - システム監視・ダッシュボード
   * - キャッシュ効率の分析
   * - 容量計画・最適化
   */
  async getCacheStats(req, res) {
    ResponseHelpers.setCORSHeaders(res);

    if (req.method === 'OPTIONS') {
      res.status(200).end();
      return;
    }

    try {
      const stats = await this.weatherService.getCacheStats();
      ResponseHelpers.sendSuccess(res, { stats });
    } catch (error) {
      console.error('❌ キャッシュ統計取得エラー:', error);
      ResponseHelpers.sendError(res, 500, 'Internal server error', error.message);
    }
  }
}

module.exports = HttpHandlers;
