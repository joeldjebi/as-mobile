import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'api.dart';
import 'theme.dart';
import 'widgets.dart';

/// Communes du Grand Abidjan : pour vérifier que le point correspond au quartier saisi
const _communes = [
  'Abobo',
  'Adjamé',
  'Anyama',
  'Attécoubé',
  'Bingerville',
  'Cocody',
  'Koumassi',
  'Marcory',
  'Plateau',
  'Port-Bouët',
  'Songon',
  'Treichville',
  'Yopougon',
  'Grand-Bassam',
];

String _fold(String s) {
  const from = 'àâäéèêëîïôöùûüç';
  const to = 'aaaeeeeiioouuuc';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : (ch == '-' ? ' ' : ch));
  }
  return b.toString();
}

String? communeIn(String text) {
  final t = _fold(text);
  for (final c in _communes) {
    if (t.contains(_fold(c))) return c;
  }
  return null;
}

/// Nouvelle adresse de livraison. Renvoie l'id de l'adresse créée (ou null si annulé).
Future<String?> addAddressSheet(BuildContext context) =>
    Navigator.of(context).push<String>(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => const AddressScreen(),
      ),
    );

/// Nom, quartier (recherche : le point se place tout seul), repère, point vérifié sur la carte
class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});
  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  static const _abidjan = LatLng(5.3536, -4.0230);
  final _label = TextEditingController(text: 'Maison');
  final _address = TextEditingController();
  final _landmark = TextEditingController();
  final _map = MapController();
  LatLng? _pos;
  Map<String, dynamic>? _spot; // adresse du point : { label, commune }
  List<Map> _places = [];
  Timer? _debounce;
  bool _busy = false;
  bool _locating = false;
  bool _confirmed = false;
  int _reverseSeq = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _label.dispose();
    _address.dispose();
    _landmark.dispose();
    super.dispose();
  }

  void _onAddress(String v) {
    _debounce?.cancel();
    if (v.trim().length < 3) {
      setState(() => _places = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final r = await Api.instance.geoSearch(v.trim());
        if (mounted && _address.text.trim() == v.trim())
          setState(() => _places = r.cast<Map>());
      } catch (_) {}
    });
  }

  Future<void> _setPos(LatLng p, {bool move = true}) async {
    setState(() {
      _pos = p;
      _spot = null;
      _confirmed = false;
    });
    if (move) _map.move(p, 16.5);
    final seq = ++_reverseSeq;
    try {
      final r = await Api.instance.geoReverse(p.latitude, p.longitude);
      if (mounted && seq == _reverseSeq) setState(() => _spot = r);
    } catch (_) {}
  }

  void _pick(Map p) {
    FocusScope.of(context).unfocus();
    _address.text = [
      p['label'],
      p['sublabel'],
    ].where((x) => (x ?? '').toString().isNotEmpty).join(', ');
    setState(() => _places = []);
    _setPos(LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()));
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied)
        perm = await Geolocator.requestPermission();
      final p = await Geolocator.getCurrentPosition();
      await _setPos(LatLng(p.latitude, p.longitude));
    } catch (_) {
      if (mounted)
        showError(
          context,
          'Position indisponible : choisissez le quartier ou touchez la carte',
        );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  String? get _typed => communeIn(_address.text);
  bool get _mismatch {
    final c = _spot?['commune'] as String?;
    return _typed != null && c != null && communeIn(c) != _typed;
  }

  Future<void> _save() async {
    if (_address.text.trim().isEmpty)
      return showError(context, 'Indiquez la commune et le quartier');
    if (_pos == null)
      return showError(
        context,
        'Choisissez votre quartier dans la liste ou touchez la carte à l’endroit de la livraison',
      );
    // Point et quartier différents : on prévient une fois, un second « Ajouter » confirme
    if (_mismatch && !_confirmed) {
      setState(() => _confirmed = true);
      return showError(
        context,
        'Le point est à ${_spot!['commune']}, mais vous avez indiqué $_typed. Déplacez le point, ou touchez à nouveau « Ajouter » si c’est bien là.',
      );
    }
    setState(() => _busy = true);
    try {
      final before = ((Api.instance.user?['addresses'] as List?) ?? [])
          .map((a) => a['id'])
          .toSet();
      await Api.instance.addAddress({
        'label': _label.text.trim().isEmpty ? 'Adresse' : _label.text.trim(),
        'address': _address.text.trim(),
        'landmark': _landmark.text.trim(),
        'lat': _pos!.latitude,
        'lng': _pos!.longitude,
      });
      final after = ((Api.instance.user?['addresses'] as List?) ?? [])
          .cast<Map>();
      if (mounted)
        Navigator.pop(
          context,
          after.where((a) => !before.contains(a['id'])).firstOrNull?['id']
              as String?,
        );
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    TextEditingController c,
    String hint, {
    ValueChanged<String>? onChanged,
  }) => TextField(
    controller: c,
    onChanged: onChanged,
    style: AppText.body,
    decoration: InputDecoration(hintText: hint, filled: false),
  );

  @override
  Widget build(BuildContext context) {
    final spotText = _spot == null
        ? null
        : {
            _spot!['label'],
            _spot!['commune'],
          }.whereType<String>().where((s) => s.isNotEmpty).join(', ');
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(
                children: [
                  BarButton('Annuler', onTap: () => Navigator.pop(context)),
                  const Expanded(
                    child: Text(
                      'Nouvelle adresse',
                      textAlign: TextAlign.center,
                      style: AppText.title,
                    ),
                  ),
                  _busy
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 18),
                          child: CupertinoActivityIndicator(),
                        )
                      : BarButton('Ajouter', bold: true, onTap: _save),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  Group(
                    children: [
                      _field(_label, 'Nom (Maison, Bureau…)'),
                      _field(
                        _address,
                        'Commune, quartier (ex. Cocody Palmeraie)',
                        onChanged: _onAddress,
                      ),
                      _field(_landmark, 'Repère (facultatif)'),
                    ],
                  ),
                  if (_places.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Group(
                      dividerIndent: 48,
                      children: [
                        for (final p in _places.take(6))
                          Cell(
                            leading: const Icon(
                              PhosphorIconsFill.mapPin,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            title: '${p['label']}',
                            subtitle: (p['sublabel'] ?? '').toString().isEmpty
                                ? null
                                : '${p['sublabel']}',
                            onTap: () => _pick(p),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Point de livraison', style: AppText.title),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(36, 34),
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(17),
                        onPressed: _locating ? null : _locate,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _locating
                                ? const CupertinoActivityIndicator(radius: 7)
                                : const Icon(
                                    CupertinoIcons.location_fill,
                                    size: 15,
                                    color: AppColors.primary,
                                  ),
                            const SizedBox(width: 6),
                            Text(
                              'Ma position',
                              style: AppText.body.copyWith(
                                color: AppColors.primary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 260,
                      child: FlutterMap(
                        mapController: _map,
                        options: MapOptions(
                          initialCenter: _abidjan,
                          initialZoom: 12,
                          interactionOptions: const InteractionOptions(
                            flags:
                                InteractiveFlag.all & ~InteractiveFlag.rotate,
                          ),
                          onTap: (_, ll) => _setPos(ll, move: false),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'ci.adjamesmart.adjame_smart',
                          ),
                          if (_pos != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _pos!,
                                  width: 40,
                                  height: 40,
                                  alignment: Alignment.topCenter,
                                  child: const Icon(
                                    PhosphorIconsFill.mapPin,
                                    color: AppColors.primary,
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  SectionFooter(
                    _pos == null
                        ? 'Choisissez votre quartier dans la liste, puis touchez la carte à l’endroit exact de la livraison : le livreur ira exactement là.'
                        : spotText == null
                        ? 'Touchez la carte pour ajuster le point : le livreur ira exactement là.'
                        : 'Point placé : $spotText. Touchez la carte pour l’ajuster : le livreur ira exactement là.',
                  ),
                  if (_mismatch) ...[
                    const SizedBox(height: 12),
                    StatusBanner(
                      icon: CupertinoIcons.info_circle_fill,
                      color: AppColors.warning,
                      title: 'Vérifiez le point',
                      text:
                          'Le point est à ${_spot!['commune']}, mais vous avez indiqué $_typed.',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
