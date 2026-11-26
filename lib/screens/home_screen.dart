import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets.dart';
import 'account_screen.dart';
import 'product_card.dart';
import 'search_screen.dart';
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
    body: SafeArea(
      child: IndexedStack(
        index: _tab,
        children: const [DiscoverTab(), AccountScreen()],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (i) => setState(() => _tab = i),
      destinations: const [
        NavigationDestination(
          icon: Icon(PhosphorIconsBold.storefront),
          selectedIcon: Icon(PhosphorIconsFill.storefront),
          label: 'Découvrir',
        ),
        NavigationDestination(
          icon: Icon(PhosphorIconsBold.userCircle),
          selectedIcon: Icon(PhosphorIconsFill.userCircle),
          label: 'Compte',
        ),
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
  Map<String, dynamic>? _home;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([
        Api.instance.categories(),
        Api.instance.home(),
      ]);
      if (mounted) {
        setState(() {
          _cats = r[0] as List;
          _home = r[1] as Map<String, dynamic>;
        });
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _open(Widget w) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => w));

  Widget _shopTile(Map s) => SizedBox(
    width: 150,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _open(ShopPage(slug: s['slug'] as String)),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: (s['storefrontUrl'] ?? s['logoUrl']) != null
                  ? Image.network(
                      photoUrl((s['storefrontUrl'] ?? s['logoUrl']) as String),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Container(color: AppColors.background),
                    )
                  : Container(
                      color: AppColors.background,
                      child: const Icon(
                        PhosphorIconsFill.storefront,
                        color: AppColors.primary,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s['name'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    [
                      if (s['type'] == 'GROSSISTE') 'Grossiste',
                      s['market'],
                    ].whereType<String>().join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final name = (Api.instance.user?['name'] as String? ?? '').split(' ').first;
    final fresh = (_home?['newProducts'] as List?) ?? [];
    final popular = (_home?['popularProducts'] as List?) ?? [];
    final featured = (_home?['featuredShops'] as List?) ?? [];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            'Bonjour $name',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const Text(
            'Que cherchez-vous à Adjamé aujourd’hui ?',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _open(const SearchScreen(autofocus: true)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    PhosphorIconsBold.magnifyingGlass,
                    color: AppColors.muted,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Rechercher un produit, une boutique…',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
          const SectionTitle('Catégories'),
          if (_cats == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
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
                    onTap: () => _open(
                      SearchScreen(
                        categoryId: c['id'] as String,
                        categoryName: c['name'] as String,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            categoryIcon(c['icon'] as String?),
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          c['name'] as String,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          if (featured.isNotEmpty) ...[
            const SectionTitle('Boutiques à la une'),
            SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: featured.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _shopTile(featured[i] as Map),
              ),
            ),
          ],
          if (fresh.isNotEmpty) ...[
            const SectionTitle('Nouveautés'),
            SizedBox(
              height: 250,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: fresh.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => ProductCard(fresh[i] as Map, width: 160),
              ),
            ),
          ],
          if (popular.isNotEmpty) ...[
            const SectionTitle('Populaires'),
            ProductGrid(popular.take(6).toList()),
          ],
          if (_home != null && fresh.isEmpty)
            const StatusBanner(
              icon: PhosphorIconsFill.storefront,
              color: AppColors.primary,
              title: 'Bientôt ici',
              text: 'Les premières boutiques d’Adjamé ajoutent leurs produits.',
            ),
        ],
      ),
    );
  }
}
