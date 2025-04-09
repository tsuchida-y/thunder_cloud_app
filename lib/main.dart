import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MapTestScreen(),
    );
  }
}

class MapTestScreen extends StatelessWidget {
  const MapTestScreen({super.key});

  static const LatLng tokyoStation = LatLng(35.681236, 139.7671248);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Map Test'),
      ),
      body: const GoogleMap(
        initialCameraPosition: CameraPosition(
          target: tokyoStation,
          zoom: 15.0,
        ),
      ),
    );
  }
}