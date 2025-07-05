// functions/thunder_cloud_analyzer.js - 入道雲分析ロジック（定数ファイル対応）

// 定数ファイルをインポート
const {
  ANALYSIS_THRESHOLDS,
  SCORE_WEIGHTS,
  SCORE_VALUES,
  WEATHER_CONSTANTS
} = require('./constants');

class ThunderCloudAnalyzer {
  static analyzeWithMeteoDataOnly(meteoData) {
    const scores = {};

    // CAPE（対流有効位置エネルギー）の評価
    const cape = meteoData.cape || WEATHER_CONSTANTS.DEFAULT_WEATHER_VALUE;
    if (cape >= ANALYSIS_THRESHOLDS.CAPE_VERY_HIGH) {
      scores.cape = SCORE_VALUES.PERFECT;
    } else if (cape >= ANALYSIS_THRESHOLDS.CAPE_HIGH) {
      scores.cape = SCORE_VALUES.HIGH;
    } else if (cape >= ANALYSIS_THRESHOLDS.CAPE_MEDIUM) {
      scores.cape = SCORE_VALUES.MEDIUM_HIGH;
    } else if (cape >= ANALYSIS_THRESHOLDS.CAPE_LOW) {
      scores.cape = SCORE_VALUES.MEDIUM_LOW;
    } else {
      scores.cape = SCORE_VALUES.NONE;
    }

    // リフティドインデックス（Lifted Index）の評価
    const liftedIndex = meteoData.lifted_index || WEATHER_CONSTANTS.DEFAULT_WEATHER_VALUE;
    if (liftedIndex <= ANALYSIS_THRESHOLDS.LI_VERY_UNSTABLE) {
      scores.lifted_index = SCORE_VALUES.PERFECT;
    } else if (liftedIndex <= ANALYSIS_THRESHOLDS.LI_UNSTABLE) {
      scores.lifted_index = SCORE_VALUES.HIGH;
    } else if (liftedIndex <= ANALYSIS_THRESHOLDS.LI_NEUTRAL) {
      scores.lifted_index = SCORE_VALUES.MEDIUM_HIGH;
    } else if (liftedIndex <= ANALYSIS_THRESHOLDS.LI_STABLE) {
      scores.lifted_index = SCORE_VALUES.MEDIUM;
    } else if (liftedIndex <= ANALYSIS_THRESHOLDS.LI_VERY_STABLE) {
      scores.lifted_index = SCORE_VALUES.LOW;
    } else {
      scores.lifted_index = SCORE_VALUES.NONE;
    }

    // CIN（対流抑制）の評価
    const cin = meteoData.convective_inhibition || WEATHER_CONSTANTS.DEFAULT_WEATHER_VALUE;
    if (cin <= ANALYSIS_THRESHOLDS.CIN_LOW) {
      scores.cin = SCORE_VALUES.MEDIUM_LOW;
    } else if (cin <= ANALYSIS_THRESHOLDS.CIN_MEDIUM) {
      scores.cin = SCORE_VALUES.VERY_LOW;
    } else {
      scores.cin = SCORE_VALUES.NONE;
    }

    // 気温の評価
    const temperature = meteoData.temperature || WEATHER_CONSTANTS.DEFAULT_TEMPERATURE;
    if (temperature >= ANALYSIS_THRESHOLDS.TEMP_VERY_HIGH) {
      scores.temperature = SCORE_VALUES.PERFECT;
    } else if (temperature >= ANALYSIS_THRESHOLDS.TEMP_HIGH) {
      scores.temperature = SCORE_VALUES.HIGH;
    } else if (temperature >= ANALYSIS_THRESHOLDS.TEMP_MEDIUM) {
      scores.temperature = SCORE_VALUES.MEDIUM_HIGH;
    } else if (temperature >= ANALYSIS_THRESHOLDS.TEMP_LOW) {
      scores.temperature = SCORE_VALUES.MEDIUM;
    } else {
      scores.temperature = SCORE_VALUES.NONE;
    }

    // 雲量の評価
    const cloudCover = meteoData.cloud_cover || WEATHER_CONSTANTS.DEFAULT_WEATHER_VALUE;
    const cloudCoverMid = meteoData.cloud_cover_mid || WEATHER_CONSTANTS.DEFAULT_WEATHER_VALUE;
    const cloudCoverHigh = meteoData.cloud_cover_high || WEATHER_CONSTANTS.DEFAULT_WEATHER_VALUE;

    // 全体的な雲量を計算
    const totalCloudCover = Math.max(cloudCover, cloudCoverMid, cloudCoverHigh);

    if (totalCloudCover >= ANALYSIS_THRESHOLDS.CLOUD_VERY_HIGH) {
      scores.cloud_cover = SCORE_VALUES.PERFECT;
    } else if (totalCloudCover >= ANALYSIS_THRESHOLDS.CLOUD_HIGH) {
      scores.cloud_cover = SCORE_VALUES.HIGH;
    } else if (totalCloudCover >= ANALYSIS_THRESHOLDS.CLOUD_MEDIUM) {
      scores.cloud_cover = SCORE_VALUES.MEDIUM_HIGH;
    } else if (totalCloudCover >= ANALYSIS_THRESHOLDS.CLOUD_LOW) {
      scores.cloud_cover = SCORE_VALUES.MEDIUM_LOW;
    } else {
      scores.cloud_cover = SCORE_VALUES.NONE;
    }

    // 総合スコアを計算（重み付け平均）
    const totalScore =
      scores.cape * SCORE_WEIGHTS.CAPE +
      scores.lifted_index * SCORE_WEIGHTS.LIFTED_INDEX +
      scores.cin * SCORE_WEIGHTS.CIN +
      scores.temperature * SCORE_WEIGHTS.TEMPERATURE +
      scores.cloud_cover * SCORE_WEIGHTS.CLOUD_COVER;

    // 入道雲の可能性を判定
    const isThunderCloudLikely = totalScore >= ANALYSIS_THRESHOLDS.TOTAL_SCORE_HIGH;
    const riskLevel = totalScore >= ANALYSIS_THRESHOLDS.TOTAL_SCORE_HIGH ? '高い' :
      totalScore >= ANALYSIS_THRESHOLDS.TOTAL_SCORE_MEDIUM ? '中程度' :
        totalScore >= ANALYSIS_THRESHOLDS.TOTAL_SCORE_LOW ? '低い' : '極めて低い';

    return {
      isThunderCloudLikely,
      totalScore,
      riskLevel,
      individualScores: scores,
      capeScore: scores.cape,
      liScore: scores.lifted_index,
      cinScore: scores.cin,
      tempScore: scores.temperature,
      cloudScore: scores.cloud_cover,
    };
  }
}

module.exports = ThunderCloudAnalyzer;