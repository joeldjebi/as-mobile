import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'cart.dart';
import 'mode.dart';
import 'screens/home_screen.dart';
import 'screens/seller_shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark, statusBarBrightness: Brightness.light));
  await Future.wait([Api.instance.restore(), Cart.instance.load(), AppMode.instance.load()]);
  runApp(const AdjameSmartApp());
}

class AdjameSmartApp extends StatelessWidget {
  const AdjameSmartApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Adjamé-Smart',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    // Une seule app, deux profils : client (sans compte jusqu'à la commande) ou boutique (dernier profil retenu)
    home: ListenableBuilder(
      listenable: Listenable.merge([AppMode.instance, Api.instance]),
      builder: (_, _) => AppMode.instance.seller && Api.instance.loggedIn ? const SellerShell() : const HomeScreen(),
    ),
  );
}
