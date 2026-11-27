import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Adresse de l'API : --dart-define=API_URL=… ; sinon production en release, machine locale en debug
const _defined = String.fromEnvironment('API_URL');
final String apiUrl = _defined.isNotEmpty
    ? _defined
    : kReleaseMode
    ? 'https://api.as.performx.online'
    : Platform.isAndroid
    ? 'http://10.0.2.2:3100'
    : 'http://127.0.0.1:3100';

String photoUrl(String path) => path.startsWith('http') ? path : '$apiUrl$path';

/// Miniature servie par l'API (WebP à la largeur demandée : 240, 480, 800 ou 1200)
String thumbUrl(String path, int width) {
  if (!path.startsWith('/uploads/')) return photoUrl(path);
  final w = width <= 240 ? 240 : width <= 480 ? 480 : width <= 800 ? 800 : 1200;
  return '$apiUrl$path?w=$w';
}

/// Erreur à montrer telle quelle (message clair en français)
class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

const _generic = 'Une erreur est survenue. Réessayez dans un instant.';
const _offline =
    'Impossible de joindre Adjamé-Smart. Vérifiez votre connexion.';

/// Session : écoutable (l'onglet Compte se met à jour à la connexion / déconnexion)
class Api extends ChangeNotifier {
  Api._();
  static final instance = Api._();

  String? _token;
  Map<String, dynamic>? user;
  /// Connexion réutilisée (keep-alive) : chaque appel évite une nouvelle poignée de main
  final _http = http.Client();
  /// Réponses récentes du catalogue (retour en arrière instantané)
  final _cache = <String, (DateTime, dynamic)>{};
  String? get token => _token;
  bool get loggedIn => _token != null && user != null;

  Future<void> restore() async {
    final p = await SharedPreferences.getInstance();
    _token = p.getString('token');
    if (_token == null) return;
    try {
      user = await _request('GET', '/auth/me');
    } catch (_) {
      _token = null;
      user = null;
    }
  }

  Future<dynamic> _request(String method, String path, [Object? body]) async {
    http.Response res;
    try {
      final req = http.Request(method, Uri.parse('$apiUrl$path'))
        ..headers.addAll({
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        });
      if (body != null) req.body = jsonEncode(body);
      res = await http.Response.fromStream(
        await _http.send(req).timeout(const Duration(seconds: 25)),
      );
    } catch (_) {
      throw ApiException(_offline);
    }
    final data = res.body.isEmpty
        ? null
        : jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    if (res.statusCode == 401 && _token != null && path != '/auth/login') {
      await logout();
    }
    if (res.statusCode >= 500) throw ApiException(_generic);
    final m = data is Map ? data['message'] : null;
    throw ApiException(
      m is List ? m.join('\n') : (m is String && m.isNotEmpty ? m : _generic),
    );
  }

  /// GET mis en cache [ttl] (le prix de gros dépend du compte : cache vidé à la connexion)
  Future<dynamic> _cached(String path, Duration ttl) async {
    final hit = _cache[path];
    if (hit != null && DateTime.now().difference(hit.$1) < ttl) return hit.$2;
    final data = await _request('GET', path);
    _cache[path] = (DateTime.now(), data);
    return data;
  }

  /// Réponse en cache sans appel réseau (affichage immédiat)
  dynamic peek(String path) => _cache[path]?.$2;

  Future<void> _session(Map<String, dynamic> res) async {
    _cache.clear();
    _token = res['token'] as String;
    user = res['user'] as Map<String, dynamic>;
    (await SharedPreferences.getInstance()).setString('token', _token!);
    notifyListeners();
  }

  Future<void> login(String phone, String password) async => _session(
    await _request('POST', '/auth/login', {
      'phone': phone,
      'password': password,
    }),
  );
  Future<void> register(String name, String phone, String password) async =>
      _session(
        await _request('POST', '/auth/register', {
          'name': name,
          'phone': phone,
          'password': password,
        }),
      );
  Future<void> refreshMe() async {
    user = await _request('GET', '/auth/me');
    notifyListeners();
  }
  Future<void> logout() async {
    _token = null;
    user = null;
    _cache.clear();
    (await SharedPreferences.getInstance()).remove('token');
    notifyListeners();
  }

  Future<void> addAddress(Map<String, dynamic> a) async =>
      user = await _request('POST', '/auth/me/addresses', a);
  Future<void> removeAddress(String id) async =>
      user = await _request('DELETE', '/auth/me/addresses/$id');
  Future<void> requestReseller(Map<String, dynamic> body) async =>
      user = await _request('POST', '/auth/me/reseller', body);

  // ---------- Catalogue ----------
  String _qs(Map<String, String> p) => p.isEmpty ? '' : '?${Uri(queryParameters: p).query}';

