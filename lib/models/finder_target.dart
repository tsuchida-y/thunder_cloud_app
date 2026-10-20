import '../utils/sky_geometry.dart';
import 'sky_cloud.dart';

/// 方角ガイドで案内する雲（ホームの雲、または通知から）
class FinderTarget {
  /// 雲の ID（「見えた」「見えなかった」の答えに使う）。古い通知などで分からなければ null
  final String? cloudId;

  /// 本当の北から時計回りの角度
  final double bearingDeg;
  final double distanceKm;
  final double elevationDeg;
  final double fists;

  /// どこから開いたか（reports に残す）
  final FinderSource source;

  const FinderTarget({
    required this.cloudId,
    required this.bearingDeg,
    required this.distanceKm,
    required this.elevationDeg,
    required this.fists,
    required this.source,
  });

  factory FinderTarget.fromView(CloudView view) => FinderTarget(
        cloudId: view.cloud.id,
        bearingDeg: view.bearingDeg,
        distanceKm: view.distanceKm,
        elevationDeg: SkyGeometry.elevationDeg(view.distanceKm),
        fists: view.fists,
        source: FinderSource.home,
      );

  /// 通知のデータ（functions/modules/watch/cloud_watch_service.js の _send）から作る
  static FinderTarget? fromNotification(Map<String, dynamic> data) {
    if (data['type'] != 'cloud_appeared') return null;
    final bearing = double.tryParse('${data['bearingDeg']}');
    final distance = double.tryParse('${data['distanceKm']}');
    if (bearing == null || distance == null) return null;
    final elevation = double.tryParse('${data['elevationDeg']}') ?? SkyGeometry.elevationDeg(distance);
    return FinderTarget(
      cloudId: data['cloudId'] as String?,
      bearingDeg: bearing,
      distanceKm: distance,
      elevationDeg: elevation,
      fists: double.tryParse('${data['fists']}') ?? SkyGeometry.fistsFromElevation(elevation),
      source: FinderSource.notification,
    );
  }

  String get directionName => SkyGeometry.directionName(bearingDeg);
  String get fistsLabel => SkyGeometry.fistsLabel(fists);
}

enum FinderSource { home, notification }
