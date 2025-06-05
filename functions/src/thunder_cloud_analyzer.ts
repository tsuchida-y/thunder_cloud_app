// functions/src/thunder_cloud_analyzer.ts - Dartロジックの直接移植
export class ThunderCloudAnalyzer {
  // ✅ Dartから直接コピー&調整
  static analyzeWithMeteoDataOnly(meteoData: any) {
    const scores: {[key: string]: number} = {};

    // ✅ 既存Dartロジックをそのまま移植
    // 1. CAPE評価（重み50%）
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

    // 2. Lifted Index評価（重み35%）
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

    // 3. CIN評価（重み5%）
    const cin = meteoData.convective_inhibition || 0.0;
    if (cin <= 10) {
      scores.cin = 0.3;
    } else if (cin <= 50) {
      scores.cin = 0.1;
    } else {
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

    // ✅ 重み配分も完全に同じ
    const totalScore = (
      scores.cape * 0.5 +
      scores.lifted_index * 0.35 +
      scores.cin * 0.05 +
      scores.temperature * 0.1
    );

    return {
      isThunderCloudLikely: totalScore >= 0.6,
      totalScore: totalScore,
      riskLevel: totalScore >= 0.6 ? "高い" :
                totalScore >= 0.3 ? "中程度" :
                totalScore >= 0.15 ? "低い" : "極めて低い",
      individualScores: scores
    };
  }
}