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
        await req.send().timeout(const Duration(seconds: 25)),
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

  Future<void> _session(Map<String, dynamic> res) async {
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
  Future<List<dynamic>> categories() async =>
      await _request('GET', '/categories') as List<dynamic>;
  Future<List<dynamic>> shops({String? categoryId}) async =>
      await _request(
            'GET',
            '/shops${categoryId == null ? '' : '?categoryId=$categoryId'}',
          )
          as List<dynamic>;
  Future<Map<String, dynamic>> shop(String slug) async =>
      await _request('GET', '/shops/$slug') as Map<String, dynamic>;
  Future<List<String>> markets() async =>
      ((await _request('GET', '/shops/meta'))['markets'] as List)
          .cast<String>();

  // ---------- Produits (client) ----------
  Future<Map<String, dynamic>> home() async =>
      await _request('GET', '/products/home') as Map<String, dynamic>;
  Future<Map<String, dynamic>> searchProducts(
    Map<String, String> params,
  ) async =>
      await _request(
            'GET',
            '/products${params.isEmpty ? '' : '?${Uri(queryParameters: params).query}'}',
          )
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> product(String id) async =>
      await _request('GET', '/products/$id') as Map<String, dynamic>;
  Future<void> reportProduct(String id, String reason) async =>
      _request('POST', '/products/$id/report', {'reason': reason});

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
