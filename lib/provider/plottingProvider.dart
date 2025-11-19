import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:osm_google_plotting/model/geoAreasCalculateFarm.dart';

class GeoPlottingProvider extends ChangeNotifier {
  GeoPlottingProvider() : super() {}

  GeoAreasCalculateFarm? farmData;

  LatLng? latLng;
  Set<Polygon> polygons = {};

  List<LatLng> coordinates = [];
  Set<Marker> markers = {};

  _myPolygon() {
    polygons.add(
      Polygon(
        polygonId: PolygonId('test'),
        strokeWidth: 2,
        consumeTapEvents: true,
        geodesic: true,
        fillColor: Colors.orange.withOpacity(0.3),
        points: coordinates,
        strokeColor: Colors.orange,
      ),
    );
  }

  _setMarkers() {
    for (var a in coordinates.indexed) {
      markers.add(
        Marker(
          icon: BitmapDescriptor.defaultMarkerWithHue(
            a.$1 == 0
                ? BitmapDescriptor.hueGreen
                : a.$1 == coordinates.length - 1
                ? BitmapDescriptor.hueRed
                : BitmapDescriptor.hueOrange,
          ),
          markerId: MarkerId(a.$1.toString()),
          position: LatLng(a.$2.latitude, a.$2.longitude),
          infoWindow: InfoWindow(
            anchor: Offset(0.7, 0.01),
            snippet: 'lat: ${a.$2.latitude}, lng: ${a.$2.longitude}',
            title: latLng != null
                ? '${a.$1 == 0
                      ? "Start"
                      : a.$1 == coordinates.length - 1
                      ? 'End'
                      : 'Intermediate ${a.$1}'}   '
                : null,
          ),
        ),
      );
    }
  }

  resetMap() {
    markers.clear();
    polygons.clear();
    coordinates.clear();
    notifyListeners();
  }

  undoOnPressed() {
    markers.remove(markers.last);
    coordinates.removeAt(coordinates.length - 1);
    _setMarkersNadPolygons();
    notifyListeners();
  }

  endDisplayer(int length) {
    return length >= 3 ? true : false;
  }

  onTapMap(LatLng data) {
    coordinates.add(data);
    _setMarkersNadPolygons(latLng: data);
    notifyListeners();
  }

  bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    int intersectCount = 0;
    for (int j = 0; j < polygon.length - 1; j++) {
      LatLng vertex1 = polygon[j];
      LatLng vertex2 = polygon[j + 1];

      if (((vertex1.latitude > point.latitude) !=
              (vertex2.latitude > point.latitude)) &&
          (point.longitude <
              (vertex2.longitude - vertex1.longitude) *
                      (point.latitude - vertex1.latitude) /
                      (vertex2.latitude - vertex1.latitude) +
                  vertex1.longitude)) {
        intersectCount++;
      }
    }
    LatLng vertex1 = polygon[polygon.length - 1];
    LatLng vertex2 = polygon[0];
    if (((vertex1.latitude > point.latitude) !=
            (vertex2.latitude > point.latitude)) &&
        (point.longitude <
            (vertex2.longitude - vertex1.longitude) *
                    (point.latitude - vertex1.latitude) /
                    (vertex2.latitude - vertex1.latitude) +
                vertex1.longitude)) {
      intersectCount++;
    }

    return (intersectCount % 2) == 1; // Odd number of intersections = inside
  }

  _setMarkersNadPolygons({LatLng? latLng}) async {
    await _myPolygon();
    await _setMarkers();
  }

  addAreaItems(String acre, String hectare, String squareMeter) async {
    farmData = GeoAreasCalculateFarm(acre, hectare, squareMeter);
    notifyListeners();
  }

  calculate() {
    var lat = coordinates[0].latitude;
    var lng = coordinates[0].longitude;

    var intText = "";

    for (var j = coordinates.length - 2; j >= 1; j--) {
      lat = coordinates[j].latitude;
      lng = coordinates[j].longitude;
      intText = "$intText $lat,$lng";
    }

    lat = coordinates[coordinates.length - 1].latitude;
    lng = coordinates[coordinates.length - 1].longitude;

    var radius = 6378137;
    var diameter = radius * 2;

    var circumference = diameter * pi;

    List<double> listY = [];
    List<double> listX = [];
    List<double> listArea = [];

    var latitudeRef = coordinates[0].latitude;
    var longitudeRef = coordinates[0].longitude;

    for (var i = 1; i < coordinates.length; i++) {
      var latitude = coordinates[i].latitude;
      var longitude = coordinates[i].longitude;

      var value = (latitude - latitudeRef) * circumference / 360.0;

      var vY = value;

      listY.add(vY);

      var valueX =
          (longitude - longitudeRef) *
          circumference *
          cos(0.017453292519943295769236907684886 * (latitude)) /
          360.0;

      var vX = valueX;
      listX.add(vX);
    }
    for (var j = 1; j < listX.length; j++) {
      var x1 = listX[j - 1];
      var y1 = listY[j - 1];

      var x2 = listX[j];
      var y2 = listY[j];

      var areaValue = ((y1 * x2) - (x1 * y2)) / 2;

      var area = areaValue;

      listArea.add(area);
    }

    // sum areas of all triangle segments
    var areasSum = 0.0;
    for (var i = 0; i < listArea.length; i++) {
      var areaCal = listArea[i];
      areasSum = areasSum + areaCal;
    }
    var meterSquare = areasSum;
    areasSum = (meterSquare * 0.000247104393);

    areasSum = areasSum.abs();

    num squareFeetArea = (areasSum / 0.00024711);

    var hectorArea = areasSum / 2.4711;

    var acre = areasSum.toStringAsFixed(6);

    addAreaItems(
      acre,
      hectorArea.toStringAsFixed(6),
      squareFeetArea.toStringAsFixed(6),
    );

    notifyListeners();
  }
}

