import 'package:adjame_smart/screens/auth_screen.dart';
import 'package:adjame_smart/screens/shop_form_screen.dart';
import 'package:adjame_smart/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget child, {double scale = 1}) => MaterialApp(
  theme: buildTheme(),
  home: MediaQuery(data: MediaQueryData(size: const Size(390, 844), textScaler: TextScaler.linear(scale)), child: child),
);

void main() {
  testWidgets('Connexion puis création de compte', (t) async {
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    await t.pumpWidget(app(const AuthScreen()));
    expect(find.text('Adjamé-Smart'), findsOneWidget);
    expect(find.text('Nom complet'), findsNothing);
    await t.tap(find.text('Créer un compte'));
    await t.pump();
    expect(find.text('Nom complet'), findsOneWidget);
    expect(find.text('Créer mon compte'), findsOneWidget);
  });

  testWidgets('Dossier de boutique en vérification (grands caractères)', (t) async {
    t.view.physicalSize = const Size(390 * 3, 2400 * 3);
    t.view.devicePixelRatio = 3;
    await t.pumpWidget(app(const ShopFormScreen(shop: {
      'id': 's1', 'name': 'Awa Pagnes', 'status': 'PENDING', 'type': 'BOUTIQUE', 'market': 'Forum des marchés', 'location': 'Allée C',
      'lat': 5.355, 'lng': -4.022, 'categoryIds': [], 'required': [],
    }), scale: 1.3));
    await t.pump();
    expect(find.text('Dossier en cours de vérification'), findsOneWidget);
    expect(find.text('Envoyer le dossier'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('Nouvelle boutique : brouillon et envoi', (t) async {
    t.view.physicalSize = const Size(390 * 3, 2400 * 3);
    t.view.devicePixelRatio = 3;
    await t.pumpWidget(app(const ShopFormScreen()));
    await t.pump();
    expect(find.text('Ouvrez votre boutique'), findsOneWidget);
    expect(find.text('Envoyer le dossier'), findsOneWidget);
    expect(find.text('Pièce (recto)'), findsOneWidget);
  });
}
