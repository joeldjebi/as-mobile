import 'package:adjame_smart/cart.dart';
import 'package:adjame_smart/screens/account_screen.dart';
import 'package:adjame_smart/screens/auth_screen.dart';
import 'package:adjame_smart/screens/cart_screen.dart';
import 'package:adjame_smart/screens/orders_screen.dart';
import 'package:adjame_smart/screens/shop_form_screen.dart';
import 'package:adjame_smart/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(Widget child, {double scale = 1}) => MaterialApp(
  theme: buildTheme(),
  home: MediaQuery(data: MediaQueryData(size: const Size(390, 844), textScaler: TextScaler.linear(scale)), child: child),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Connexion puis création de compte', (t) async {
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    await t.pumpWidget(app(const AuthScreen(reason: 'Connectez-vous pour finaliser votre commande')));
    expect(find.text('Bon retour parmi nous'), findsOneWidget);
    expect(find.text('Connectez-vous pour finaliser votre commande'), findsOneWidget);
    expect(find.text('Nom et prénom'), findsNothing);
    await t.tap(find.text('Inscription'));
    await t.pumpAndSettle();
    expect(find.text('Nom et prénom'), findsOneWidget);
    expect(find.text('Créer mon compte'), findsOneWidget);
  });

  testWidgets('Compte visiteur : invitation à se connecter', (t) async {
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    await t.pumpWidget(app(const Scaffold(body: AccountScreen())));
    expect(find.text('Se connecter ou créer un compte'), findsOneWidget);
    expect(find.text('Ouvrir ma boutique'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('Panier sans compte : groupé par boutique, connexion à la commande', (t) async {
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    Cart.instance.items.clear();
    Cart.instance.add(CartItem(productId: 'p1', name: 'Pagne wax 6 yards', price: 12500, shopId: 's1', shopName: 'Awa Pagnes', qty: 2, prepayPercent: 30));
    Cart.instance.add(CartItem(productId: 'p2', variantId: 'v1', variantLabel: 'Taille M', name: 'Robe', price: 8000, shopId: 's2', shopName: 'Mode Adjamé'));
    await t.pumpWidget(app(CartScreen(onBrowse: () {})));
    await t.pump();
    expect(find.text('AWA PAGNES · 2 ARTICLES'), findsOneWidget);
    expect(find.text('MODE ADJAMÉ · 1 ARTICLE'), findsOneWidget);
    expect(find.text('Articles (3)'), findsOneWidget);
    expect(find.text('Livraisons (2)'), findsOneWidget);
    // Acompte 30 % sur 25 000 F (7 500 F) + robe payée en entier (8 000 F) : 15 500 F maintenant, 17 500 F à la livraison
    expect(Cart.instance.dueNow, 15500);
    expect(Cart.instance.dueOnDelivery, 17500);
    expect(find.text('Acompte 30 % à la commande'), findsOneWidget);
    expect(find.text('Reste à la livraison'), findsOneWidget);
    await t.tap(find.text('Commander'));
    await t.pumpAndSettle();
    expect(find.text('Connectez-vous pour finaliser votre commande'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('Commande enregistrée : une commande par boutique à payer', (t) async {
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    await t.pumpWidget(app(const CheckoutDoneScreen(orders: [
      {'id': 'o1', 'number': 'AS-1004', 'shopName': 'Awa Pagnes', 'dueNow': 10200},
      {'id': 'o2', 'number': 'AS-1005', 'shopName': 'Phone 24', 'dueNow': 8000},
    ])));
    expect(find.text('Commande enregistrée'), findsOneWidget);
    expect(find.text('AS-1004 · Awa Pagnes'), findsOneWidget);
    expect(find.text('Voir mes commandes'), findsOneWidget);
    expect(t.takeException(), isNull);
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
