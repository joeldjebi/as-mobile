import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../api.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets.dart';
import 'reseller_screen.dart';
import 'shop_form_screen.dart';

const _shopStatus = {
  'DRAFT': 'Brouillon',
  'PENDING': 'En vérification',
  'APPROVED': 'En ligne',
  'REJECTED': 'À corriger',
  'SUSPENDED': 'Suspendue',
};
const _resellerStatus = {
  'NONE': 'Achetez pour revendre ? Demandez le statut',
  'PENDING': 'Demande en vérification',
  'APPROVED': 'Prix de gros visibles',
  'REJECTED': 'Demande refusée',
};

/// Compte : profil, adresses, statut revendeur, espace vendeur
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final api = Api.instance;
  List<dynamic> _shops = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await api.refreshMe();
      final shops = await api.myShops();
      if (mounted) setState(() => _shops = shops);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _openShop([Map<String, dynamic>? s]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ShopFormScreen(shop: s)),
    );
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
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(c).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Nouvelle adresse',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Votre position actuelle est enregistrée avec l’adresse.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: label,
              decoration: const InputDecoration(
                hintText: 'Nom (Maison, Bureau…)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: address,
              decoration: const InputDecoration(hintText: 'Commune, quartier'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: landmark,
              decoration: const InputDecoration(
                hintText: 'Repère (facultatif)',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Enregistrer ici'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      final p = await Geolocator.getCurrentPosition();
      await api.addAddress({
        'label': label.text.trim(),
        'address': address.text.trim(),
        'landmark': landmark.text.trim(),
        'lat': p.latitude,
        'lng': p.longitude,
      });
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        showError(
          context,
          e is ApiException
              ? e
              : 'Position indisponible : activez la localisation',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = api.user ?? {};
    final addresses = ((u['addresses'] as List?) ?? []).cast<Map>();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const Text(
            'Compte',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Group(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Text(
                    (u['name'] as String? ?? '?').characters.first
                        .toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  u['name'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(formatPhone(u['phone'])),
              ),
            ],
          ),
          const SectionTitle('Ma boutique'),
          Group(
            children: [
              for (final s in _shops)
                ListTile(
                  leading: const Icon(
                    PhosphorIconsFill.storefront,
                    color: AppColors.primary,
                  ),
                  title: Text(s['name']),
                  subtitle: Text(_shopStatus[s['status']] ?? ''),
                  trailing: const Icon(PhosphorIconsBold.caretRight, size: 18),
                  onTap: () => _openShop(Map<String, dynamic>.from(s)),
                ),
              ListTile(
                leading: const Icon(
                  PhosphorIconsBold.plusCircle,
                  color: AppColors.primary,
                ),
                title: Text(
                  _shops.isEmpty
                      ? 'Ouvrir ma boutique'
                      : 'Ouvrir une autre boutique',
                ),
                subtitle: const Text(
                  'Vous vendez à Adjamé ? Mettez votre boutique en ligne',
                ),
                onTap: () => _openShop(),
              ),
            ],
          ),
          const SectionTitle('Revendeur'),
          Group(
            children: [
              ListTile(
                leading: const Icon(
                  PhosphorIconsBold.tag,
                  color: AppColors.primary,
                ),
                title: const Text('Statut revendeur'),
                subtitle: Text(_resellerStatus[u['resellerStatus']] ?? ''),
                trailing: const Icon(PhosphorIconsBold.caretRight, size: 18),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ResellerScreen()),
                  );
                  _load();
                },
              ),
            ],
          ),
          const SectionTitle('Adresses de livraison'),
          Group(
            children: [
              for (final a in addresses)
                ListTile(
                  leading: const Icon(PhosphorIconsBold.mapPin),
                  title: Text(a['label']),
                  subtitle: Text(
                    [
                      a['address'],
                      a['landmark'],
                    ].where((x) => (x ?? '').toString().isNotEmpty).join(' · '),
                  ),
                  trailing: IconButton(
                    icon: const Icon(PhosphorIconsBold.trash, size: 20),
                    onPressed: () async {
                      try {
                        await api.removeAddress(a['id']);
                        if (mounted) setState(() {});
                      } catch (e) {
                        if (context.mounted) showError(context, e);
                      }
                    },
                  ),
                ),
              ListTile(
                leading: const Icon(
                  PhosphorIconsBold.plusCircle,
                  color: AppColors.primary,
                ),
                title: const Text('Ajouter une adresse'),
                onTap: _addAddress,
              ),
            ],
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(PhosphorIconsBold.signOut),
            onPressed: () async {
              await api.logout();
              if (context.mounted) goHome(context);
            },
            label: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }
}
