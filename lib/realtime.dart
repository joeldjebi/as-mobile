import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api.dart';
import 'mode.dart';
import 'order_live.dart';
import 'screens/orders_screen.dart';
import 'theme.dart';

/// Navigation et bandeaux depuis n'importe où (notification touchée, événement temps réel)
final appNavigator = GlobalKey<NavigatorState>();
final appMessenger = GlobalKey<ScaffoldMessengerState>();

/// Temps réel (Socket.IO, même adresse que l'API) : les écrans se mettent à jour seuls.
///
/// Événements reçus :
///  - `order:changed` { id, number, status, deliveryStatus, notice? } : une commande a changé ;
///  - `order:offers` { id, number, notice? } : les propositions des livreurs ont changé.
/// Connecté tant que le compte l'est ; reconnecté à la connexion du compte et au retour au premier plan.
class Realtime with WidgetsBindingObserver {
  Realtime._();
  static final instance = Realtime._();

  io.Socket? _socket;
  String? _token; // jeton de la connexion en cours
  bool _started = false;
  bool _wasConnected = false;

  final _orderChanged = StreamController<Map>.broadcast();
  final _offersChanged = StreamController<Map>.broadcast();
  final _resynced = StreamController<void>.broadcast();

  /// Une commande a changé (commande du client ou commande reçue par une boutique)
  Stream<Map> get orderChanged => _orderChanged.stream;

  /// Les propositions de prix des livreurs ont changé pour une commande
  Stream<Map> get offersChanged => _offersChanged.stream;

  /// Connexion rétablie ou retour au premier plan : des événements ont pu être manqués, tout relire
  Stream<void> get resynced => _resynced.stream;

  /// Notification d'une commande reçue touchée : l'espace boutique ouvre l'onglet Commandes
  final openShopOrders = ValueNotifier<int>(0);

  bool get connected => _socket?.connected ?? false;

  /// Démarrage (une fois, au lancement de l'app)
  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    Api.instance.addListener(_sync);
    await Notices.instance.init();
    _sync();
  }

  /// Connexion / déconnexion selon la session
  void _sync() {
    final token = Api.instance.loggedIn ? Api.instance.token : null;
    if (token == _token && (_socket != null) == (token != null)) return;
    _close();
    if (token == null) {
      OrderLive.instance.end();
      return;
    }
    _token = token;
    final s = io.io(
      apiUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableForceNew()
          .enableReconnection()
          .disableAutoConnect()
          .build(),
    );
    s.onConnect((_) {
      // Reconnexion après une coupure : relire ce qui a pu changer entre-temps
      if (_wasConnected) _resync();
      _wasConnected = true;
    });
    s.on('order:changed', (d) {
      if (d is Map) _onOrder(d);
    });
    s.on('order:offers', (d) {
      if (d is Map) _onOffers(d);
    });
    s.connect();
    _socket = s;
    Notices.instance.askOnce();
  }

  void _close() {
    _socket?.dispose();
    _socket = null;
    _token = null;
    _wasConnected = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !Api.instance.loggedIn) return;
    if (_socket == null || _token != Api.instance.token) {
      _sync();
    } else if (!connected) {
      _socket!.connect();
    }
    _resync();
  }

  /// Retour au premier plan / reconnexion : écrans et suivi hors de l'app remis à jour
  Future<void> _resync() async {
    _resynced.add(null);
    try {
      OrderLive.instance.syncAll(await Api.instance.myOrders());
    } catch (_) {}
  }

  /// Un même compte peut recevoir plusieurs copies d'un événement (client et propriétaire de la boutique) :
  /// `audience` dit à qui s'adresse chacune ('customer', 'shop', 'admin').
  /// Les écrans se rechargent sur n'importe quelle copie ; notifications selon le profil affiché
  /// (client : 'customer' ; boutique : 'shop' ; 'admin' ignoré).
  bool _forProfile(String? audience) =>
      audience == (AppMode.instance.seller ? 'shop' : 'customer');

  Future<void> _onOrder(Map d) async {
    _orderChanged.add(d);
    final id = d['id'] as String?;
    final audience = d['audience'] as String?;
    if (id == null || audience == null || audience == 'admin') return;
    final notice = d['notice'];
    if (audience == 'customer') {
      // Commande du client : suivi hors de l'app (écran verrouillé, Dynamic Island, notification Android),
      // tenu à jour et terminé à la livraison même si l'écran de la commande n'est pas ouvert
      try {
        OrderLive.instance.sync(await Api.instance.order(id));
      } catch (_) {}
    }
    if (notice is Map && _forProfile(audience)) {
      Notices.instance.show(
        notice,
        audience == 'shop' ? 'shop:$id' : 'order:$id',
      );
    }
  }

  void _onOffers(Map d) {
    _offersChanged.add(d);
    final notice = d['notice'];
    final audience = (d['audience'] as String?) ?? 'customer';
    if (notice is Map && d['id'] is String && _forProfile(audience)) {
      Notices.instance.show(notice, 'order:${d['id']}');
    }
  }

  /// Abonnement d'un écran : [onChange] quand une commande change (seulement [orderId] s'il est donné),
  /// quand les propositions changent si [offers], et au retour de la connexion.
  /// Appels rapprochés regroupés. Renvoie la fonction de désabonnement.
  void Function() watch(
    VoidCallback onChange, {
    String? orderId,
    bool orders = true,
    bool offers = false,
  }) {
    Timer? debounce;
    void fire() {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 250), onChange);
    }

    bool concerns(Map d) => orderId == null || d['id'] == orderId;
    final subs = [
      if (orders) orderChanged.where(concerns).listen((_) => fire()),
      if (offers) offersChanged.where(concerns).listen((_) => fire()),
      resynced.listen((_) => fire()),
    ];
    return () {
      debounce?.cancel();
      for (final s in subs) {
        s.cancel();
      }
    };
  }
}

