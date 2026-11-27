import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:live_activities/live_activities.dart';

import 'realtime.dart';

/// Groupe d'apps partagé avec l'extension Live Activity (ios/AsLive)
const kAppGroup = 'group.ci.adjamesmart.adjameSmart';

/// Suivi de la livraison hors de l'app pendant qu'un livreur VITE apporte la commande :
/// - iPhone : Live Activity (écran verrouillé et Dynamic Island), compte à rebours de l'arrivée ;
/// - Android : notification fixe avec avancement.
/// Mise à jour par l'écran de la commande, le suivi en direct et les événements temps réel (lib/realtime.dart).
class OrderLive {
  OrderLive._();
  static final instance = OrderLive._();

  final _ios = LiveActivities();
  final _local = FlutterLocalNotificationsPlugin();
  bool _iosReady = false;
  bool _androidReady = false;
  String? _current; // commande affichée
  String? _lastKey;

  static const _androidId = 7101;
  static const _channel = AndroidNotificationChannel(
    'as_delivery_live',
    'Livraison en direct',
    description: 'Suivi de la livraison de votre commande',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
  );

  bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  final _orders =
      <
        String,
        Map
      >{}; // dernière commande vue (pour les mises à jour du suivi en direct)
  final _eta = <String, int?>{};

  /// Temps restant et statut de la course, reçus du suivi en direct (carte)
  Future<void> live(
    String orderId, {
    int? etaMin,
    String? deliveryStatus,
  }) async {
    _eta[orderId] = etaMin;
    final o = _orders[orderId];
    if (o != null) await sync(o, deliveryStatus: deliveryStatus);
  }

  /// [order] : commande (statut, livraison) ; [deliveryStatus] : statut de la course s'il est plus récent
  Future<void> sync(Map order, {String? deliveryStatus}) async {
    if (!_supported) return;
    final id = order['id'] as String?;
    if (id != null) _orders[id] = order;
    final etaMin = id == null ? null : _eta[id];
    final d = (order['delivery'] as Map?) ?? {};
    final status = deliveryStatus ?? d['status'] as String?;
    final active =
        order['status'] == 'IN_DELIVERY' &&
        (status == 'ACCEPTED' || status == 'PICKED_UP');
    if (id == null || !active) {
      if (_current != null && (id == null || id == _current)) await end();
      return;
    }
    final picked = status == 'PICKED_UP';
    final driver = d['driver'] as Map?;
    final title = picked
        ? 'Votre colis est en route'
        : 'Le livreur va chercher votre colis';
    final subtitle = [
      driver?['name'] as String? ?? 'Livreur VITE',
      if ((driver?['plate'] ?? '').toString().isNotEmpty) driver!['plate'],
      order['number'],
    ].whereType<String>().join(' · ');
    final etaEpoch = etaMin == null
        ? 0
        : DateTime.now()
                  .add(Duration(minutes: etaMin))
                  .millisecondsSinceEpoch ~/
              1000;
    final key = '$id|$title|$subtitle|${etaMin ?? -1}';
    if (key == _lastKey) return;
    _lastKey = key;
    if (_current != null && _current != id) await end();
    _current = id;
    try {
      if (Platform.isIOS) {
        if (!_iosReady) {
          await _ios.init(
            appGroupId: kAppGroup,
            requestAndroidNotificationPermission: false,
          );
          _iosReady = true;
        }
        if (!await _ios.areActivitiesEnabled()) return;
        await _ios.createOrUpdateActivity(id, {
          'title': title,
          'subtitle': subtitle,
          'step': picked ? 2 : 1,
          'etaEpoch': etaEpoch,
        }, iOSEnableRemoteUpdates: false);
      } else {
        await _initAndroid();
        await _local.show(
          id: _androidId,
          title: title,
          body: [
            subtitle,
            if (etaMin != null) 'arrivée ~$etaMin min',
          ].join(' · '),
          payload: 'order:$id',
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.low,
              priority: Priority.low,
              ongoing: true,
              autoCancel: false,
              onlyAlertOnce: true,
              playSound: false,
              showProgress: true,
              maxProgress: 3,
              progress: picked ? 2 : 1,
              category: AndroidNotificationCategory.progress,
              visibility: NotificationVisibility.public,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Suivi en direct : $e');
    }
  }

  Future<void> _initAndroid() async {
    if (_androidReady) return;
    // Module de notifications initialisé une seule fois (notification touchée → commande)
    await Notices.instance.init();
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
    await Notices.instance.askOnce();
    _androidReady = true;
  }

  /// Liste des commandes : affiche la livraison en cours, ou arrête le suivi d'une commande terminée
  Future<void> syncAll(List orders) async {
    final list = orders.cast<Map>();
    final shown = list.where((o) => o['id'] == _current).firstOrNull;
    final active = list.where((o) => o['status'] == 'IN_DELIVERY').firstOrNull;
    if (shown != null && shown['status'] != 'IN_DELIVERY') await sync(shown);
    if (active != null) await sync(active);
  }

  Future<void> end() async {
    final id = _current;
    _current = null;
    _lastKey = null;
    if (!_supported) return;
    try {
      if (Platform.isIOS) {
        if (id != null && _iosReady) await _ios.endActivity(id);
      } else if (_androidReady) {
        await _local.cancel(id: _androidId);
      }
    } catch (_) {}
  }
}
