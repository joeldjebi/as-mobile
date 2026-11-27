import 'dart:ui';

import 'package:flutter/cupertino.dart';
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
    extendBody: true,
    body: IndexedStack(index: _tab, children: [
      DiscoverTab(onSearch: () => select(1), onAccount: () => select(3)),
      const SearchScreen(embedded: true),
      CartScreen(onBrowse: () => select(0)),
      const AccountScreen(),
    ]),
    bottomNavigationBar: _TabBar(index: _tab, onTap: select),
  );
}

/// Barre d'onglets translucide façon iOS
class _TabBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _TabBar({required this.index, required this.onTap});

  Widget _item(int i, IconData icon, IconData active, String label, {int badge = 0}) {
    final on = index == i;
    final color = on ? AppColors.primary : AppColors.muted;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(i),
        child: Padding(
          padding: const EdgeInsets.only(top: 7, bottom: 3),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(clipBehavior: Clip.none, children: [
              Icon(on ? active : icon, size: 25, color: color),
              if (badge > 0)
                Positioned(
                  right: -10,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(color: AppColors.badge, borderRadius: BorderRadius.circular(10)),
                    child: Text('$badge', textAlign: TextAlign.center, style: AppText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white, height: 1.35)),
                  ),
                ),
            ]),
            const SizedBox(height: 3),
            Text(label, style: AppText.caption.copyWith(fontSize: 10.5, fontWeight: FontWeight.w500, color: color, letterSpacing: 0.1)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFFF9F9F9).withValues(alpha: 0.84), border: const Border(top: BorderSide(color: AppColors.separator, width: 0.5))),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: ListenableBuilder(
          listenable: Cart.instance,
          builder: (_, _) => Row(children: [
            _item(0, CupertinoIcons.house, CupertinoIcons.house_fill, 'Accueil'),
            _item(1, CupertinoIcons.search, CupertinoIcons.search, 'Rechercher'),
            _item(2, CupertinoIcons.bag, CupertinoIcons.bag_fill, 'Panier', badge: Cart.instance.count),
            _item(3, CupertinoIcons.person_crop_circle, CupertinoIcons.person_crop_circle_fill, 'Compte'),
          ]),
        ),
      ),
    ),
  );
}

/// Icône d'une catégorie (nom Phosphor envoyé par l'API)
IconData categoryIcon(String? name) => switch (name) {
  'deviceMobile' => PhosphorIconsRegular.deviceMobile,
  'television' => PhosphorIconsRegular.television,
  'dress' => PhosphorIconsRegular.dress,
  'tShirt' => PhosphorIconsRegular.tShirt,
  'sneaker' => PhosphorIconsRegular.sneaker,
  'sparkle' => PhosphorIconsRegular.sparkle,
  'cookingPot' => PhosphorIconsRegular.cookingPot,
  'basket' => PhosphorIconsRegular.basket,
  'baby' => PhosphorIconsRegular.baby,
  'wrench' => PhosphorIconsRegular.wrench,
  'hammer' => PhosphorIconsRegular.hammer,
  'notebook' => PhosphorIconsRegular.notebook,
  _ => PhosphorIconsRegular.tag,
};

/// Couleur de pastille par catégorie (palette douce, façon Réglages)
const _catColors = [Color(0xFF0B6B4F), Color(0xFFE8962A), Color(0xFF8E5B3A), Color(0xFF2F6F7E), Color(0xFFB05A4A), Color(0xFF5E6B3A)];

class DiscoverTab extends StatefulWidget {
  final VoidCallback onSearch;
  final VoidCallback onAccount;
  const DiscoverTab({super.key, required this.onSearch, required this.onAccount});
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

