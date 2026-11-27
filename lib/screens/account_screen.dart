import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets.dart';
import 'auth_screen.dart';
import 'reseller_screen.dart';
import 'shop_form_screen.dart';

const _shopStatus = {'DRAFT': 'Brouillon', 'PENDING': 'En vérification', 'APPROVED': 'En ligne', 'REJECTED': 'À corriger', 'SUSPENDED': 'Suspendue'};
const _resellerStatus = {'NONE': 'Achetez pour revendre ? Demandez le statut', 'PENDING': 'Demande en vérification', 'APPROVED': 'Prix de gros visibles', 'REJECTED': 'Demande refusée'};

/// Compte : visiteur (invitation à se connecter) ou client (profil, adresses, revendeur, espace vendeur)
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final api = Api.instance;
  List<dynamic> _shops = [];
  bool _wasLogged = false;

  @override
  void initState() {
    super.initState();
    _wasLogged = api.loggedIn;
    api.addListener(_onSession);
    if (api.loggedIn) _load();
  }

  @override
  void dispose() {
    api.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    if (!mounted) return;
    if (api.loggedIn && !_wasLogged) _loadShops();
    if (!api.loggedIn) _shops = [];
    _wasLogged = api.loggedIn;
    setState(() {});
  }

  Future<void> _load() async {
    if (!api.loggedIn) return;
    try {
      await api.refreshMe();
      await _loadShops();
    } catch (_) {}
  }

  Future<void> _loadShops() async {
    try {
      final shops = await api.myShops();
      if (mounted) setState(() => _shops = shops);
    } catch (_) {}
  }

  Future<void> _openShop([Map<String, dynamic>? s]) async {
    if (!await requireAuth(context, reason: 'Connectez-vous pour ouvrir votre boutique')) return;
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ShopFormScreen(shop: s)));
    _load();
  }

  Future<void> _addAddress() async {
    final label = TextEditingController(text: 'Maison');
    final address = TextEditingController();
    final landmark = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(c).viewInsets.bottom + 24 + MediaQuery.of(c).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Nouvelle adresse', style: AppText.headline),
          const SizedBox(height: 6),
          const Text('Votre position actuelle est enregistrée avec l’adresse, pour guider le livreur.', style: AppText.bodyMuted),
          const SizedBox(height: 18),
          TextField(controller: label, decoration: const InputDecoration(hintText: 'Nom (Maison, Bureau…)')),
          const SizedBox(height: 10),
          TextField(controller: address, decoration: const InputDecoration(hintText: 'Commune, quartier')),
          const SizedBox(height: 10),
          TextField(controller: landmark, decoration: const InputDecoration(hintText: 'Repère (facultatif)')),
          const SizedBox(height: 20),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Enregistrer ici')),
        ]),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      final p = await Geolocator.getCurrentPosition();
      await api.addAddress({'label': label.text.trim(), 'address': address.text.trim(), 'landmark': landmark.text.trim(), 'lat': p.latitude, 'lng': p.longitude});
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) showError(context, e is ApiException ? e : 'Position indisponible : activez la localisation');
    }
  }

  Widget _row(IconData icon, String title, {String? sub, VoidCallback? onTap, Widget? trailing}) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    leading: Icon(icon, color: AppColors.ink, size: 22),
    title: Text(title, style: AppText.label.copyWith(fontSize: 14.5)),
    subtitle: sub == null ? null : Text(sub, style: AppText.caption),
    trailing: trailing ?? (onTap == null ? null : const Icon(PhosphorIconsRegular.caretRight, size: 16, color: AppColors.faint)),
    onTap: onTap,
  );

  Widget _guest() => ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), children: [
    const Text('Compte', style: AppText.display),
    const SizedBox(height: 22),
    Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('BIENVENUE', style: AppText.overline.copyWith(color: Colors.white70)),
        const SizedBox(height: 8),
        Text('Connectez-vous pour commander et suivre vos livraisons.', style: AppText.headline.copyWith(color: Colors.white, fontSize: 22)),
        const SizedBox(height: 18),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.ink),
          onPressed: () => requireAuth(context),
          child: const Text('Se connecter ou créer un compte'),
        ),
      ]),
    ),
    const SectionTitle('Vous vendez à Adjamé ?'),
    Group(children: [
      _row(PhosphorIconsLight.storefront, 'Ouvrir ma boutique', sub: 'Mettez vos produits en ligne gratuitement', onTap: () => _openShop()),
      _row(PhosphorIconsLight.tag, 'Devenir revendeur', sub: 'Accédez aux prix de gros', onTap: () async {
        if (!await requireAuth(context, reason: 'Connectez-vous pour demander le statut revendeur')) return;
        if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const ResellerScreen()));
      }),
    ]),
    const SectionTitle('Adjamé-Smart'),
    Group(children: [
      _row(PhosphorIconsLight.moped, 'Livraison par LETO', sub: 'Frais payés en espèces au livreur'),
      _row(PhosphorIconsLight.shieldCheck, 'Paiement Mobile Money', sub: 'Le colis est remis une fois le paiement confirmé'),
    ]),
  ]);

  @override
  Widget build(BuildContext context) {
    if (!api.loggedIn) return SafeArea(bottom: false, child: _guest());
    final u = api.user ?? {};
    final name = (u['name'] as String?) ?? '';
    final addresses = ((u['addresses'] as List?) ?? []).cast<Map>();
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.ink,
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), children: [
          const Text('Compte', style: AppText.display),
          const SizedBox(height: 20),
          Row(children: [
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(), style: AppText.headline.copyWith(color: Colors.white, fontSize: 26)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: AppText.title.copyWith(fontSize: 19)),
                const SizedBox(height: 2),
                Text(formatPhone(u['phone'] as String?), style: AppText.caption),
              ]),
            ),
            if (u['resellerStatus'] == 'APPROVED') const Pill('Revendeur', background: AppColors.accent),
          ]),
          const SectionTitle('Ma boutique'),
          Group(children: [
            for (final s in _shops)
              _row(PhosphorIconsLight.storefront, s['name'] as String, sub: _shopStatus[s['status']] ?? '', onTap: () => _openShop(Map<String, dynamic>.from(s))),
            _row(PhosphorIconsLight.plusCircle, _shops.isEmpty ? 'Ouvrir ma boutique' : 'Ouvrir une autre boutique', sub: 'Vous vendez à Adjamé ? Mettez-la en ligne', onTap: () => _openShop()),
          ]),
          const SectionTitle('Revendeur'),
          Group(children: [
            _row(PhosphorIconsLight.tag, 'Statut revendeur', sub: _resellerStatus[u['resellerStatus']] ?? '', onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ResellerScreen()));
              _load();
            }),
          ]),
          const SectionTitle('Adresses de livraison'),
          Group(children: [
            for (final a in addresses)
              _row(
                PhosphorIconsLight.mapPin,
                a['label'] as String,
                sub: [a['address'], a['landmark']].where((x) => (x ?? '').toString().isNotEmpty).join(' · '),
                trailing: IconButton(
                  icon: const Icon(PhosphorIconsLight.trash, size: 20, color: AppColors.muted),
                  onPressed: () async {
                    try {
                      await api.removeAddress(a['id'] as String);
                      if (mounted) setState(() {});
                    } catch (e) {
                      if (context.mounted) showError(context, e);
                    }
                  },
                ),
              ),
            _row(PhosphorIconsLight.plusCircle, 'Ajouter une adresse', onTap: _addAddress),
          ]),
          const SizedBox(height: 28),
          OutlinedButton(onPressed: () => api.logout(), child: const Text('Se déconnecter')),
        ]),
      ),
    );
  }
}
