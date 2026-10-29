import 'package:flutter_test/flutter_test.dart';
import 'package:thunder_cloud_app/models/lat_lng.dart';
import 'package:thunder_cloud_app/services/location/current_place.dart';

void main() {
  test('地名の分からない海の上の雲は、いちばん近い都道府県の沖とする', () {
    // 沖縄本島の東の海、男鹿半島の西の日本海、房総半島の東の太平洋
    expect(CurrentPlace.offshoreName(const LatLng(26.4, 128.3)), '沖縄県の沖');
    expect(CurrentPlace.offshoreName(const LatLng(39.9, 139.3)), '秋田県の沖');
    expect(CurrentPlace.offshoreName(const LatLng(35.4, 141.0)), '千葉県の沖');
  });
}