  /// Grande carte « À la une » façon App Store
  Widget _hero(Map s) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Pressable(
      onTap: () => _open(ShopPage(slug: s['slug'] as String)),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 8))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(aspectRatio: 16 / 10, child: NetImage((s['storefrontUrl'] ?? s['logoUrl']) as String?, placeholder: CupertinoIcons.building_2_fill)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('BOUTIQUE À LA UNE', style: AppText.overline.copyWith(color: AppColors.primary, fontSize: 12)),
              const SizedBox(height: 4),
              Text(s['name'] as String, style: AppText.headline),
              const SizedBox(height: 2),
              Text([if (s['type'] == 'GROSSISTE') 'Grossiste', s['market'] ?? 'Adjamé'].whereType<String>().join(' · '), style: AppText.bodyMuted),
            ]),
          ),
        ]),
      ),
    ),
  );

  Widget _shopCard(Map s) => Pressable(
    onTap: () => _open(ShopPage(slug: s['slug'] as String)),
    child: SizedBox(
      width: 250,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(borderRadius: BorderRadius.circular(14), child: AspectRatio(aspectRatio: 16 / 10, child: NetImage((s['storefrontUrl'] ?? s['logoUrl']) as String?, placeholder: CupertinoIcons.building_2_fill))),
        const SizedBox(height: 8),
        Text(s['name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title.copyWith(fontSize: 16)),
        Text([if (s['type'] == 'GROSSISTE') 'Grossiste', s['market']].whereType<String>().join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
      ]),
    ),
  );

  Widget _category(Map c, int i) => Pressable(
    onTap: () => _open(SearchScreen(categoryId: c['id'] as String, categoryName: c['name'] as String)),
    child: SizedBox(
      width: 76,
      child: Column(children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(color: _catColors[i % _catColors.length].withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
          child: Icon(categoryIcon(c['icon'] as String?), color: _catColors[i % _catColors.length], size: 28),
        ),
        const SizedBox(height: 7),
        Text(c['name'] as String, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: AppColors.ink, fontSize: 12, height: 1.2)),
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final fresh = (_home?['newProducts'] as List?) ?? [];
    final popular = (_home?['popularProducts'] as List?) ?? [];
    final featured = (_home?['featuredShops'] as List?) ?? [];
    final bottom = MediaQuery.of(context).padding.bottom + 70;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()), slivers: [
        LargeTitleBar(
          'Accueil',
          background: AppColors.surface,
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(44, 44),
            onPressed: widget.onAccount,
            child: const Icon(CupertinoIcons.person_crop_circle, size: 28, color: AppColors.primary),
          ),
        ),
        CupertinoSliverRefreshControl(onRefresh: _load),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: GestureDetector(
              onTap: widget.onSearch,
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(color: const Color(0xFFEEEEEF), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(CupertinoIcons.search, color: AppColors.muted, size: 19),
                  const SizedBox(width: 6),
                  Text('Pagnes, téléphones, chaussures…', style: AppText.body.copyWith(color: AppColors.muted)),
                ]),
              ),
            ),
          ),
        ),
        if (_failed)
          SliverToBoxAdapter(child: EmptyState(icon: CupertinoIcons.wifi_slash, title: 'Pas de connexion', text: 'Vérifiez votre connexion Internet puis réessayez.', action: 'Réessayer', onAction: _load))
        else if (_home == null)
          const SliverToBoxAdapter(child: Loader(padding: 60))
        else ...[
          if (featured.isNotEmpty) SliverToBoxAdapter(child: _hero(featured.first as Map)),
          if ((_cats ?? []).isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader('Catégories', action: 'Tout voir', onAction: widget.onSearch)),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 108,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: _cats!.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 4),
                  itemBuilder: (_, i) => _category(_cats![i] as Map, i),
                ),
              ),
            ),
          ],
          if (fresh.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader('Nouveautés', action: 'Tout voir', onAction: () => _open(const SearchScreen(sort: 'new')))),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 292,
                child: ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 16), scrollDirection: Axis.horizontal, itemCount: fresh.length, separatorBuilder: (_, _) => const SizedBox(width: 12), itemBuilder: (_, i) => ProductCard(fresh[i] as Map, width: 160)),
              ),
            ),
          ],
          if (featured.length > 1) ...[
            const SliverToBoxAdapter(child: SectionHeader('Boutiques à la une')),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 212,
                child: ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 16), scrollDirection: Axis.horizontal, itemCount: featured.length - 1, separatorBuilder: (_, _) => const SizedBox(width: 12), itemBuilder: (_, i) => _shopCard(featured[i + 1] as Map)),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SectionHeader('Acheter en toute sérénité')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Group(color: AppColors.surfaceAlt, dividerIndent: 60, children: [
                Cell(leading: const SettingsIcon(PhosphorIconsFill.moped), title: 'Livré par LETO', subtitle: 'Une course par boutique, frais payés au livreur'),
                Cell(leading: const SettingsIcon(CupertinoIcons.creditcard, color: AppColors.accent), title: 'Paiement Mobile Money', subtitle: 'Colis remis une fois le paiement confirmé'),
                Cell(leading: const SettingsIcon(CupertinoIcons.checkmark_shield_fill, color: Color(0xFF2F6F7E)), title: 'Boutiques vérifiées', subtitle: 'Chaque vendeur est contrôlé par notre équipe'),
              ]),
            ),
          ),
          if (popular.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader('Les plus vus', action: 'Tout voir', onAction: () => _open(const SearchScreen(sort: 'popular')))),
            SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 16), sliver: ProductSliverGrid(popular.take(6).toList())),
          ],
          if (fresh.isEmpty)
            const SliverToBoxAdapter(child: EmptyState(icon: CupertinoIcons.bag, title: 'Bientôt ici', text: 'Les premières boutiques d’Adjamé ajoutent leurs produits.')),
        ],
        SliverToBoxAdapter(child: SizedBox(height: bottom + 16)),
      ]),
    );
  }
}
