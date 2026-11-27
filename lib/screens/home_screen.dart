import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../api.dart';
import '../cart.dart';
import '../theme.dart';
import '../widgets.dart';
import 'account_screen.dart';
import 'cart_screen.dart';
import 'product_card.dart';
import 'search_screen.dart';
import 'shop_page.dart';

/// Structure : Accueil · Rechercher · Panier · Compte (ouvert à tous, connexion à la commande)
class HomeScreen extends StatefulWidget {
  final int initialTab;
  const HomeScreen({super.key, this.initialTab = 0});
  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  late int _tab = widget.initialTab;
  void select(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: _tab, children: [
      DiscoverTab(onSearch: () => select(1)),
      const SearchScreen(embedded: true),
      CartScreen(onBrowse: () => select(0)),
      const AccountScreen(),
    ]),
    bottomNavigationBar: _NavBar(index: _tab, onTap: select),
  );
}

class _NavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _NavBar({required this.index, required this.onTap});

  Widget _item(int i, IconData icon, IconData active, String label, {int badge = 0}) {
    final on = index == i;
    return Expanded(
      child: Pressable(
        onTap: () => onTap(i),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(clipBehavior: Clip.none, children: [
              Icon(on ? active : icon, size: 25, color: on ? AppColors.ink : AppColors.faint),
              if (badge > 0)
                Positioned(
                  right: -9,
                  top: -5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.background, width: 1.5)),
                    child: Text('$badge', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Inter', fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
            ]),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: on ? FontWeight.w600 : FontWeight.w500, color: on ? AppColors.ink : AppColors.faint)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(color: AppColors.background, border: Border(top: BorderSide(color: AppColors.line))),
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
    child: ListenableBuilder(
      listenable: Cart.instance,
      builder: (_, _) => Row(children: [
        _item(0, PhosphorIconsRegular.house, PhosphorIconsFill.house, 'Accueil'),
        _item(1, PhosphorIconsRegular.magnifyingGlass, PhosphorIconsBold.magnifyingGlass, 'Rechercher'),
        _item(2, PhosphorIconsRegular.handbag, PhosphorIconsFill.handbag, 'Panier', badge: Cart.instance.count),
        _item(3, PhosphorIconsRegular.user, PhosphorIconsFill.user, 'Compte'),
      ]),
    ),
  );
}

/// Icône d'une catégorie (nom Phosphor envoyé par l'API)
IconData categoryIcon(String? name) => switch (name) {
  'deviceMobile' => PhosphorIconsLight.deviceMobile,
  'television' => PhosphorIconsLight.television,
  'dress' => PhosphorIconsLight.dress,
  'tShirt' => PhosphorIconsLight.tShirt,
  'sneaker' => PhosphorIconsLight.sneaker,
  'sparkle' => PhosphorIconsLight.sparkle,
  'cookingPot' => PhosphorIconsLight.cookingPot,
  'basket' => PhosphorIconsLight.basket,
  'baby' => PhosphorIconsLight.baby,
  'wrench' => PhosphorIconsLight.wrench,
  'hammer' => PhosphorIconsLight.hammer,
  'notebook' => PhosphorIconsLight.notebook,
  _ => PhosphorIconsLight.tag,
};

