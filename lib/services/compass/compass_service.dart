import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../../models/lat_lng.dart';
import '../../utils/logger.dart';

/// スマホが向いている方角（本当の北から時計回り）と、その精度
class Heading {
  final double trueDeg;

  /// 誤差の目安（°）。分からなければ null
  final double? accuracyDeg;

  const Heading(this.trueDeg, this.accuracyDeg);
}

/// 方位センサー
///
/// - iPhone は本当の北を基準にした角度がそのまま届く
/// - Android は磁北を基準にした角度が届くので、その場所の偏角（岩手で西へ約8°）を足して本当の北にする
class CompassService {
  CompassService._();

  static const MethodChannel _geomagnetic = MethodChannel('thunder_cloud/geomagnetic');

  /// その場所の偏角（磁北が本当の北から東へ何度ずれているか）。iPhone では使わないので 0
  static Future<double> declination(LatLng? point) async {
    if (!Platform.isAndroid || point == null) return 0;
    try {
      final value = await _geomagnetic.invokeMethod<double>('declination', {
        'latitude': point.latitude,
        'longitude': point.longitude,
      });
      return value ?? 0;
    } catch (e) {
      AppLogger.warning('偏角が分かりませんでした: $e', tag: 'CompassService');
      return 0;
    }
  }

  /// 開発中の確かめ用。デバッグ版で --dart-define=FAKE_HEADING=100 のように付けると、
  /// 方位センサーのないシミュレータでも、その方角を向いているとして動く
  static const String _fakeHeading = kDebugMode ? String.fromEnvironment('FAKE_HEADING') : '';

  /// 方位センサーの値。センサーがない端末（シミュレータなど）では何も届かない
  ///
  /// iPhone は、位置情報を許可する前は本当の北の角度が負（使えない）で届く。[allowMagneticFallback] が true なら、
  /// そのときは端末の動きから出した磁北の角度を使う（はじめの使い方の見本用。偏角は直さないので数°ずれる）
  static Stream<Heading> headings({double declinationDeg = 0, bool allowMagneticFallback = false}) {
    final fake = double.tryParse(_fakeHeading);
    if (fake != null) {
      return Stream.periodic(const Duration(milliseconds: 200), (_) => Heading(fake, 10));
    }
    final events = FlutterCompass.events;
    if (events == null) return const Stream.empty();
    return events.where((e) => e.heading != null).map((e) {
      var base = e.heading!;
      if (allowMagneticFallback && base < 0) base = e.headingForCameraMode ?? base;
      final deg = (base + declinationDeg) % 360;
      return Heading(deg < 0 ? deg + 360 : deg, e.accuracy);
    });
  }
}
