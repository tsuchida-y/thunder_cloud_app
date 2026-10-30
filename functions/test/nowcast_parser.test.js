const { test } = require('node:test');
const assert = require('node:assert/strict');
const {
  rainFromColor,
  thunderFromColor,
  pixelToLatLng,
  collectPixels,
  extractClusters,
} = require('../modules/jma/nowcast_parser');

test('雨の色を強さの下限に直す（凡例とタイルで少し違う黄色も読める）', () => {
  assert.equal(rainFromColor(255, 153, 0, 255), 30);
  assert.equal(rainFromColor(255, 40, 0, 255), 50);
  assert.equal(rainFromColor(180, 0, 104, 255), 80);
  assert.equal(rainFromColor(250, 245, 0, 255), 20);
  assert.equal(rainFromColor(255, 245, 0, 255), 20);
  assert.equal(rainFromColor(0, 0, 0, 0), null);
  assert.equal(rainFromColor(10, 200, 10, 255), null);
});

test('雷の色を活動度に直す', () => {
  assert.equal(thunderFromColor(250, 245, 0, 255), 1);
  assert.equal(thunderFromColor(255, 170, 0, 255), 2);
  assert.equal(thunderFromColor(255, 40, 0, 255), 3);
  assert.equal(thunderFromColor(200, 0, 255, 255), 4);
  assert.equal(thunderFromColor(0, 0, 0, 0), 0);
});

test('ピクセル座標を緯度経度に直す（z6 のタイル 57,24 の左上は青森県と秋田県の境あたり）', () => {
  const { latitude, longitude } = pixelToLatLng(57 * 256, 24 * 256, 6);
  assert.ok(Math.abs(longitude - 140.62) < 0.05, `経度 ${longitude}`);
  assert.ok(Math.abs(latitude - 40.98) < 0.05, `緯度 ${latitude}`);
});

function fakePng(width, height, paint) {
  const data = Buffer.alloc(width * height * 4);
  for (const [x, y, rgb] of paint) {
    const i = (y * width + x) * 4;
    data[i] = rgb[0];
    data[i + 1] = rgb[1];
    data[i + 2] = rgb[2];
    data[i + 3] = 255;
  }
  return { width, height, data };
}

test('条件に合うピクセルだけを全体の座標で拾う', () => {
  const png = fakePng(4, 4, [[1, 2, [255, 153, 0]], [3, 3, [160, 210, 255]]]);
  const pixels = collectPixels(png, 2, 1, rainFromColor, (mm) => mm !== null && mm >= 30);
  assert.deepEqual(pixels, [{ x: 2 * 256 + 1, y: 256 + 2, value: 30 }]);
});

test('つながったピクセルを1つの塊にまとめ、離れたものは別の塊にする', () => {
  const rain = [
    { x: 100, y: 100, value: 30 },
    { x: 101, y: 101, value: 50 }, // 斜めでもつながる
    { x: 200, y: 200, value: 80 },
  ];
  const thunder = [
    { x: 102, y: 101, value: 2 }, // 雨の塊に隣り合う雷
    { x: 300, y: 300, value: 3 }, // 雷だけの塊
  ];
  const clusters = extractClusters(rain, thunder, 6);
  assert.equal(clusters.length, 3);

  const big = clusters[0];
  assert.equal(big.pixelCount, 3);
  assert.equal(big.maxRainMmPerHour, 50);
  assert.equal(big.maxThunderLevel, 2);

  const thunderOnly = clusters.find((c) => c.maxRainMmPerHour === 0);
  assert.equal(thunderOnly.maxThunderLevel, 3);
});

test('塊のふちの点を返す（3×3 の塊なら真ん中を除く8点）', () => {
  const rain = [];
  for (let x = 0; x < 3; x++) for (let y = 0; y < 3; y++) rain.push({ x: 1000 + x, y: 2000 + y, value: 30 });
  const [cluster] = extractClusters(rain, [], 6);
  assert.equal(cluster.edgePoints.length, 8);
  const middle = pixelToLatLng(1001, 2001, 6);
  const isMiddle = (p) => p.latitude === middle.latitude && p.longitude === middle.longitude;
  assert.equal(cluster.edgePoints.some(isMiddle), false);
});
