import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Article du panier (copie des infos utiles : le panier reste lisible hors ligne)
class CartItem {
  final String productId;
  final String? variantId;
  final String name;
  final String? variantLabel;
  final String? photo;
  final int price;
  final String shopId;
  final String shopName;
  int qty;
  CartItem({required this.productId, this.variantId, required this.name, this.variantLabel, this.photo, required this.price, required this.shopId, required this.shopName, this.qty = 1});

  String get key => '$productId:${variantId ?? ''}';
  Map<String, dynamic> toJson() => {
    'productId': productId, 'variantId': variantId, 'name': name, 'variantLabel': variantLabel, 'photo': photo,
    'price': price, 'shopId': shopId, 'shopName': shopName, 'qty': qty,
  };
  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
    productId: j['productId'], variantId: j['variantId'], name: j['name'], variantLabel: j['variantLabel'], photo: j['photo'],
    price: (j['price'] as num).toInt(), shopId: j['shopId'], shopName: j['shopName'], qty: (j['qty'] as num).toInt(),
  );
}

/// Panier : accessible sans compte, gardé sur le téléphone ; la connexion est demandée à la commande
class Cart extends ChangeNotifier {
  Cart._();
  static final instance = Cart._();
  final List<CartItem> items = [];

  int get count => items.fold(0, (t, i) => t + i.qty);
  int get total => items.fold(0, (t, i) => t + i.qty * i.price);

  /// Articles groupés par boutique (une livraison LETO par boutique)
  Map<String, List<CartItem>> get byShop {
    final m = <String, List<CartItem>>{};
    for (final i in items) {
      m.putIfAbsent(i.shopId, () => []).add(i);
    }
    return m;
  }

  Future<void> load() async {
    final raw = (await SharedPreferences.getInstance()).getString('cart');
    if (raw == null) return;
    try {
      items
        ..clear()
        ..addAll((jsonDecode(raw) as List).map((e) => CartItem.fromJson(Map<String, dynamic>.from(e))));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _save() async {
    (await SharedPreferences.getInstance()).setString('cart', jsonEncode(items.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  void add(CartItem item) {
    final found = items.where((i) => i.key == item.key).firstOrNull;
    if (found != null) {
      found.qty += item.qty;
    } else {
      items.add(item);
    }
    _save();
  }

  void setQty(CartItem item, int qty) {
    if (qty <= 0) {
      items.remove(item);
    } else {
      item.qty = qty;
    }
    _save();
  }

  void clear() {
    items.clear();
    _save();
  }
}
