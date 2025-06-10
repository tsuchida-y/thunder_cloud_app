#!/bin/bash
# 🚀 入道雲サーチアプリ - App Store Upload Script

echo "🌩️ 入道雲サーチアプリ v1.0.0 - App Store Upload開始"

# ステップ1: クリーンビルド
echo "🧹 クリーンビルド中..."
flutter clean
flutter pub get

# ステップ2: iOSリリースビルド
echo "📱 iOSリリースビルド中..."
flutter build ios --release

# ステップ3: Xcodeアーカイブ（手動で実行）
echo "📦 次のステップ（手動実行）:"
echo "1. Xcodeで Runner.xcworkspace を開く"
echo "2. Product > Archive を実行"
echo "3. Organizer で Distribute App を選択"
echo "4. App Store Connect を選択"
echo "5. Upload を実行"

# ステップ4: 次回バージョン準備
echo "🏷️ 次のバージョン準備:"
echo "flutter pub version patch  # 1.0.0+2"
echo "flutter pub version minor  # 1.1.0+1"
echo "flutter pub version major  # 2.0.0+1"

echo "✅ 準備完了！Xcodeでアーカイブしてください"