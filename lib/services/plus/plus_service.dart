import 'dart:io';

import 'package:flutter/foundation.dart';
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

  /// ストア（RevenueCat）で見て、いま Plus の権利があるか。買った直後や復元した直後は、
  /// webhook が届いてサーバー（member_server）が Plus になるまで少しかかるので、そのあいだもこれで Plus として扱う
  static final ValueNotifier<bool> activeInStore = ValueNotifier(false);

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
      // 買う・復元する・期限が切れるたびに知らせが来る
      Purchases.addCustomerInfoUpdateListener(_updateActive);
      _updateActive(await Purchases.getCustomerInfo());
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

  static void _updateActive(CustomerInfo info) {
    activeInStore.value = info.entitlements.active.containsKey(entitlementId);
  }

  /// いまの Plus の契約（プラン、期限、解約済みか、ストアの管理画面）。Plus でなければ null
  static Future<PlusStatus?> status() async {
    if (!_configured) return null;
    try {
      final info = await Purchases.getCustomerInfo();
      final entitlement = info.entitlements.active[entitlementId];
      if (entitlement == null) return null;
      final expiration = entitlement.expirationDate;
      return PlusStatus(
        lifetime: expiration == null,
        expiresAt: expiration == null ? null : DateTime.tryParse(expiration)?.toLocal(),
        willRenew: entitlement.willRenew,
        inTrial: entitlement.periodType == PeriodType.trial,
        managementUrl: info.managementURL == null ? null : Uri.tryParse(info.managementURL!),
      );
    } catch (e) {
      AppLogger.warning('Plus の契約を取れませんでした: $e', tag: 'PlusService');
      return null;
    }
  }

  /// 買う。Plus になったら true、やめたら false
  static Future<bool> purchase(Package package) async {
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      _updateActive(result.customerInfo);
      return activeInStore.value;
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) == PurchasesErrorCode.purchaseCancelledError) return false;
      rethrow;
    }
  }

  /// 購入を復元する。Plus なら true
  static Future<bool> restore() async {
    final info = await Purchases.restorePurchases();
    _updateActive(info);
    return activeInStore.value;
  }
}

/// 月額と買い切りの商品（買い切りには、ストアの仕組みで無料体験を付けられない）
class PlusPlans {
  final Package monthly;
  final Package lifetime;
  final bool monthlyTrial;

  const PlusPlans({required this.monthly, required this.lifetime, required this.monthlyTrial});
}

/// いまの Plus の契約
class PlusStatus {
  /// 買い切りか（期限がない）
  final bool lifetime;

  /// 月額の、今の期間の終わり（更新される日、解約済みなら使える最後の日）
  final DateTime? expiresAt;

  /// 期限が来たら自動で更新されるか（解約済みなら false）
  final bool willRenew;

  /// 7日間の無料体験中か
  final bool inTrial;

  /// ストアのサブスクリプションの管理画面（解約はここから）
  final Uri? managementUrl;

  const PlusStatus({
    required this.lifetime,
    required this.expiresAt,
    required this.willRenew,
    required this.inTrial,
    required this.managementUrl,
  });
}
