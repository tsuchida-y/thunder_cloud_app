// functions/coordinate_utils.js - 座標計算ユーティリティ（定数ファイル対応）

// 定数ファイルをインポート
const { WEATHER_CONSTANTS } = require('./constants');

/**
 * 指定方向と距離から座標を計算
 */
function calculateDirectionCoordinates(direction, currentLatitude, currentLongitude, distanceKm) {
  // 緯度1度あたりの距離（定数ファイルから参照）
  const latitudePerDegreeKm = WEATHER_CONSTANTS.LATITUDE_PER_DEGREE_KM;
  let latitudeOffset = WEATHER_CONSTANTS.DEFAULT_WEATHER_VALUE;
  let longitudeOffset = WEATHER_CONSTANTS.DEFAULT_WEATHER_VALUE;

  switch (direction) {
  case 'north':
    latitudeOffset = distanceKm / latitudePerDegreeKm;
    break;
  case 'south':
    latitudeOffset = -distanceKm / latitudePerDegreeKm;
    break;
  case 'east':
    longitudeOffset = distanceKm / (latitudePerDegreeKm * Math.cos(currentLatitude * Math.PI / 180.0));
    break;
  case 'west':
    longitudeOffset = -distanceKm / (latitudePerDegreeKm * Math.cos(currentLatitude * Math.PI / 180.0));
    break;
  default:
    throw new Error(`未知の方向: ${direction}`);
  }

  return {
    latitude: currentLatitude + latitudeOffset,
    longitude: currentLongitude + longitudeOffset
  };
}

module.exports = {
  calculateDirectionCoordinates
};