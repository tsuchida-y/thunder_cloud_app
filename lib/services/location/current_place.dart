import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/lat_lng.dart';
import '../../utils/logger.dart';

/// 位置情報の許可の状態
enum LocationAccess {
  /// 使える（「使用中のみ」か「常に」）
  granted,

  /// まだ聞いていない
  notAsked,

  /// 許可されていない、または端末の位置情報がオフ
  off,
}

/// ホームで使う「いまいる場所」（v2.0）
///
/// v1 の LocationService と違い、Firestore には書かない（members への保存は MemberService）。
class CurrentPlace {
  CurrentPlace._();

  static final Geocoding _geocoding = Geocoding();
  static const Locale _japanese = Locale('ja', 'JP');

  static Future<LocationAccess> access() async {
    if (!await Geolocator.isLocationServiceEnabled()) return LocationAccess.off;
    switch (await Geolocator.checkPermission()) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationAccess.granted;
      case LocationPermission.denied:
        return LocationAccess.notAsked;
      case LocationPermission.deniedForever:
      case LocationPermission.unableToDetermine:
        return LocationAccess.off;
    }
  }

  static const MethodChannel _foreground = MethodChannel('thunder_cloud/location_foreground');
  static const MethodChannel _always = MethodChannel('thunder_cloud/location_always');

  /// 「使用中のみ」の許可をお願いする（はじめての起動の画面と、許可がないときの画面から）
  ///
  /// 「常に」はいきなり聞かない（CLAUDE.md）。iOS は Info.plist に「使用中」の説明があるので geolocator で「使用中」だけを聞く。
  /// Android は geolocator だと Android 10 で「常に」も一緒に聞いてしまうので、MainActivity の「使用中」だけのお願いを使う。
  static Future<LocationAccess> request() async {
    if (Platform.isAndroid) {
      final granted = await _foreground.invokeMethod<bool>('request') ?? false;
      return granted ? LocationAccess.granted : LocationAccess.off;
    }
    final permission = await Geolocator.requestPermission();
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse
        ? LocationAccess.granted
        : LocationAccess.off;
  }

  /// 「常に」になっているか
  static Future<bool> isAlways() async => await Geolocator.checkPermission() == LocationPermission.always;

  /// 「常に」をお願いする（AlwaysAllow.html の「「常に」にする」）
  ///
  /// iOS は確認の画面を出す。iOS がもう聞かせてくれないとき（2回目以降）と Android は設定アプリを開く。
  /// 「常に」になったら true
  static Future<bool> requestAlways() async {
    if (Platform.isIOS) {
      final result = await _always.invokeMethod<String>('requestAlways');
      if (result == 'always') return true;
      // 確認の画面を出せなかったときだけ設定アプリを開く（断った人には開かない）
      if (result == 'unavailable') await Geolocator.openAppSettings();
      return isAlways();
    }
    await Geolocator.openAppSettings();
    return false;
  }

  /// いまの位置。取れなければ最後に分かった位置
  static Future<LatLng?> position() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 15));
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      AppLogger.warning('いまの位置が取れませんでした: $e', tag: 'CurrentPlace');
      final last = await Geolocator.getLastKnownPosition();
      return last == null ? null : LatLng(last.latitude, last.longitude);
    }
  }

  /// 最後に分かった位置（すぐ返る。方角ガイドの偏角など、だいたいの場所で足りるときに使う）
  static Future<LatLng?> lastKnown() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      return last == null ? null : LatLng(last.latitude, last.longitude);
    } catch (_) {
      return null;
    }
  }

  /// 場所の名前（「滝沢市」など）。分からなければ null
  ///
  /// 端末の地名検索（iOS は Apple、Android は Google）を使う。同じ場所（約1km）なら前の結果を使う。
  static Future<String?> placeName(LatLng location) async {
    final key = 'place_name_${location.latitude.toStringAsFixed(2)}_${location.longitude.toStringAsFixed(2)}';
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(key);
      if (cached != null) return cached;

      final marks = await _geocoding.placemarkFromCoordinates(location.latitude, location.longitude, locale: _japanese);
      final name = marks
          .map((m) => [m.locality, m.subAdministrativeArea, m.administrativeArea])
          .expand((names) => names)
          .firstWhere((n) => n != null && n.isNotEmpty, orElse: () => null);
      if (name != null) await prefs.setString(key, name);
      return name;
    } catch (e) {
      AppLogger.warning('場所の名前が分かりませんでした: $e', tag: 'CurrentPlace');
      return null;
    }
  }

  static Future<bool> openAppSettings() => Geolocator.openAppSettings();

  static Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
