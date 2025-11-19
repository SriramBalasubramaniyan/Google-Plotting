import 'dart:io';
import 'package:flutter/material.dart';
import 'package:osm_google_plotting/provider/connectiveProvider.dart';
import 'package:osm_google_plotting/provider/mapControllerProvider.dart';
import 'package:osm_google_plotting/widget/optionButton.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geocoding/geocoding.dart';

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      builder: (ctx) {
        return Consumer<MapControllerProvider>(
          builder: (ctx, ctrl, _) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildMapTypeButtons(context, ctrl),
                    ],
                  ),
                  const Divider(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildToggleButtons(context, ctrl),
                    ],
                  ),

                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMapTypeButtons(BuildContext context, MapControllerProvider ctrl) {
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
      body: ctrl.loading ? SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          backgroundColor: Colors.grey.shade300,
          strokeWidth: 1.7,
          color: Colors.green,
        ),
      ) : Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(ctrl.currentPosition!.latitude , ctrl.currentPosition!.longitude),
              zoom: 12,
            ),
            onMapCreated: (c) =>
                context.read<MapControllerProvider>().setController(c),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
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
              if (online) {
                Fluttertoast.showToast(
                  msg:
                      "Lat: ${pos.latitude.toStringAsFixed(7)}, Lng: ${pos.longitude.toStringAsFixed(7)}",
                );
                return;
              }

              final hit = ctrl.find(pos);
              if (hit == null) {
                Fluttertoast.showToast(msg: "No cached data here.");
                return;
              }

              final file = File(hit.path);
              final bytes = await file.readAsBytes();

              context.read<MapControllerProvider>().showOverlay(hit, bytes);
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
      ),
    );
  }
}
