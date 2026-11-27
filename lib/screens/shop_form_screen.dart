import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets.dart';
import 'photo_field.dart';
import 'prepay_picker.dart';
import 'products_screen.dart';

/// Centre d'Adjamé (Forum des marchés)
const _adjame = LatLng(5.3555, -4.0225);
const _idTypes = {
  'CNI': 'Carte nationale d’identité',
  'PASSPORT': 'Passeport',
  'CONSULAR': 'Carte consulaire',
  'RESIDENCE': 'Carte de séjour',
};
const _days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

/// Inscription ou modification d'une boutique : brouillon enregistré, puis dossier envoyé à l'équipe
class ShopFormScreen extends StatefulWidget {
  final Map<String, dynamic>? shop;
  const ShopFormScreen({super.key, this.shop});
  @override
  State<ShopFormScreen> createState() => _ShopFormScreenState();
}

class _ShopFormScreenState extends State<ShopFormScreen> {
  final api = Api.instance;
  late Map<String, dynamic>? _s = widget.shop;
  late final _name = TextEditingController(text: _s?['name']);
  late final _phone = TextEditingController(
    text: (_s?['phone'] as String?)?.replaceFirst('+225', ''),
  );
  late final _description = TextEditingController(text: _s?['description']);
  late final _location = TextEditingController(text: _s?['location']);
  late final _idNumber = TextEditingController(text: _s?['ownerIdNumber']);
  late final _register = TextEditingController(text: _s?['tradeRegister']);
  late String _type = _s?['type'] ?? 'BOUTIQUE';
  late String? _market = _s?['market'];
  late String _idType = _s?['ownerIdType'] ?? 'CNI';
  late final Set<String> _cats = {
    ...((_s?['categoryIds'] as List?) ?? []).cast<String>(),
  };
  late LatLng? _pos = _s?['lat'] != null
      ? LatLng((_s!['lat'] as num).toDouble(), (_s!['lng'] as num).toDouble())
      : null;
  late int _prepay = (_s?['prepayPercent'] as num?)?.toInt() ?? 100;
  late String _payout = (_s?['payoutMode'] as String?) ?? 'PLATFORM';
  late final _alias = TextEditingController(text: _s?['pispiAlias'] as String? ?? '');
  late String _open = (_s?['hours'] as Map?)?['open'] ?? '08:00';
  late String _close = (_s?['hours'] as Map?)?['close'] ?? '18:00';
  late final Set<int> _openDays = {
    ...(((_s?['hours'] as Map?)?['days'] as List?) ?? [1, 2, 3, 4, 5, 6])
        .cast<int>(),
  };
  final Map<String, String> _photos = {};
  List<dynamic> _categories = [];
  List<String> _markets = [];
  bool _busy = false;
  final _map = MapController();

  String get _status => _s?['status'] ?? 'DRAFT';
  bool get _editable => _status == 'DRAFT' || _status == 'REJECTED';
  bool get _approved => _status == 'APPROVED' || _status == 'SUSPENDED';

  @override
  void initState() {
    super.initState();
    Future.wait([api.categories(), api.markets()])
        .then((r) {
          if (mounted) {
            setState(() {
              _categories = r[0];
              _markets = r[1] as List<String>;
            });
          }
        })
        .catchError((Object e) {
          if (mounted) showError(context, e);
        });
  }

  Map<String, dynamic> _fields() {
    final phone = _phone.text.replaceAll(RegExp(r'\D'), '');
    return {
      'name': _name.text.trim(),
      'type': _type,
      'description': _description.text.trim(),
      if (phone.isNotEmpty) 'phone': phone,
      'categoryIds': _cats.toList(),
      'prepayPercent': _prepay,
      'pispiAlias': _alias.text.trim(),
      'payoutMode': _payout,
      'hours': {
        'open': _open,
        'close': _close,
        'days': _openDays.toList()..sort(),
      },
      if (_editable) ...{
        'market': ?_market,
        'location': _location.text.trim(),
        if (_pos != null) 'lat': _pos!.latitude,
        if (_pos != null) 'lng': _pos!.longitude,
        'ownerIdType': _idType,
        'ownerIdNumber': _idNumber.text.trim(),
        ..._photos,
      } else ...{
        // Après validation : seules les photos publiques changent
        for (final k in ['logoUrl', 'storefrontUrl'])
          if (_photos[k] != null) k: _photos[k],
      },
      'tradeRegister': _register.text.trim(),
    };
  }

