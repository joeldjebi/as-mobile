import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets.dart';
import 'account_screen.dart';
import 'shop_page.dart';

/// Accueil : onglets Découvrir (catégories, boutiques) et Compte
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: IndexedStack(index: _tab, children: const [DiscoverTab(), AccountScreen()])),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (i) => setState(() => _tab = i),
      destinations: const [
        NavigationDestination(icon: Icon(PhosphorIconsBold.storefront), selectedIcon: Icon(PhosphorIconsFill.storefront), label: 'Découvrir'),
        NavigationDestination(icon: Icon(PhosphorIconsBold.userCircle), selectedIcon: Icon(PhosphorIconsFill.userCircle), label: 'Compte'),
      ],
    ),
  );
}

/// Icône d'une catégorie (nom Phosphor envoyé par l'API)
IconData categoryIcon(String? name) => switch (name) {
  'deviceMobile' => PhosphorIconsFill.deviceMobile,
  'television' => PhosphorIconsFill.television,
  'dress' => PhosphorIconsFill.dress,
  'tShirt' => PhosphorIconsFill.tShirt,
  'sneaker' => PhosphorIconsFill.sneaker,
  'sparkle' => PhosphorIconsFill.sparkle,
  'cookingPot' => PhosphorIconsFill.cookingPot,
  'basket' => PhosphorIconsFill.basket,
  'baby' => PhosphorIconsFill.baby,
  'wrench' => PhosphorIconsFill.wrench,
  'hammer' => PhosphorIconsFill.hammer,
  'notebook' => PhosphorIconsFill.notebook,
  _ => PhosphorIconsFill.tag,
};

class DiscoverTab extends StatefulWidget {
  const DiscoverTab({super.key});
  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> {
  List<dynamic>? _cats;
  List<dynamic>? _shops;
  String? _cat;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([Api.instance.categories(), Api.instance.shops(categoryId: _cat)]);
      if (mounted) setState(() { _cats = r[0]; _shops = r[1]; });
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (Api.instance.user?['name'] as String? ?? '').split(' ').first;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
        Text('Bonjour $name', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const Text('Que cherchez-vous à Adjamé aujourd’hui ?', style: TextStyle(color: AppColors.muted)),
        const SectionTitle('Catégories'),
        if (_cats == null)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.82,
            children: [
              for (final c in _cats!)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () { setState(() => _cat = _cat == c['id'] ? null : c['id'] as String); _load(); },
                  child: Column(children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(color: _cat == c['id'] ? AppColors.primary : Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: Icon(categoryIcon(c['icon'] as String?), color: _cat == c['id'] ? Colors.white : AppColors.primary),
                    ),
                    const SizedBox(height: 6),
                    Text(c['name'] as String, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5)),
                  ]),
                ),
            ],
          ),
        SectionTitle(_cat == null ? 'Boutiques' : 'Boutiques de la catégorie'),
        if (_shops == null)
          const SizedBox.shrink()
        else if (_shops!.isEmpty)
          const StatusBanner(icon: PhosphorIconsFill.storefront, color: AppColors.primary, title: 'Bientôt ici', text: 'Les premières boutiques d’Adjamé arrivent. Les produits et la commande seront disponibles prochainement.')
        else
          for (final s in _shops!)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: (s['logoUrl'] ?? s['storefrontUrl']) != null
                          ? Image.network(photoUrl((s['logoUrl'] ?? s['storefrontUrl']) as String), fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: AppColors.background))
                          : Container(color: AppColors.background, child: const Icon(PhosphorIconsFill.storefront, color: AppColors.primary)),
                    ),
                  ),
                  title: Text(s['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text([if (s['type'] == 'GROSSISTE') 'Grossiste', s['market']].whereType<String>().join(' · ')),
                  trailing: const Icon(PhosphorIconsBold.caretRight, size: 18),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopPage(slug: s['slug'] as String))),
                ),
              ),
            ),
      ]),
    );
  }
}
