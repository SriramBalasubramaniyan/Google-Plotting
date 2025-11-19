import 'dart:io';
import 'package:flutter/material.dart';
import 'package:osm_google_plotting/provider/connectiveProvider.dart';
import 'package:osm_google_plotting/provider/mapControllerProvider.dart';
import 'package:osm_google_plotting/widget/customColumn.dart';
import 'package:osm_google_plotting/widget/customFilledButton.dart';
import 'package:osm_google_plotting/widget/optionButton.dart';
import 'package:osm_google_plotting/widget/customButton.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geocoding/geocoding.dart';
import 'package:osm_google_plotting/model/geoAreasCalculateFarm.dart';
import 'package:osm_google_plotting/model/plottingData.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _goToCurrentLocation(BuildContext context) async {
    final mapCtrl = context.read<MapControllerProvider>();
    final loc = mapCtrl.currentPosition;

    if (loc == null) {
      Fluttertoast.showToast(msg: "Current location not available yet.");
      return;
    }

    final pos = LatLng(loc.latitude, loc.longitude);
    if (mapCtrl.controller != null) {
      await mapCtrl.controller!.animateCamera(
        CameraUpdate.newLatLngZoom(pos, 16),
      );
    }
  }

  Future<void> _searchAndMove(BuildContext context) async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final locations = await locationFromAddress(query);
      if (locations.isEmpty) {
        Fluttertoast.showToast(msg: "Location not found.");
        setState(() => _isSearching = false);
        return;
      }

      final first = locations.first;
      final target = LatLng(first.latitude, first.longitude);
      final mapCtrl = context.read<MapControllerProvider>();

      if (mapCtrl.controller != null) {
        await mapCtrl.controller!.animateCamera(
          CameraUpdate.newLatLngZoom(target, 15),
        );
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Search failed: $e");
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _showMapOptionsSheet(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) {
        return Consumer<MapControllerProvider>(
          builder: (ctx, ctrl, _) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [_buildMapTypeButtons(context, ctrl)],
                  ),
                  const Divider(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [_buildToggleButtons(context, ctrl)],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMapTypeButtons(
    BuildContext context,
    MapControllerProvider ctrl,
  ) {
    final mapCtrl = context.read<MapControllerProvider>();

    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        OptionButton(
          label: "Normal",
          selected: ctrl.mapType == MapType.normal,
          onTap: () => mapCtrl.setMapType(MapType.normal),
        ),
        OptionButton(
          label: "Satellite",
          selected: ctrl.mapType == MapType.satellite,
          onTap: () => mapCtrl.setMapType(MapType.satellite),
        ),
        OptionButton(
          label: "Terrain",
          selected: ctrl.mapType == MapType.terrain,
          onTap: () => mapCtrl.setMapType(MapType.terrain),
        ),
        OptionButton(
          label: "Hybrid",
          selected: ctrl.mapType == MapType.hybrid,
          onTap: () => mapCtrl.setMapType(MapType.hybrid),
        ),
      ],
    );
  }

  Widget _buildToggleButtons(BuildContext context, MapControllerProvider ctrl) {
    final mapCtrl = context.read<MapControllerProvider>();

    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        OptionButton(
          label: "Traffic",
          selected: ctrl.trafficEnabled,
          onTap: mapCtrl.toggleTraffic,
        ),
        OptionButton(
          label: "3D Buildings",
          selected: ctrl.buildingsEnabled,
          onTap: mapCtrl.toggleBuildings,
        ),
        OptionButton(
          label: "Indoor View",
          selected: ctrl.indoorViewEnabled,
          onTap: mapCtrl.toggleIndoor,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final online = context.watch<ConnectivityProvider>().online;
    final ctrl = context.watch<MapControllerProvider>();

    return Scaffold(
      floatingActionButton: Selector(
        selector: (context, MapControllerProvider p) => p.coordinates,
        shouldRebuild: (p, n) => true,
        builder: (context, v, child) {
          return v.isNotEmpty ? ButtonsRowWidget(geo: ctrl) : SizedBox();
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Selector(
        shouldRebuild: (p, n) => true,
        selector: (context, MapControllerProvider p) => p.isLoading,
        builder: (context, isLoading, child) {
          return isLoading ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              backgroundColor: Colors.grey.shade300,
              strokeWidth: 1.7,
              color: Colors.green,
            ),
          ) : Stack(
            children: [
              Selector(
                shouldRebuild: (previous, next) => true,
                selector: (context, MapControllerProvider p) => p.polygons,
                builder: (context, polygon, child) {
                  return GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                              ctrl.currentPosition!.latitude,
                              ctrl.currentPosition!.longitude,
                            ),
                      zoom: 12,
                    ),
                    onMapCreated: (c) =>
                        context.read<MapControllerProvider>().setController(c),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: false,
                    compassEnabled: true,
                    polygons: polygon,
                    mapType: ctrl.mapType,
                    trafficEnabled: ctrl.trafficEnabled,
                    buildingsEnabled: ctrl.buildingsEnabled,
                    indoorViewEnabled: ctrl.indoorViewEnabled,
                    onCameraIdle: () async {
                      if (!online) return;

                      final controller = ctrl.controller;
                      if (controller == null) return;

                      final bounds = await controller.getVisibleRegion();
                      final bytes = await controller.takeSnapshot();
                      if (bytes == null) return;

                      await context.read<MapControllerProvider>().saveSnapshot(
                        bytes: bytes,
                        ne: bounds.northeast,
                        sw: bounds.southwest,
                      );
                    },
                    onTap: (pos) async {
                      ctrl.onTapMap(pos);
                      if (online) {
                        // Fluttertoast.showToast(msg: "Lat: ${pos.latitude.toStringAsFixed(7)}, Lng: ${pos.longitude.toStringAsFixed(7)}");
                        return;
                      }

                      final hit = ctrl.find(pos);
                      if (hit == null) {
                        Fluttertoast.showToast(msg: "No cached data here.");
                        return;
                      }

                      final file = File(hit.path);
                      final bytes = await file.readAsBytes();

                      context.read<MapControllerProvider>().showOverlay(
                        hit,
                        bytes,
                      );
                    },
                  );
                },
              ),
              Positioned(
                top: 0,
                left: 10,
                right: 10,
                child: SafeArea(
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: "Search here",
                              border: InputBorder.none,
                            ),
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _searchAndMove(context),
                          ),
                        ),
                        if (_isSearching)
                          const Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: () => _searchAndMove(context),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              Positioned(
                bottom: 10,
                right: 10,
                child: FloatingActionButton(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.green,
                  heroTag: "my_location_btn",
                  mini: true,
                  onPressed: () => _goToCurrentLocation(context),
                  child: const Icon(Icons.my_location),
                ),
              ),

              Positioned(
                top: 90,
                right: 10,
                child: FloatingActionButton(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black54,
                  heroTag: "map_type_btn",
                  mini: true,
                  onPressed: () => _showMapOptionsSheet(context),
                  child: const Icon(Icons.layers),
                ),
              ),

              if (ctrl.overlayBytes != null)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () =>
                        context.read<MapControllerProvider>().hideOverlay(),
                    child: Container(
                      color: Colors.black.withOpacity(0.7),
                      child: Center(
                        child: Image.memory(
                          ctrl.overlayBytes!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class ButtonsRowWidget extends StatelessWidget {
  const ButtonsRowWidget({super.key, required this.geo});

  final MapControllerProvider geo;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 35,
      child: Row(
        children: [
          CustomFilledButton(
            label: 'Reset',
            color: Colors.purple,
            onPressed: geo.resetMap,
          ),
          SizedBox(width: 10),
          CustomFilledButton(
            label: 'Undo',
            color: Colors.orange,
            onPressed: geo.undoOnPressed,
          ),
          SizedBox(width: 10),
          Selector(
            selector: (context, MapControllerProvider p) => p.coordinates,
            builder: (ct, v, child) {
              return geo.endDisplayer(v.length)
                  ? CustomFilledButton(
                label: 'End',
                color: Colors.red,
                onPressed: () async {
                  await geo.calculate();
                  await showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                    builder: (ctx) {
                      return SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              height: 5,
                              margin: EdgeInsets.symmetric(vertical: 5),
                              width: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(
                              width: double.infinity,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "Calculation",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 10),
                                    Row(
                                      children: [
                                        CustomColumn(
                                          label: 'Acre',
                                          value: geo.farmData!.acre,
                                        ),
                                        CustomColumn(
                                          label: 'Hectare',
                                          value: geo.farmData!.hectare,
                                        ),
                                        CustomColumn(
                                          label: 'Square Meter',
                                          value:
                                          geo.farmData!.squareMeters,
                                        ),
                                      ],
                                    ),
                                    Divider(endIndent: 5, indent: 5),
                                    Text(
                                      'Positions',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Flexible(
                                      child: SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: List.generate(
                                            geo.coordinates.length,
                                                (int i) {
                                              LatLng data =
                                              geo.coordinates[i];
                                              return Row(
                                                spacing: 20,
                                                mainAxisAlignment:
                                                MainAxisAlignment
                                                    .center,
                                                children: [
                                                  Align(
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      'Lat : ${data.latitude}',
                                                    ),
                                                  ),
                                                  Align(
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      'Lng : ${data.longitude}',
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Row(
                                    //   mainAxisAlignment:
                                    //   MainAxisAlignment.spaceAround,
                                    //   children: [
                                    //     CustomButton(
                                    //       label: 'Cancel',
                                    //       bgColor: Colors.red,
                                    //       onPressed: () {
                                    //         Navigator.pop(context);
                                    //       },
                                    //     ),
                                    //     CustomButton(
                                    //       label: 'Done',
                                    //       onPressed: () {
                                    //         Navigator.pop(
                                    //           context,
                                    //           PlottingData(
                                    //             farmData: geo.farmData ?? GeoAreasCalculateFarm("", "", ""),
                                    //             listData: geo.coordinates,
                                    //           ),
                                    //         );
                                    //       },
                                    //     ),
                                    //   ],
                                    // ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              )
                  : SizedBox();
            },
          ),
        ],
      ),
    );
  }
}
