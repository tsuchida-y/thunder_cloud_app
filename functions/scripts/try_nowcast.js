/**
 * 気象庁ナウキャストから、いまある雲の塊を取り出して表示する（Firestore には書かない）
 *
 * 使い方: functions フォルダで `npm run try:nowcast`
 * 表示された場所を気象庁ホームページの「雨雲の動き」「雷活動度」と見比べて確かめる。
 * https://www.jma.go.jp/bosai/nowc/
 */

const NowcastService = require('../modules/jma/nowcast_service');
const JmaClient = require('../modules/jma/jma_client');

function toJst(jmaTime) {
  if (!jmaTime) return 'なし';
  const date = JmaClient.parseTime(jmaTime);
  return new Date(date.getTime() + 9 * 60 * 60 * 1000).toISOString().slice(0, 16).replace('T', ' ') + ' (日本時間)';
}

(async () => {
  const service = new NowcastService();
  const { times, clusters, requestCount, lowClusterCount, amedasStations, errors } = await service.detectClusters();
  console.log(`降水の解析時刻: ${toJst(times.rain)}`);
  console.log(`雷の解析時刻:   ${toJst(times.thunder)}`);
  console.log(`気象庁へのリクエスト: ${requestCount}回`);
  console.log(`ひまわり: ${errors.himawari ? `取れませんでした（${errors.himawari.message}）` : 'OK'}` +
    `  アメダス: ${errors.amedas ? `取れませんでした（${errors.amedas.message}）` : `OK（${amedasStations.length}地点）`}`);
  console.log(`見つけた雲: ${clusters.length}個（てっぺんが冷たくないので外した塊 ${lowClusterCount}個）\n`);
  clusters.forEach((c, i) => {
    console.log(
      `${String(i + 1).padStart(2)}. 北緯${c.latitude.toFixed(3)} 東経${c.longitude.toFixed(3)}` +
      `  雨${c.maxRainMmPerHour}mm/h以上  雷の活動度${c.maxThunderLevel}  広さ約${c.areaKm2.toFixed(0)}km²` +
      (c.topTempC === null ? '  てっぺん不明' : `  てっぺん約${c.topTempC.toFixed(0)}℃・約${c.topHeightKm.toFixed(1)}km`) +
      `  https://www.google.com/maps?q=${c.latitude.toFixed(4)},${c.longitude.toFixed(4)}`
    );
  });
})().catch((error) => {
  console.error('失敗しました:', error.message);
  process.exitCode = 1;
});
