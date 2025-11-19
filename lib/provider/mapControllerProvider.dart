import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../model/cachedSnapShot.dart';

class MapControllerProvider extends ChangeNotifier {
  //Location
  Position? currentPosition;
  StreamSubscription<Position>? _sub;

  GoogleMapController? controller;
  Uint8List? overlayBytes;
  CachedSnapshot? overlayMeta;

  MapType mapType = MapType.normal;
  bool trafficEnabled = false;
  bool buildingsEnabled = true;
  bool indoorViewEnabled = true;

  //Map Cache
  List<CachedSnapshot> cache = [];
  late File manifestFile;
  late Directory storage;

  bool loading = false;

  MapControllerProvider() {
    WidgetsFlutterBinding.ensureInitialized().addPostFrameCallback((
        timeStamp,
        ) async {
      _initLocation();
      _initMapCache();
    });
  }

  Future<void> _initLocation() async {
    loading = true;
    notifyListeners();
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Fluttertoast.showToast(msg: "Location services are disabled.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        Fluttertoast.showToast(msg: "Location permission denied.");
        return;
      }

      currentPosition = await Geolocator.getCurrentPosition();
      notifyListeners();

      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5,
        ),
      ).listen((pos) {
        currentPosition = pos;
        notifyListeners();
      });
    } catch (e) {
      Fluttertoast.showToast(msg: "Location error: $e");
    }
    loading = false;
    notifyListeners();
  }

  Future<void> _initMapCache() async {
    storage = await getApplicationDocumentsDirectory();
    manifestFile = File("${storage.path}/map_cache.json");

    if (await manifestFile.exists()) {
      final list = jsonDecode(await manifestFile.readAsString());
      cache = (list as List)
          .map((e) => CachedSnapshot.fromJson(e))
          .toList();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> saveSnapshot({
    required Uint8List bytes,
    required LatLng ne,
    required LatLng sw,
  }) async {
    final id = const Uuid().v4();
    final file = File("${storage.path}/snap_$id.png");
    await file.writeAsBytes(bytes);

    cache.add(CachedSnapshot(id: id, path: file.path, ne: ne, sw: sw));

    await manifestFile.writeAsString(jsonEncode(
      cache.map((e) => e.toJson()).toList(),
    ));

    notifyListeners();
  }

  CachedSnapshot? find(LatLng p) {
    try {
      return cache.firstWhere((c) => c.contains(p));
    } catch (_) {
      return null;
    }
  }

  void setController(GoogleMapController c) {
    controller = c;
    notifyListeners();
  }

  void showOverlay(CachedSnapshot meta, Uint8List bytes) {
    overlayMeta = meta;
    overlayBytes = bytes;
    notifyListeners();
  }

  void hideOverlay() {
    overlayBytes = null;
    overlayMeta = null;
    notifyListeners();
  }

  // NEW: setters for map options
  void setMapType(MapType type) {
    mapType = type;
    notifyListeners();
  }

  void toggleTraffic() {
    trafficEnabled = !trafficEnabled;
    notifyListeners();
  }

  void toggleBuildings() {
    buildingsEnabled = !buildingsEnabled;
    notifyListeners();
  }

  void toggleIndoor() {
    indoorViewEnabled = !indoorViewEnabled;
    notifyListeners();
  }
}