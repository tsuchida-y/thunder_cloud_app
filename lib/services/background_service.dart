import 'package:workmanager/workmanager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:developer';
import 'geolocator.dart';
import 'weather/weather_logic.dart';
import 'notification_service.dart';

class BackgroundService {
  static const String _taskName = "thunder_cloud_background_check";

  /// バックグラウンドサービスの初期化
  static Future<void> initialize() async {
    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: true, // デバッグ時はtrue
      );
      log("Workmanager初期化完了");
    } catch (e) {
      log("Workmanager初期化エラー: $e");
      rethrow;
    }
  }

  /// 定期チェックの開始
  static Future<void> startPeriodicCheck() async {
    try {
      // 既存のタスクをキャンセル
      await Workmanager().cancelByUniqueName(_taskName);
      
      // 新しいタスクを登録
      await Workmanager().registerPeriodicTask(
        _taskName,
        _taskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
      );
      log("バックグラウンド定期チェックを開始しました");
    } catch (e) {
      log("バックグラウンドタスク登録エラー: $e");
      rethrow;
    }
  }

  /// 定期チェックの停止
  static Future<void> stopPeriodicCheck() async {
    try {
      await Workmanager().cancelByUniqueName(_taskName);
      log("バックグラウンド定期チェックを停止しました");
    } catch (e) {
      log("バックグラウンドタスク停止エラー: $e");
    }
  }

  /// チェック状況を確認
  static Future<bool> isRunning() async {
    // WorkManagerには直接的な確認方法がないため、SharedPreferencesなどで管理
    return true; // 簡略化
  }
}

/// バックグラウンドタスクのコールバック関数
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      log("バックグラウンドタスク開始: $task");
      
      // 環境変数の読み込み
      await dotenv.load(fileName: ".env");
      
      // 現在地取得
      await checkPermission();
      final position = await getCurrentLocation();
      
      // 天気情報取得
      final result = await fetchWeatherInDirections(
        position.latitude,
        position.longitude,
      );
      
      // 通知の送信（入道雲がある場合のみ）
      if (result.isNotEmpty) {
        // 方向を日本語に変換
        final japaneseDirections = result.map((dir) {
          switch (dir) {
            case 'north': return '北';
            case 'south': return '南';
            case 'east': return '東';
            case 'west': return '西';
            default: return dir;
          }
        }).toList();
        
        await NotificationService.showThunderCloudNotification(japaneseDirections);
      }
      
      log("バックグラウンドタスク完了: 入道雲 ${result.length}箇所");
      return Future.value(true);
      
    } catch (e) {
      log("バックグラウンドタスクエラー: $e");
      return Future.value(false);
    }
  });
}