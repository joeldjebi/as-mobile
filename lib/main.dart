import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'cart.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark, statusBarBrightness: Brightness.light));
  await Future.wait([Api.instance.restore(), Cart.instance.load()]);
  runApp(const AdjameSmartApp());
}

class AdjameSmartApp extends StatelessWidget {
  const AdjameSmartApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Adjamé-Smart',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    // Visiteur bienvenu : boutiques et produits sans compte, connexion au moment de commander
    home: const HomeScreen(),
  );
}