  Future<bool> _save({bool quiet = false}) async {
    if (_name.text.trim().isEmpty) {
      showError(context, 'Indiquez le nom de la boutique');
      return false;
    }
    setState(() => _busy = true);
    try {
      final s = _s == null
          ? await api.createShop(_fields())
          : await api.updateShop(_s!['id'], _fields());
      if (!mounted) return false;
      setState(() {
        _s = s;
        _photos.clear();
      });
      if (!quiet) showInfo(context, 'Boutique enregistrée');
      return true;
    } catch (e) {
      if (mounted) showError(context, e);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!await _save(quiet: true)) return;
    setState(() => _busy = true);
    try {
      final s = await api.submitShop(_s!['id']);
      if (!mounted) return;
      setState(() => _s = s);
      showInfo(
        context,
        'Dossier envoyé : Adjamé-Smart le vérifie au plus vite',
      );
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _myPosition() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) {
          showError(
            context,
            'Autorisez la localisation, ou placez le repère à la main sur la carte',
          );
        }
        return;
      }
      final p = await Geolocator.getCurrentPosition();
      final ll = LatLng(p.latitude, p.longitude);
      setState(() => _pos = ll);
      _map.move(ll, 17);
    } catch (_) {
      if (mounted) {
        showError(
          context,
          'Position indisponible : placez le repère à la main sur la carte',
        );
      }
    }
  }

  Future<void> _pickTime(bool open) async {
    final cur = (open ? _open : _close).split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(cur[0]),
        minute: int.parse(cur[1]),
      ),
    );
    if (t == null) return;
    final v =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    setState(() => open ? _open = v : _close = v);
  }

  Widget _banner() {
    final note = _s?['reviewNote'] as String?;
    return switch (_status) {
      'PENDING' => const StatusBanner(
        icon: PhosphorIconsBold.hourglassMedium,
        color: AppColors.warning,
        title: 'Dossier en cours de vérification',
        text:
            'Adjamé-Smart vérifie votre boutique. Vous serez prévenu dès qu’elle est en ligne.',
      ),
      'APPROVED' => const StatusBanner(
        icon: PhosphorIconsFill.sealCheck,
        color: AppColors.success,
        title: 'Boutique en ligne',
        text:
            'Les clients la voient dans l’app. L’ajout de produits arrive bientôt.',
      ),
      'REJECTED' => StatusBanner(
        icon: PhosphorIconsFill.info,
        color: AppColors.warning,
        title: 'Dossier à corriger',
        text: note ?? 'Corrigez votre dossier puis renvoyez-le.',
      ),
      'SUSPENDED' => StatusBanner(
        icon: PhosphorIconsFill.pauseCircle,
        color: AppColors.warning,
        title: 'Boutique suspendue',
        text: note ?? 'Contactez Adjamé-Smart.',
      ),
      _ => const StatusBanner(
        icon: PhosphorIconsFill.storefront,
        color: AppColors.primary,
        title: 'Ouvrez votre boutique',
        text:
            'Remplissez le dossier puis envoyez-le : l’équipe le vérifie avant la mise en ligne.',
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final e = _editable;
    final missing = ((_s?['required'] as List?) ?? [])
        .cast<Map>()
        .where((r) => r['ok'] != true)
        .map((r) => r['label'])
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(_s == null ? 'Ouvrir ma boutique' : _s!['name']),
      ),
      bottomNavigationBar: _status == 'PENDING'
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => _save(),
                        child: const Text('Enregistrer'),
                      ),
                    ),
                    if (e) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: Text(
                            _status == 'REJECTED'
                                ? 'Renvoyer'
                                : 'Envoyer le dossier',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
      body: AbsorbPointer(
        absorbing: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _banner(),
            if (_s != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProductsScreen(shop: _s!)),
                ),
                icon: const Icon(PhosphorIconsBold.package),
                label: const Text('Mes produits'),
              ),
            ],
            if (e && _s != null && missing.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'À compléter : ${missing.join(', ')}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
            const SectionTitle('La boutique'),
            TextField(
              controller: _name,
              enabled: !_approved,
              decoration: const InputDecoration(hintText: 'Nom de la boutique'),
            ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'BOUTIQUE', label: Text('Boutique')),
                ButtonSegment(value: 'GROSSISTE', label: Text('Grossiste')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: 'Téléphone de la boutique',
                prefixText: '+225  ',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Ce que vous vendez (facultatif)',
              ),
            ),
            const SectionTitle('Catégories (5 maximum)'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _categories)
                  FilterChip(
                    label: Text(c['name'] as String),
                    selected: _cats.contains(c['id']),
                    onSelected: (v) => setState(() {
                      if (v && _cats.length >= 5) {
                        return showError(context, '5 catégories maximum');
                      }
                      v ? _cats.add(c['id'] as String) : _cats.remove(c['id']);
                    }),
                  ),
              ],
            ),
            const SectionTitle('Emplacement à Adjamé'),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _markets.contains(_market) ? _market : null,
              hint: Text(
                _market ?? 'Marché ou zone',
                overflow: TextOverflow.ellipsis,
              ),
              items: [
                for (final m in _markets)
                  DropdownMenuItem(
                    value: m,
                    child: Text(m, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: e ? (v) => setState(() => _market = v) : null,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _location,
              enabled: e,
              decoration: const InputDecoration(
                hintText: 'Allée, n° du magasin, repère',
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 220,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _map,
                      options: MapOptions(
                        initialCenter: _pos ?? _adjame,
                        initialZoom: _pos != null ? 17 : 15,
                        onTap: e ? (_, ll) => setState(() => _pos = ll) : null,
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
                    if (e)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 40),
                          ),
                          onPressed: _myPosition,
                          icon: const Icon(
                            PhosphorIconsBold.crosshair,
                            size: 18,
                          ),
                          label: const Text('Ma position'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Touchez la carte pour placer le repère sur votre magasin.',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
            ),
            const SectionTitle('Horaires'),
            Group(
              children: [
                ListTile(
                  title: const Text('Ouverture'),
                  trailing: Text(_open),
                  onTap: () => _pickTime(true),
                ),
                ListTile(
                  title: const Text('Fermeture'),
                  trailing: Text(_close),
                  onTap: () => _pickTime(false),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (var d = 1; d <= 7; d++)
                        FilterChip(
                          label: Text(_days[d - 1]),
                          selected: _openDays.contains(d),
                          onSelected: (v) => setState(
                            () => v ? _openDays.add(d) : _openDays.remove(d),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SectionTitle('Paiement avant livraison'),
            PrepayPicker(value: _prepay, onChanged: (v) => setState(() => _prepay = v ?? 100)),
            const SectionFooter('Valeur par défaut de vos produits ; vous pouvez la changer produit par produit.'),
            const SectionTitle('Encaissement des ventes'),
            Group(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoSlidingSegmentedControl<String>(
                    groupValue: _payout,
                    children: const {'PLATFORM': Text('Via Adjamé-Smart'), 'DIRECT': Text('Directement')},
                    onValueChanged: (v) => setState(() => _payout = v ?? 'PLATFORM'),
                  ),
                ),
              ),
              if (_payout == 'DIRECT')
                Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: TextField(controller: _alias, decoration: const InputDecoration(hintText: 'Votre alias PI-SPI (numéro Mobile Money)', filled: false)),
                ),
            ]),
            SectionFooter(_payout == 'DIRECT'
                ? 'Le client vous paie directement. Vous confirmez la réception dans « Commandes reçues » : la livraison VITE part aussitôt.'
                : 'Le client paie Adjamé-Smart, qui confirme la réception puis vous reverse le montant.'),
            const SectionTitle('Photos de la boutique'),
            Row(
              children: [
                Expanded(
                  child: PhotoField(
                    label: 'Devanture',
                    url: _photos['storefrontUrl'] ?? _s?['storefrontUrl'],
                    onUploaded: (u) =>
                        setState(() => _photos['storefrontUrl'] = u),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PhotoField(
                    label: 'Logo (facultatif)',
                    url: _photos['logoUrl'] ?? _s?['logoUrl'],
                    onUploaded: (u) => setState(() => _photos['logoUrl'] = u),
                  ),
                ),
              ],
            ),
            const SectionTitle('Gérant'),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _idType,
              items: [
                for (final t in _idTypes.entries)
                  DropdownMenuItem(
                    value: t.key,
                    child: Text(t.value, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: e ? (v) => setState(() => _idType = v!) : null,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _idNumber,
              enabled: e,
              decoration: const InputDecoration(hintText: 'Numéro de la pièce'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: PhotoField(
                    label: 'Pièce (recto)',
                    url: _photos['ownerIdFrontUrl'] ?? _s?['ownerIdFrontUrl'],
                    identity: true,
                    enabled: e,
                    onUploaded: (u) =>
                        setState(() => _photos['ownerIdFrontUrl'] = u),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PhotoField(
                    label: 'Pièce (verso)',
                    url: _photos['ownerIdBackUrl'] ?? _s?['ownerIdBackUrl'],
                    identity: true,
                    enabled: e,
                    onUploaded: (u) =>
                        setState(() => _photos['ownerIdBackUrl'] = u),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _register,
              decoration: const InputDecoration(
                hintText: 'Registre du commerce (facultatif)',
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Votre pièce d’identité n’est visible que par l’équipe Adjamé-Smart, pour vérifier votre boutique.',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