  /// Rayons (arbre : chaque rayon a ses sous-rayons dans « children »)
  Future<List<dynamic>> categories() async => await _cached('/categories', const Duration(minutes: 10)) as List<dynamic>;
  /// Annuaire des boutiques : q, market, type, categoryId, sort (name|new|popular), page
  Future<Map<String, dynamic>> shops(Map<String, String> params) async => await _request('GET', '/shops${_qs(params)}') as Map<String, dynamic>;
  Future<Map<String, dynamic>> shop(String slug) async => await _cached('/shops/$slug', const Duration(minutes: 1)) as Map<String, dynamic>;
  Future<Map<String, dynamic>> shopsMeta() async => await _cached('/shops/meta', const Duration(minutes: 5)) as Map<String, dynamic>;
  Future<List<String>> markets() async => ((await shopsMeta())['markets'] as List).cast<String>();

  // ---------- Produits (client) ----------
  Future<Map<String, dynamic>> home({bool fresh = false}) async {
    if (fresh) _cache.remove('/products/home');
    return await _cached('/products/home', const Duration(seconds: 45)) as Map<String, dynamic>;
  }
  Future<Map<String, dynamic>> searchProducts(Map<String, String> params) async => await _request('GET', '/products${_qs(params)}') as Map<String, dynamic>;
  Future<Map<String, dynamic>> suggest(String q) async => await _cached('/products/suggest${_qs({'q': q})}', const Duration(minutes: 2)) as Map<String, dynamic>;
  Future<Map<String, dynamic>> product(String id) async => await _request('GET', '/products/$id') as Map<String, dynamic>;
  Future<void> reportProduct(String id, String reason) async => _request('POST', '/products/$id/report', {'reason': reason});

  // ---------- Commandes ----------
  /// Lignes du panier envoyées au serveur (prix et stocks revérifiés côté serveur)
  Future<Map<String, dynamic>> orderQuote(Map<String, dynamic> body) async => await _request('POST', '/orders/quote', body) as Map<String, dynamic>;
  Future<Map<String, dynamic>> checkout(Map<String, dynamic> body) async => await _request('POST', '/orders', body) as Map<String, dynamic>;
  Future<List<dynamic>> myOrders() async => await _request('GET', '/orders/mine') as List<dynamic>;
  Future<Map<String, dynamic>> order(String id) async => await _request('GET', '/orders/$id') as Map<String, dynamic>;
  Future<Map<String, dynamic>> declarePayment(String id, String reference, {String? payerPhone}) async =>
      await _request('POST', '/orders/mine/$id/payment', {'reference': reference, 'payerPhone': ?payerPhone}) as Map<String, dynamic>;
  Future<Map<String, dynamic>> cancelOrder(String id) async => await _request('POST', '/orders/mine/$id/cancel') as Map<String, dynamic>;
  // Boutique
  Future<List<dynamic>> shopOrders(String shopId) async => await _request('GET', '/orders/shop?shopId=$shopId') as List<dynamic>;
  Future<Map<String, dynamic>> shopOrderAction(String id, String action, [String? note]) async =>
      await _request('POST', '/orders/shop/$id/$action', note == null ? null : {'note': note}) as Map<String, dynamic>;

  // ---------- Mes produits (vendeur) ----------
  Future<List<dynamic>> myProducts(String shopId) async =>
      await _request('GET', '/products/mine?shopId=$shopId') as List<dynamic>;
  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> body) async =>
      await _request('POST', '/products', body) as Map<String, dynamic>;
  Future<Map<String, dynamic>> updateProduct(
    String id,
    Map<String, dynamic> body,
  ) async =>
      await _request('PATCH', '/products/mine/$id', body)
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> duplicateProduct(String id) async =>
      await _request('POST', '/products/mine/$id/duplicate')
          as Map<String, dynamic>;
  Future<void> deleteProduct(String id) async =>
      _request('DELETE', '/products/mine/$id');

  // ---------- Ma boutique ----------
  Future<List<dynamic>> myShops() async =>
      await _request('GET', '/shops/mine') as List<dynamic>;
  Future<Map<String, dynamic>> createShop(Map<String, dynamic> body) async =>
      await _request('POST', '/shops', body) as Map<String, dynamic>;
  Future<Map<String, dynamic>> updateShop(
    String id,
    Map<String, dynamic> body,
  ) async =>
      await _request('PATCH', '/shops/mine/$id', body) as Map<String, dynamic>;
  Future<Map<String, dynamic>> submitShop(String id) async =>
      await _request('POST', '/shops/mine/$id/submit') as Map<String, dynamic>;

  /// Envoi d'une photo : publique (/uploads/…) ou pièce d'identité privée (/identity/…)
  Future<String> upload(File file, {bool identity = false}) async {
    try {
      final req =
          http.MultipartRequest(
              'POST',
              Uri.parse('$apiUrl/uploads${identity ? '/identity' : ''}'),
            )
            ..headers['Authorization'] = 'Bearer $_token'
            ..files.add(
              await http.MultipartFile.fromPath(
                'file',
                file.path,
                contentType: MediaType('image', 'jpeg'),
              ),
            );
      final res = await http.Response.fromStream(
        await req.send().timeout(const Duration(seconds: 60)),
      );
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode >= 300) {
        throw ApiException(
          data is Map && data['message'] is String
              ? data['message']
              : 'Envoi de la photo impossible. Réessayez.',
        );
      }
      return data['url'] as String;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(_offline);
    }
  }
}
