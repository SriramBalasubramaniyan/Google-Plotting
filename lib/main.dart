import 'package:flutter/material.dart';
import 'package:osm_google_plotting/provider/connectiveProvider.dart';
import 'package:osm_google_plotting/provider/mapControllerProvider.dart';
import 'package:osm_google_plotting/provider/plottingProvider.dart';
import 'package:osm_google_plotting/view/mapPage.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => MapControllerProvider()),
        ChangeNotifierProvider(create: (_) => GeoPlottingProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const MapPage(),
    );
  }
}