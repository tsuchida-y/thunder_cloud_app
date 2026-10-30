const { test } = require('node:test');
const assert = require('node:assert/strict');
const { RainLookup, latLngToPixel } = require('../modules/jma/rain_lookup');

// 1枚 256×256 の PNG を作り、指定のピクセルに色を塗る
function png(paint = []) {
  const data = Buffer.alloc(256 * 256 * 4);
  for (const [x, y, rgb] of paint) {
    const i = (y * 256 + x) * 4;
    data.set([...rgb, 255], i);
  }
  return { width: 256, height: 256, data };
}

const LIGHT_BLUE = [160, 210, 255]; // 雨 1mm/h 以上
const morioka = { latitude: 39.70, longitude: 141.15 };

function tileAndPixel(point, zoom) {
  const p = latLngToPixel(point.latitude, point.longitude, zoom);
  return { x: Math.floor(p.x / 256), y: Math.floor(p.y / 256), px: p.x % 256, py: p.y % 256 };
}

function setup({ coarseRain, detailRain }) {
  const c = tileAndPixel(morioka, 4);
  const d = tileAndPixel(morioka, 6);
  const requests = [];
  const jma = {
    async getAnalysisTiles(basetime, element, zoom, tiles) {
      requests.push({ zoom, tiles });
      return tiles.map((t) => ({ ...t, png: png(detailRain ? [[d.px, d.py, LIGHT_BLUE]] : []) }));
    },
  };
  const coarse = [{ x: c.x, y: c.y, png: png(coarseRain ? [[c.px, c.py, LIGHT_BLUE]] : []) }];
  return { lookup: new RainLookup(jma, '20260812062000', coarse), requests };
}

test('z4 で雨がなければ z6 を取りに行かずに「雨なし」', async () => {
  const { lookup, requests } = setup({ coarseRain: false, detailRain: true });
  assert.equal(await lookup.isRaining(morioka.latitude, morioka.longitude), false);
  assert.equal(requests.length, 0);
});

test('z4 で雨があれば z6 で地点そのものを調べ、同じタイルは1回だけ取る', async () => {
  const wet = setup({ coarseRain: true, detailRain: true });
  assert.equal(await wet.lookup.isRaining(morioka.latitude, morioka.longitude), true);
  assert.equal(await wet.lookup.isRaining(morioka.latitude, morioka.longitude), true);
  assert.equal(wet.requests.length, 1);
  assert.equal(wet.requests[0].zoom, 6);

  // z4 では近くに雨があっても、地点そのものに雨がなければ「雨なし」
  const dry = setup({ coarseRain: true, detailRain: false });
  assert.equal(await dry.lookup.isRaining(morioka.latitude, morioka.longitude), false);
});

test('日本の外（z4 のタイルがない所）は雨なし', async () => {
  const { lookup } = setup({ coarseRain: true, detailRain: true });
  assert.equal(await lookup.rainAt(0, 0), null);
});
