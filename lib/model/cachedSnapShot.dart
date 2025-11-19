import 'package:google_maps_flutter/google_maps_flutter.dart';

class CachedSnapshot {
  final String id;
  final String path;
  final LatLng ne;
  final LatLng sw;

  CachedSnapshot({
    required this.id,
    required this.path,
    required this.ne,
    required this.sw,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'ne': {'lat': ne.latitude, 'lng': ne.longitude},
    'sw': {'lat': sw.latitude, 'lng': sw.longitude},
  };

  factory CachedSnapshot.fromJson(Map<String, dynamic> map) {
    return CachedSnapshot(
      id: map['id'],
      path: map['path'],
      ne: LatLng(map['ne']['lat'], map['ne']['lng']),
      sw: LatLng(map['sw']['lat'], map['sw']['lng']),
    );
  }

  bool contains(LatLng p) {
    return (p.latitude <= ne.latitude &&
        p.latitude >= sw.latitude &&
        p.longitude >= sw.longitude &&
        p.longitude <= ne.longitude);
  }
}