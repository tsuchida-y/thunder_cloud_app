import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/lat_lng.dart';
import '../../models/prefectures.dart';
import '../../utils/logger.dart';
import '../../utils/sky_geometry.dart';

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
  static const MethodChannel _background = MethodChannel('thunder_cloud/background_location');

  /// 「常に」の人の場所を、アプリを閉じているあいだも members に書く仕組みを、許可に合わせて始める・止める
  ///
  /// iOS は AppDelegate.swift（大きな移動の検知）が許可の変化を見て自分で始めるので、Android だけ。
  /// Android は MainActivity と BackgroundLocation.kt（15分ごとの定期処理）。アプリを開くたびに呼ぶ。
  static Future<void> syncBackground() async {
    if (!Platform.isAndroid) return;
    try {
      await _background.invokeMethod<bool>('sync');
    } catch (e) {
      AppLogger.warning('バックグラウンドの位置の更新を設定できませんでした: $e', tag: 'CurrentPlace');
    }
  }

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

  /// 入道雲のある所の目安（「秋田市のあたり」「太平洋の上」「秋田県の沖」）。ホームの全国の入道雲に使う
  ///
  /// 市町村 → 都道府県 → 海などの名前 の順に使う。地名の検索で何も分からなかったとき（海の上など）は、
  /// いちばん近い都道府県庁から「〜の沖」とする。同じ場所（約10km）なら前の結果を使う。
  /// 端末の地名検索は一度に1つしか調べられないので、順番に調べる。
  static Future<String> areaName(LatLng location) async {
    final key = 'area_name_${location.latitude.toStringAsFixed(1)}_${location.longitude.toStringAsFixed(1)}';
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(key);
    if (cached != null) return cached;
    final previous = _areaQueue;
    final next = previous.then((_) => _lookUpArea(location, key, prefs));
    _areaQueue = next.catchError((_) => '');
    return next;
  }

  static Future<String> _areaQueue = Future.value('');

  static Future<String> _lookUpArea(LatLng location, String key, SharedPreferences prefs) async {
    try {
      final cached = prefs.getString(key);
      if (cached != null) return cached;
      final marks = await _geocoding.placemarkFromCoordinates(location.latitude, location.longitude, locale: _japanese);
      String? pick(String? Function(dynamic m) field) =>
          marks.map(field).firstWhere((n) => n != null && n.trim().isNotEmpty, orElse: () => null);
      final city = pick((m) => m.locality) ?? pick((m) => m.subAdministrativeArea);
      final prefecture = pick((m) => m.administrativeArea);
      // 海の上では、市町村や県の代わりに「太平洋」などの名前だけが返ることがある（数字だけのものは使わない）
      final other = pick((m) => m.name);
      final String area;
      if (city != null) {
        area = '$cityのあたり';
      } else if (prefecture != null) {
        area = '$prefectureのあたり';
      } else if (other != null && !RegExp(r'^[\d\s.,\-]+$').hasMatch(other)) {
        area = '$otherの上';
      } else {
        area = offshoreName(location);
      }
      await prefs.setString(key, area);
      return area;
    } catch (e) {
      AppLogger.warning('入道雲の場所の名前が分かりませんでした: $e', tag: 'CurrentPlace');
      return offshoreName(location);
    }
  }

  /// いちばん近い都道府県庁から「〜の沖」
  static String offshoreName(LatLng location) {
    var best = prefectureOffices.first;
    var bestKm = double.infinity;
    for (final office in prefectureOffices) {
      final km = SkyGeometry.distanceKm(location, office.$2);
      if (km < bestKm) {
        best = office;
        bestKm = km;
      }
    }
    return '${best.$1}の沖';
  }

  /// 地名や住所から場所をさがす（見張る場所の登録。地図は使わない）
  ///
  /// 端末の地名検索を使う。見つからなければ空のリスト。同じ地名の候補はまとめる。
  static Future<List<PlaceCandidate>> search(String query) async {
    final text = query.trim();
    if (text.isEmpty) return const [];
    try {
      final locations = await _geocoding.locationFromAddress(text, locale: _japanese);
      final candidates = <PlaceCandidate>[];
      final seen = <String>{};
      for (final location in locations.take(5)) {
        final point = LatLng(location.latitude, location.longitude);
        final marks = await _geocoding.placemarkFromCoordinates(point.latitude, point.longitude, locale: _japanese);
        final mark = marks.isEmpty ? null : marks.first;
        final parts = [mark?.administrativeArea, mark?.locality, mark?.subLocality]
            .whereType<String>()
            .where((p) => p.isNotEmpty)
            .toList();
        final name = parts.isEmpty ? text : parts.toSet().join();
        if (seen.add(name)) {
          candidates.add(PlaceCandidate(
            name: name,
            shortName: mark?.locality?.isNotEmpty == true ? mark!.locality! : name,
            region: mark?.administrativeArea,
            location: point,
          ));
        }
      }
      return candidates;
    } catch (e) {
      AppLogger.warning('場所が見つかりませんでした: $e', tag: 'CurrentPlace');
      return const [];
    }
  }

  static Future<bool> openAppSettings() => Geolocator.openAppSettings();

  static Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}

/// 場所さがしの候補
class PlaceCandidate {
  /// 「岩手県盛岡市内丸」
  final String name;

  /// 「盛岡市」（登録したときの地名と、名前の最初の案に使う）
  final String shortName;

  /// 「岩手県」（候補の右に出す）。分からなければ null
  final String? region;
  final LatLng location;

  const PlaceCandidate({required this.name, required this.shortName, required this.location, this.region});
}
