import 'package:flutter/material.dart';

/// レスポンシブな座標計算を提供するクラス（SafeArea基準）
class ResponsiveAvatarPositions {
  /// SafeAreaを基準とした動的アバター位置計算
  static Map<String, Offset> calculatePositions(Size screenSize, EdgeInsets safeArea) {
    // SafeAreaを考慮した実際の利用可能エリア
    final double availableWidth = screenSize.width - safeArea.left - safeArea.right;
    final double availableHeight = screenSize.height - safeArea.top - safeArea.bottom;

    // SafeAreaの開始位置
    final double startX = safeArea.left;
    final double startY = safeArea.top;

    // アバターのサイズを考慮したマージン
    final double avatarRadius = calculateAvatarRadius(screenSize);

    return {
      // 北：上端から一定距離、水平中央
      "north": Offset(
        startX + availableWidth / 2 - avatarRadius,
        startY + avatarRadius * 3,
      ),

      // 南：下端から一定距離、水平中央
      "south": Offset(
        startX + availableWidth / 2 - avatarRadius,
        startY + availableHeight - avatarRadius - (avatarRadius * 9),
      ),

      // 東：右端から一定距離、垂直中央
      "east": Offset(
        startX + availableWidth - avatarRadius - (avatarRadius * 2),
        startY + availableHeight / 2 - avatarRadius * 3.5,
      ),

      // 西：左端から一定距離、垂直中央
      "west": Offset(
        startX + avatarRadius,
        startY + availableHeight / 2 - avatarRadius * 3.5,
      ),
    };
  }

  /// アバターのサイズを画面サイズに応じて計算
  static double calculateAvatarRadius(Size screenSize) {
    final bool isTablet = screenSize.width > 600;
    final bool isSmallScreen = screenSize.width < 375; // iPhone SE等

    if (isTablet) {
      return 60.0;
    } else if (isSmallScreen) {
      return 35.0;
    } else {
      return 45.0;
    }
  }
}
