/// 緯度経度
///
/// v1 では Google マップのパッケージの LatLng を使っていた。v2.0 で地図をやめたので、
/// 同じ名前・同じ使い方の型をここに用意している。
class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  @override
  bool operator ==(Object other) =>
      other is LatLng && other.latitude == latitude && other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'LatLng($latitude, $longitude)';
}
