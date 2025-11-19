import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';

class ConnectivityProvider extends ChangeNotifier {
  bool online = true;

  ConnectivityProvider() {
    Connectivity().onConnectivityChanged.listen((status) {
      online = status != ConnectivityResult.none;
      notifyListeners();
    });
  }
}