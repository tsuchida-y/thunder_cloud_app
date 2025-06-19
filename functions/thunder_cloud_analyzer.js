// functions/thunder_cloud_analyzer.js - Dartロジックの直接移植
class ThunderCloudAnalyzer {
  // ✅ Dartから直接コピー&調整
  static analyzeWithMeteoDataOnly(meteoData) {
    const scores = {};

    // ✅ 既存Dartロジックをそのまま移植
    // 1. CAPE評価（重み40%）- 雲量追加のため重み調整
    const cape = meteoData.cape || 0.0;
    if (cape >= 2500) {
      scores.cape = 1.0;
    } else if (cape >= 1000) {
      scores.cape = 0.8;
    } else if (cape >= 500) {
      scores.cape = 0.6;
    } else if (cape >= 100) {
      scores.cape = 0.3;
    } else {
      scores.cape = 0.0;
    }

    // 2. Lifted Index評価（重み30%）- 雲量追加のため重み調整
    const liftedIndex = meteoData.lifted_index || 0.0;
    if (liftedIndex <= -6) {
      scores.lifted_index = 1.0;
    } else if (liftedIndex <= -3) {
      scores.lifted_index = 0.8;
    } else if (liftedIndex <= 0) {
      scores.lifted_index = 0.6;
    } else if (liftedIndex <= 3) {
      scores.lifted_index = 0.4;
    } else if (liftedIndex <= 6) {
      scores.lifted_index = 0.2;
    } else {
      scores.lifted_index = 0.0;
    }

    // 3. CIN評価（重み5%）- 修正版
    const cin = meteoData.convective_inhibition || 0.0;
    // CINは負の値で返される（負 = 抑制あり、0 = 抑制なし）
    if (cin >= -10) {  // -10 J/kg以上（抑制が弱い）
      scores.cin = 0.3;
    } else if (cin >= -50) {  // -50 J/kg以上（中程度の抑制）
      scores.cin = 0.1;
    } else {  // -50 J/kg未満（強い抑制）
      scores.cin = 0.0;
    }

    // 4. 温度評価（重み10%）
    const temperature = meteoData.temperature || 20.0;
    if (temperature >= 30) {
      scores.temperature = 1.0;
    } else if (temperature >= 25) {
      scores.temperature = 0.8;
    } else if (temperature >= 20) {
      scores.temperature = 0.6;
    } else if (temperature >= 15) {
      scores.temperature = 0.4;
    } else {
      scores.temperature = 0.0;
    }

    // 5. 雲量評価（重み15%）- 既存の入道雲検出
    const cloudCover = meteoData.cloud_cover || 0.0;
    const cloudCoverMid = meteoData.cloud_cover_mid || 0.0;
    const cloudCoverHigh = meteoData.cloud_cover_high || 0.0;

    // 中層・高層雲が多い場合は入道雲の可能性が高い
    const significantCloudCover = Math.max(cloudCoverMid, cloudCoverHigh);
    if (significantCloudCover >= 70) {  // 70%以上の雲量
      scores.cloud_cover = 1.0;
    } else if (significantCloudCover >= 50) {  // 50%以上の雲量
      scores.cloud_cover = 0.8;
    } else if (significantCloudCover >= 30) {  // 30%以上の雲量
      scores.cloud_cover = 0.6;
    } else if (significantCloudCover >= 15) {  // 15%以上の雲量
      scores.cloud_cover = 0.3;
    } else {
      scores.cloud_cover = 0.0;
    }

    // ✅ 重み配分を調整（雲量15%を追加）
    const totalScore = (
      scores.cape * 0.4 +
      scores.lifted_index * 0.3 +
      scores.cin * 0.05 +
      scores.temperature * 0.1 +
      scores.cloud_cover * 0.15
    );

    return {
      isThunderCloudLikely: totalScore >= 0.5,
      totalScore: totalScore,
      riskLevel: totalScore >= 0.5 ? "高い" :
                totalScore >= 0.3 ? "中程度" :
                totalScore >= 0.15 ? "低い" : "極めて低い",
      individualScores: scores
    };
  }
}

module.exports = { ThunderCloudAnalyzer };