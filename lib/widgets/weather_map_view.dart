import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

///GoogleMapを背景として表示するウィジェット
class WeatherMapView extends StatelessWidget {
  final LatLng? currentLocation;

  const WeatherMapView({
    super.key,
    required this.currentLocation,
  });

  @override
  Widget build(BuildContext context) {
    if (currentLocation == null) {
      return const SizedBox.shrink();
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: currentLocation!,
        zoom: 12.0,
      ),
      //入道雲情報が主目的のため、現在地マーカ(青いやつ)を表示するだけで他の機能は無効化
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      scrollGesturesEnabled: false,
      zoomControlsEnabled: false,
      zoomGesturesEnabled: false,
      tiltGesturesEnabled: false,
      rotateGesturesEnabled: false,
    );
  }
}