/// Notifications des commandes : bandeau discret dans l'app au premier plan, notification locale sinon.
/// Toucher la notification ouvre la commande concernée.
class Notices {
  Notices._();
  static final instance = Notices._();

  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;
  int _nextId = 7200;

  static const channel = AndroidNotificationChannel(
    'as_orders',
    'Commandes',
    description: 'Paiement, livreur et livraison de vos commandes',
    importance: Importance.high,
  );

  bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Initialisation unique du module de notifications (partagée avec le suivi de livraison)
  Future<void> init() => _ready ??= _init();

  Future<void> _init() async {
    if (!_supported) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) => _open(r.payload),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
      // App lancée en touchant une notification
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        final payload = launch!.notificationResponse?.payload;
        WidgetsBinding.instance.addPostFrameCallback((_) => _open(payload));
      }
    } catch (e) {
      debugPrint('Notifications : $e');
    }
  }

  /// Autorisation demandée une seule fois, après la connexion au compte
  Future<void> askOnce() async {
    if (!_supported) return;
    final p = await SharedPreferences.getInstance();
    if (p.getBool('notif_asked') ?? false) return;
    await p.setBool('notif_asked', true);
    await ask();
  }

  Future<void> ask() async {
    if (!_supported) return;
    await init();
    try {
      if (Platform.isAndroid) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      } else {
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }
    } catch (_) {}
  }

  /// [payload] : `order:<id>` (commande du client) ou `shop:<id>` (commande reçue)
  Future<void> show(Map notice, String payload) async {
    final title = '${notice['title'] ?? ''}'.trim();
    final body = '${notice['body'] ?? ''}'.trim();
    if (title.isEmpty) return;
    final foreground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (foreground) return _banner(title, body, payload);
    if (!_supported) return;
    await init();
    try {
      await _plugin.show(
        id: _nextId++,
        title: title,
        body: body,
        payload: payload,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            category: AndroidNotificationCategory.status,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('Notifications : $e');
    }
  }

  /// Bandeau discret dans l'app (même style que les messages de l'app)
  void _banner(String title, String body, String payload) {
    final m = appMessenger.currentState;
    if (m == null) return;
    m
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Row(
            children: [
              const Icon(
                CupertinoIcons.bell_fill,
                color: AppColors.accent,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.subhead.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (body.isNotEmpty)
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(
                          color: const Color(0xFFD1D1D6),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'Voir',
            textColor: AppColors.accent,
            onPressed: () => _open(payload),
          ),
        ),
      );
  }

  /// Ouvre la commande concernée (client) ou les commandes reçues (boutique)
  Future<void> _open(String? payload) async {
    if (payload == null || !Api.instance.loggedIn) return;
    final i = payload.indexOf(':');
    if (i < 0) return;
    final kind = payload.substring(0, i);
    final id = payload.substring(i + 1);
    final nav = appNavigator.currentState;
    if (nav == null) return;
    if (kind == 'shop') {
      nav.popUntil((r) => r.isFirst);
      if (AppMode.instance.seller) {
        Realtime.instance.openShopOrders.value++;
      } else {
        // L'espace boutique s'affiche à l'image suivante, puis ouvre ses commandes
        await AppMode.instance.setSeller(true);
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => Realtime.instance.openShopOrders.value++,
        );
      }
      return;
    }
    nav.push(CupertinoPageRoute(builder: (_) => OrderScreen(id: id)));
  }
}
