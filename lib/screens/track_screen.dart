import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../order_live.dart';
import '../theme.dart';
import '../widgets.dart';

/// Suivi en direct d'une course VITE : données rafraîchies toutes les 8 s
class TrackData {
  final Map<String, dynamic> raw;
  TrackData(this.raw);

  static LatLng? _ll(Object? m) {
    if (m is! Map || m['lat'] == null || m['lng'] == null) return null;
    return LatLng((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble());
  }

  static List<LatLng> _line(Object? l) => l is List
      ? [
          for (final p in l)
            if (p is List && p.length >= 2)
              LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
        ]
      : const [];

  String get status => '${raw['status']}';
  LatLng? get pickup => _ll(raw['pickup']);
  LatLng? get destination {
    final stops = (raw['stops'] as List?) ?? const [];
    return stops.isEmpty ? null : _ll(stops.first);
  }

  Map? get driver => raw['driver'] as Map?;
  LatLng? get driverPos => _ll(driver?['position']);
  bool get live => (driver?['position'] as Map?)?['live'] == true;
  int? get etaMin => (raw['etaMin'] as num?)?.toInt();
  List<LatLng> get route => _line(raw['route']);
  List<LatLng> get approach => _line(raw['approach']);

  /// Phrase principale selon l'avancement
  String get headline => switch (status) {
    'PENDING' => 'Recherche d’un livreur',
    'ACCEPTED' => 'Le livreur va chercher votre colis',
    'PICKED_UP' => 'Votre colis est en route',
    'DELIVERED' => 'Colis livré',
    'CANCELLED' => 'Course annulée',
    _ => 'Livraison en cours',
  };
}

/// Charge et rafraîchit le suivi tant que le widget est affiché
mixin _Polling<T extends StatefulWidget> on State<T> {
  TrackData? data;
  bool unavailable = false;
  Timer? _timer;
  String get orderId;

  void startPolling() {
    _load();
    // Pas d'appel en double quand un autre écran (suivi plein écran) le recouvre
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) _load();
    });
  }

  Future<void> _load() async {
    try {
      final r = await Api.instance.trackOrder(orderId);
      OrderLive.instance.live(
        orderId,
        etaMin: (r['etaMin'] as num?)?.toInt(),
        deliveryStatus: r['status'] as String?,
      );
      if (mounted)
        setState(() {
          data = TrackData(r);
          unavailable = false;
        });
    } catch (_) {
      if (mounted && data == null) setState(() => unavailable = true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Carte : tournée (gris), approche du livreur (émeraude), boutique, client, livreur
class _TrackMap extends StatelessWidget {
  final TrackData d;
  final MapController controller;
  final bool interactive;
  const _TrackMap({
    super.key,
    required this.d,
    required this.controller,
    this.interactive = true,
  });

  @override
  Widget build(BuildContext context) {
    final pts = [?d.pickup, ?d.destination, ?d.driverPos];
    final fit = pts.length >= 2
        ? CameraFit.coordinates(
            coordinates: pts,
            padding: const EdgeInsets.fromLTRB(48, 60, 48, 60),
            maxZoom: 16,
          )
        : null;
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: pts.isNotEmpty
            ? pts.first
            : const LatLng(5.3536, -4.0230),
        initialZoom: 14,
        initialCameraFit: fit,
        interactionOptions: InteractionOptions(
          flags: interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'ci.adjamesmart.adjame_smart',
        ),
        PolylineLayer(
          polylines: [
            if (d.route.length >= 2)
              Polyline(
                points: d.route,
                strokeWidth: 5,
                color: const Color(0xFF8A8A8E).withValues(alpha: 0.55),
              ),
            if (d.approach.length >= 2)
              Polyline(
                points: d.approach,
                strokeWidth: 5,
                color: AppColors.primary,
              ),
          ],
        ),
        MarkerLayer(
          markers: [
            if (d.pickup != null)
              Marker(
                point: d.pickup!,
                width: 34,
                height: 34,
                child: const _Pin(
                  icon: PhosphorIconsFill.storefront,
                  color: AppColors.ink,
                ),
              ),
            if (d.destination != null)
              Marker(
                point: d.destination!,
                width: 34,
                height: 34,
                child: const _Pin(
                  icon: PhosphorIconsFill.house,
                  color: AppColors.accent,
                ),
              ),
            if (d.driverPos != null)
              Marker(
                point: d.driverPos!,
                width: 42,
                height: 42,
                child: _Pin(
                  icon: PhosphorIconsFill.moped,
                  color: d.live ? AppColors.primary : AppColors.muted,
                  size: 42,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Pin extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const _Pin({required this.icon, required this.color, this.size = 34});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Icon(icon, color: Colors.white, size: size * 0.5),
  );
}

String _etaText(TrackData d) {
  if (d.etaMin == null)
    return d.driverPos == null
        ? 'Position du livreur bientôt disponible'
        : 'Position mise à jour il y a quelques minutes';
  return d.status == 'ACCEPTED'
      ? 'Arrivée à la boutique dans ${d.etaMin} min'
      : 'Arrivée chez vous dans ${d.etaMin} min';
}

/// Aperçu dans l'écran de commande : petite carte, temps restant ; touchez pour le plein écran
class LiveTrackCard extends StatefulWidget {
  final String orderId;
  const LiveTrackCard({super.key, required this.orderId});
  @override
  State<LiveTrackCard> createState() => _LiveTrackCardState();
}

class _LiveTrackCardState extends State<LiveTrackCard> with _Polling {
  final _map = MapController();
  @override
  String get orderId => widget.orderId;

  @override
  void initState() {
    super.initState();
    startPolling();
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    if (unavailable || d == null) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: unavailable
            ? Text('Carte disponible dans un instant', style: AppText.caption)
            : const CupertinoActivityIndicator(),
      );
    }
    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(CupertinoPageRoute(builder: (_) => TrackScreen(orderId: orderId))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 210,
          child: Stack(
            children: [
              // La carte suit le livreur : reconstruite (et recadrée) à chaque nouvelle position
              IgnorePointer(
                child: _TrackMap(
                  key: ValueKey('${d.driverPos}'),
                  d: d,
                  controller: _map,
                  interactive: false,
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Glass(
                  radius: BorderRadius.circular(12),
                  opacity: 0.86,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                d.headline,
                                style: AppText.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              Text(_etaText(d), style: AppText.caption),
                            ],
                          ),
                        ),
                        const Icon(
                          CupertinoIcons.arrow_up_left_arrow_down_right,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Plein écran : carte interactive, livreur, appel, temps restant
class TrackScreen extends StatefulWidget {
  final String orderId;
  const TrackScreen({super.key, required this.orderId});
  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> with _Polling {
  final _map = MapController();
  bool _follow = true;
  @override
  String get orderId => widget.orderId;

  @override
  void initState() {
    super.initState();
    startPolling();
  }

  @override
  void setState(VoidCallback fn) {
    final before = data?.driverPos;
    super.setState(fn);
    final now = data?.driverPos;
    // Suit le livreur tant que le client n'a pas déplacé la carte
    if (_follow && now != null && before != null && now != before) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _map.move(now, _map.camera.zoom);
        } catch (_) {}
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    final driver = d?.driver;
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: d == null
                ? Center(
                    child: unavailable
                        ? Text(
                            'Le suivi arrive dans un instant',
                            style: AppText.caption,
                          )
                        : const Loader(),
                  )
                : Listener(
                    onPointerDown: (_) => _follow = false,
                    child: _TrackMap(d: d, controller: _map),
                  ),
          ),
          Positioned(
            top: top + 8,
            left: 12,
            child: Glass(
              radius: BorderRadius.circular(22),
              child: CupertinoButton(
                padding: const EdgeInsets.all(10),
                minimumSize: const Size(44, 44),
                onPressed: () => Navigator.pop(context),
                child: const Icon(
                  CupertinoIcons.chevron_back,
                  color: AppColors.ink,
                  size: 20,
                ),
              ),
            ),
          ),
          if (d?.driverPos != null)
            Positioned(
              top: top + 8,
              right: 12,
              child: Glass(
                radius: BorderRadius.circular(22),
                child: CupertinoButton(
                  padding: const EdgeInsets.all(10),
                  minimumSize: const Size(44, 44),
                  onPressed: () {
                    _follow = true;
                    _map.move(d!.driverPos!, 16);
                  },
                  child: const Icon(
                    CupertinoIcons.location_fill,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
            ),
          if (d != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: MediaQuery.paddingOf(context).bottom + 12,
              child: Glass(
                radius: BorderRadius.circular(20),
                opacity: 0.9,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(d.headline, style: AppText.title),
                      const SizedBox(height: 2),
                      Text(_etaText(d), style: AppText.caption),
                      if (driver != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: AppColors.primarySoft,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                PhosphorIconsFill.moped,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${driver['name']}',
                                    style: AppText.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    [
                                      driver['vehicle'] == 'MOTO'
                                          ? 'Moto'
                                          : driver['vehicle'],
                                      driver['plate'],
                                      if (driver['rating'] != null)
                                        '★ ${(driver['rating'] as num).toStringAsFixed(1)}',
                                    ].whereType<String>().join(' · '),
                                    style: AppText.caption,
                                  ),
                                ],
                              ),
                            ),
                            if (driver['phone'] != null)
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(44, 44),
                                onPressed: () => launchUrl(
                                  Uri.parse('tel:${driver['phone']}'),
                                ),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.phone_fill,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
