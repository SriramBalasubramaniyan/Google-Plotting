import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:osm_google_plotting/model/geoAreasCalculateFarm.dart';

class PlottingData {
  GeoAreasCalculateFarm farmData;
  List<LatLng> listData;
  String? label;

  PlottingData({
    required this.farmData,
    required this.listData,
    this.label,
  });
}