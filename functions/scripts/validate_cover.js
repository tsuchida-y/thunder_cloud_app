/**
 * 空港の観測（METAR）と、ひまわりの雲の量が合っているかを集計する（しきい値の調整用）
 *
 * 使い方: functions フォルダで `npm run validate:cover`（先に `gcloud auth application-default login` が済んでいること）
 *   日数を変えるときは `npm run validate:cover -- 14`（既定は7日）
 *
 * sky_validation（recordAirportObservations が30分ごとに書く）を読んで、
 * - 空港の観測が「曇り」のとき、赤外の雲の量がしきい値以上か（曇りを見つけた割合）
 * - 空港の観測が「ほぼ晴れ」のとき、しきい値以上になってしまうか（間違えた割合）
 * を、気温との差（5・8・12℃）と割合（50・70・80・90%）の組み合わせごとに出す。
 * あわせて、昼と夜、雲底の高さ、積乱雲・雄大積雲の記号のある観測を数える。
 */

const admin = require('firebase-admin');
const { evaluateAgreement } = require('../modules/validation/airport_observer');
const { VALIDATION, CLOUD_COVER } = require('../constants');

const percent = (a, b) => (b === 0 ? '-' : `${Math.round((a / b) * 100)}%`);
const describe = (r) => `曇りを見つけた ${percent(r.coveredFound, r.coveredTotal)}（${r.coveredFound}/${r.coveredTotal}）、` +
  `晴れを曇りと間違えた ${percent(r.clearWrong, r.clearTotal)}（${r.clearWrong}/${r.clearTotal}）`;

(async () => {
  admin.initializeApp({ projectId: 'thunder-cloud-app-292e6' });
  const days = Number(process.argv[2]) || 7;
  const since = admin.firestore.Timestamp.fromDate(new Date(Date.now() - days * 24 * 60 * 60 * 1000));
  const snapshot = await admin.firestore().collection(VALIDATION.COLLECTION).where('observedAt', '>=', since).get();
  const stations = [];
  snapshot.docs.forEach((doc) => doc.data().stations.forEach((s) => stations.push(s)));
  const withInfrared = stations.filter((s) => s.ir).length;
  console.log(`直近${days}日: 記録 ${snapshot.size} 件、空港の観測 ${stations.length} 件（雲の量つき ${withInfrared} 件）`);
  if (stations.length === 0) return;

  const covered = stations.filter((s) => s.covered).length;
  const clear = stations.filter((s) => s.clearish).length;
  const neither = stations.length - covered - clear;
  console.log(`空港の観測: 曇り（BKN/OVC） ${covered} 件、ほぼ晴れ（FEW 以下） ${clear} 件、どちらでもない ${neither} 件\n`);

  console.log('しきい値ごとの合い方（いまの設定は、気温より%d℃以上冷たいピクセルが80%以上）'.replace('%d', CLOUD_COVER.COLD_DELTA_C));
  const deltas = [CLOUD_COVER.COLD_DELTA_C, ...CLOUD_COVER.EXTRA_DELTAS_C].sort((a, b) => a - b);
  for (const delta of deltas) {
    for (const fraction of [0.5, 0.7, 0.8, 0.9]) {
      const r = evaluateAgreement(stations, { delta, fraction });
      console.log(`  ${delta}℃・${fraction * 100}%以上: ${describe(r)}`);
    }
  }

  const current = { delta: CLOUD_COVER.COLD_DELTA_C, fraction: CLOUD_COVER.OVERCAST_FRACTION };
  console.log('\nいまの設定で、条件ごとに分けると');
  const groups = {
    '昼（太陽 10°以上）': (s) => s.sunAltitudeDeg >= 10,
    '朝夕（太陽 0〜10°）': (s) => s.sunAltitudeDeg >= 0 && s.sunAltitudeDeg < 10,
    '夜（太陽 0°未満）': (s) => s.sunAltitudeDeg < 0,
    '雲底が低い（1500ft 以下）': (s) => s.lowestBaseFt !== null && s.lowestBaseFt <= 1500,
    '雲底が高い（1500ft より上）': (s) => s.lowestBaseFt !== null && s.lowestBaseFt > 1500,
  };
  for (const [name, test] of Object.entries(groups)) {
    const r = evaluateAgreement(stations.filter(test), current);
    console.log(`  ${name}: ${describe(r)}`);
  }

  const convective = stations.filter((s) => s.hasConvective);
  console.log(`\n積乱雲（CB）・雄大積雲（TCU）の記号がある観測: ${convective.length} 件`);
  convective.slice(0, 10).forEach((s) => {
    const marks = s.convective.map((c) => `${c.type}${c.baseFt}ft`).join(',');
    const cover = s.ir ? s.ir.fractions[String(CLOUD_COVER.COLD_DELTA_C)] : '-';
    console.log(`  ${s.obsTime} ${s.icao} ${marks}  雲の量 ${cover}`);
  });
})().catch((error) => {
  console.error('失敗しました:', error.message);
  process.exitCode = 1;
});
