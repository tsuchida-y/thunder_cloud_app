import 'dart:io';

import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../utils/logger.dart';

/// Plus（月額200円・7日間無料と、買い切り1,200円。RevenueCat。2026-10-27 に年額をやめて買い切りにした）
///
/// - RevenueCat の「アプリのユーザー ID」に Firebase の匿名ログインの uid を使う。
///   webhook（functions/modules/plus/revenuecat_webhook.js）がその uid の member_server に isPlus を書く
/// - 通知の範囲など Plus かどうかの判断はサーバー（member_server）が正。
///   買った直後は webhook が届くまで少しかかるので、アプリの表示は RevenueCat の結果も見る
/// - RevenueCat の公開用の API キーは、ビルドのときに --dart-define で渡す
///   （REVENUECAT_IOS_KEY, REVENUECAT_ANDROID_KEY）。ないときは購入の画面を「準備中」にする
class PlusService {
  PlusService._();

  /// RevenueCat の管理画面で作る権利（entitlement）の ID
  static const String entitlementId = 'plus';

  static const String _iosKey = String.fromEnvironment('REVENUECAT_IOS_KEY');
  static const String _androidKey = String.fromEnvironment('REVENUECAT_ANDROID_KEY');

  static bool _configured = false;

  static String get _apiKey => Platform.isIOS ? _iosKey : _androidKey;

  /// 購入できる状態か（API キーがあり、設定が済んでいる）
  static bool get available => _configured;

  /// ログインのあとに1回呼ぶ
  static Future<void> configure(String uid) async {
    if (_configured || _apiKey.isEmpty) return;
    try {
      final configuration = PurchasesConfiguration(_apiKey)..appUserID = uid;
      await Purchases.configure(configuration);
      _configured = true;
    } catch (e) {
      AppLogger.warning('RevenueCat を設定できませんでした: $e', tag: 'PlusService');
    }
  }

  /// 月額と買い切りの商品。取れなければ null
  static Future<PlusPlans?> plans() async {
    if (!_configured) return null;
    try {
      final offering = (await Purchases.getOfferings()).current;
      final monthly = offering?.monthly;
      final lifetime = offering?.lifetime;
      if (monthly == null || lifetime == null) return null;
      return PlusPlans(
        monthly: monthly,
        lifetime: lifetime,
        monthlyTrial: await _trialAvailable(monthly),
      );
    } catch (e) {
      AppLogger.warning('Plus の商品を取れませんでした: $e', tag: 'PlusService');
      return null;
    }
  }

  /// 無料体験を使えるか（使えない人に「無料で試す」と出さないため。ストアの審査）
  static Future<bool> _trialAvailable(Package package) async {
    final product = package.storeProduct;
    if (Platform.isAndroid) {
      // Google Play は、使える人にだけ無料の期間がついた買い方を返す
      return product.defaultOption?.freePhase != null;
    }
    final intro = product.introductoryPrice;
    if (intro == null || intro.price != 0) return false;
    final eligibility = await Purchases.checkTrialOrIntroductoryPriceEligibility([product.identifier]);
    return eligibility[product.identifier]?.status == IntroEligibilityStatus.introEligibilityStatusEligible;
  }

  /// 買う。Plus になったら true、やめたら false
  static Future<bool> purchase(Package package) async {
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      return result.customerInfo.entitlements.active.containsKey(entitlementId);
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) == PurchasesErrorCode.purchaseCancelledError) return false;
      rethrow;
    }
  }

  /// 購入を復元する。Plus なら true
  static Future<bool> restore() async {
    final info = await Purchases.restorePurchases();
    return info.entitlements.active.containsKey(entitlementId);
  }
}

/// 月額と買い切りの商品（買い切りには、ストアの仕組みで無料体験を付けられない）
class PlusPlans {
  final Package monthly;
  final Package lifetime;
  final bool monthlyTrial;

  const PlusPlans({required this.monthly, required this.lifetime, required this.monthlyTrial});
}
