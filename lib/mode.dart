import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Profil affiché : client (acheter) ou boutique (vendre). Une seule app, le dernier profil choisi est retenu.
class AppMode extends ChangeNotifier {
  AppMode._();
  static final instance = AppMode._();

  bool seller = false;

  Future<void> load() async => seller = (await SharedPreferences.getInstance()).getString('mode') == 'seller';

  Future<void> setSeller(bool value) async {
    seller = value;
    (await SharedPreferences.getInstance()).setString('mode', value ? 'seller' : 'client');
    notifyListeners();
  }
}