class DiscoverTab extends StatefulWidget {
  final VoidCallback onSearch;
  const DiscoverTab({super.key, required this.onSearch});
  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> {
  List<dynamic>? _cats;
  Map<String, dynamic>? _home;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([Api.instance.categories(), Api.instance.home()]);
      if (mounted) setState(() { _cats = r[0] as List; _home = r[1] as Map<String, dynamic>; _failed = false; });
    } catch (e) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _open(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));

  Widget _shopCard(Map s) => Pressable(
    onTap: () => _open(ShopPage(slug: s['slug'] as String)),
    child: SizedBox(
      width: 220,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(borderRadius: BorderRadius.circular(20), child: AspectRatio(aspectRatio: 4 / 3, child: NetImage((s['storefrontUrl'] ?? s['logoUrl']) as String?, placeholder: PhosphorIconsLight.storefront))),
        const SizedBox(height: 10),
        Text(s['name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title.copyWith(fontSize: 15.5)),
        const SizedBox(height: 2),
        Text([if (s['type'] == 'GROSSISTE') 'Grossiste', s['market']].whereType<String>().join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final fresh = (_home?['newProducts'] as List?) ?? [];
    final popular = (_home?['popularProducts'] as List?) ?? [];
    final featured = (_home?['featuredShops'] as List?) ?? [];
    final name = (Api.instance.user?['name'] as String?)?.split(' ').first;
    return RefreshIndicator(
      color: AppColors.ink,
      onRefresh: _load,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name == null ? 'ADJAMÉ-SMART' : 'BONJOUR ${name.toUpperCase()}', style: AppText.overline),
                const SizedBox(height: 8),
                const Text('Le marché d’Adjamé,\nlivré chez vous.', style: AppText.display),
                const SizedBox(height: 20),
                Pressable(
                  onTap: widget.onSearch,
                  child: Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(28), border: Border.all(color: AppColors.line)),
                    child: const Row(children: [
                      Icon(PhosphorIconsRegular.magnifyingGlass, color: AppColors.ink, size: 21),
                      SizedBox(width: 12),
                      Expanded(child: Text('Pagnes, téléphones, chaussures…', style: TextStyle(fontFamily: 'Inter', color: AppColors.faint, fontSize: 15))),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
        if (_failed)
          SliverToBoxAdapter(child: EmptyState(icon: PhosphorIconsLight.wifiSlash, title: 'Connexion impossible', text: 'Vérifiez votre connexion puis réessayez.', action: 'Réessayer', onAction: _load))
        else ...[
          // Catégories
          SliverToBoxAdapter(
            child: SizedBox(
              height: 128,
              child: _cats == null
                  ? const Center(child: CircularProgressIndicator(color: AppColors.ink, strokeWidth: 2))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      scrollDirection: Axis.horizontal,
                      itemCount: _cats!.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (_, i) {
                        final c = _cats![i] as Map;
                        return Pressable(
                          onTap: () => _open(SearchScreen(categoryId: c['id'] as String, categoryName: c['name'] as String)),
                          child: SizedBox(
                            width: 74,
                            child: Column(children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, border: Border.all(color: AppColors.line)),
                                child: Icon(categoryIcon(c['icon'] as String?), color: AppColors.ink, size: 26),
                              ),
                              const SizedBox(height: 8),
                              Text(c['name'] as String, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: AppColors.ink, fontWeight: FontWeight.w500, fontSize: 12, height: 1.25)),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
          ),
          // Bandeau éditorial
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(24)),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('LIVRAISON LETO', style: AppText.overline.copyWith(color: Colors.white70)),
                      const SizedBox(height: 6),
                      Text('Commandez dans plusieurs boutiques, recevez tout chez vous.', style: AppText.headline.copyWith(color: Colors.white, fontSize: 21)),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                    child: const Icon(PhosphorIconsFill.moped, color: Colors.white, size: 28),
                  ),
                ]),
              ),
            ),
          ),
          if (featured.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SectionHeader('Boutiques à la une')),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 232,
                child: ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 20), scrollDirection: Axis.horizontal, itemCount: featured.length, separatorBuilder: (_, _) => const SizedBox(width: 14), itemBuilder: (_, i) => _shopCard(featured[i] as Map)),
              ),
            ),
          ],
          if (fresh.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader('Nouveautés', action: 'Tout voir', onAction: () => _open(const SearchScreen(sort: 'new')))),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 300,
                child: ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 20), scrollDirection: Axis.horizontal, itemCount: fresh.length, separatorBuilder: (_, _) => const SizedBox(width: 14), itemBuilder: (_, i) => ProductCard(fresh[i] as Map, width: 170)),
              ),
            ),
          ],
          if (popular.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader('Les plus vus', action: 'Tout voir', onAction: () => _open(const SearchScreen(sort: 'popular')))),
            SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 20), sliver: ProductSliverGrid(popular.take(6).toList())),
          ],
          if (_home != null && fresh.isEmpty)
            const SliverToBoxAdapter(child: EmptyState(icon: PhosphorIconsLight.storefront, title: 'Bientôt ici', text: 'Les premières boutiques d’Adjamé ajoutent leurs produits.')),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ]),
    );
  }
}
