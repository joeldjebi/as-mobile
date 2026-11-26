import 'package:flutter/material.dart';

import 'api.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.instance.restore();
  runApp(const AdjameSmartApp());
}

final navigatorKey = GlobalKey<NavigatorState>();

/// Après connexion / déconnexion : on repart de l'écran adapté
void goHome(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => Api.instance.loggedIn ? const HomeScreen() : const AuthScreen()),
    (_) => false,
  );
}

class AdjameSmartApp extends StatelessWidget {
  const AdjameSmartApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Adjamé-Smart',
    debugShowCheckedModeBanner: false,
    navigatorKey: navigatorKey,
    theme: buildTheme(),
    home: Api.instance.loggedIn ? const HomeScreen() : const AuthScreen(),
  );
}
