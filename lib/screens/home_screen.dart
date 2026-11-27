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
import 'catalog_screen.dart';
import 'product_card.dart';
import 'search_screen.dart';
import 'shop_page.dart';
import 'shops_screen.dart';

/// Onglets : Accueil · Boutiques · Rechercher · Panier · Compte (ouvert à tous, connexion à la commande)
class HomeScreen extends StatefulWidget {
  final int initialTab;
  static const cartTab = 3;
  const HomeScreen({super.key, this.initialTab = 0});
  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  late int _tab = widget.initialTab;
  final _search = GlobalKey<SearchTabState>();
  void select(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBody: true,
    body: IndexedStack(index: _tab, children: [
      DiscoverTab(
        onSearch: () {
          select(2);
          WidgetsBinding.instance.addPostFrameCallback((_) => _search.currentState?.focus());
        },
        onShops: () => select(1),
        onAccount: () => select(4),
      ),
      const ShopsScreen(embedded: true),
      SearchTab(key: _search),
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
            _item(1, CupertinoIcons.building_2_fill, CupertinoIcons.building_2_fill, 'Boutiques'),
            _item(2, CupertinoIcons.search, CupertinoIcons.search, 'Rechercher'),
            _item(3, CupertinoIcons.bag, CupertinoIcons.bag_fill, 'Panier', badge: Cart.instance.count),
            _item(4, CupertinoIcons.person_crop_circle, CupertinoIcons.person_crop_circle_fill, 'Compte'),
          ]),
        ),
      ),
    ),
  );
}

/// Icône d'un rayon (nom Phosphor envoyé par l'API)
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
  'soccerBall' => PhosphorIconsRegular.soccerBall,
  _ => PhosphorIconsRegular.tag,
};

/// Couleurs de la marque, déclinées pour les rayons et les marchés
const brandTints = [Color(0xFF0B6B4F), Color(0xFFE8962A), Color(0xFF8E5B3A), Color(0xFF2F6F7E), Color(0xFFB05A4A), Color(0xFF5E6B3A)];

/// Logo Adjamé-Smart : pastille au motif wax + nom
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 34});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: SizedBox(
        width: size,
        height: size,
        child: WaxPattern(seed: 2, child: Center(child: Text('A', style: AppText.title1.copyWith(color: Colors.white, fontSize: size * 0.58, height: 1)))),
      ),
    ),
    const SizedBox(width: 9),
    Text.rich(TextSpan(children: [
      TextSpan(text: 'Adjamé', style: AppText.headline.copyWith(fontSize: 23, letterSpacing: -0.2)),
      TextSpan(text: 'Smart', style: AppText.headline.copyWith(fontSize: 23, letterSpacing: -0.2, color: AppColors.accent)),
    ])),
  ]);
}

class DiscoverTab extends StatefulWidget {
  final VoidCallback onSearch;
  final VoidCallback onShops;
  final VoidCallback onAccount;
  const DiscoverTab({super.key, required this.onSearch, required this.onShops, required this.onAccount});
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
    _home = Api.instance.peek('/products/home') as Map<String, dynamic>?;
    _load();
  }

  Future<void> _load({bool fresh = false}) async {
    try {
      final r = await Future.wait([Api.instance.categories(), Api.instance.home(fresh: fresh)]);
      if (mounted) setState(() { _cats = r[0] as List; _home = r[1] as Map<String, dynamic>; _failed = false; });
    } catch (e) {
      if (mounted && _home == null) setState(() => _failed = true);
    }
  }

  void _open(Widget w) => Navigator.push(context, CupertinoPageRoute(builder: (_) => w));

  String get _greeting {
    final h = DateTime.now().hour;
    final name = (Api.instance.user?['name'] as String?)?.split(' ').first;
    final hello = h < 5 || h >= 18 ? 'Bonsoir' : 'Bonjour';
    return name == null ? hello : '$hello $name';
  }

  Widget _hero(Map totals) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
    child: Pressable(
      onTap: widget.onShops,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: WaxPattern(
          ink: const Color(0x1FFFFFFF),
          accent: const Color(0x1FFFFFFF),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('LE MARCHÉ D’ADJAMÉ', style: AppText.overline.copyWith(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, letterSpacing: 0.6)),
              const SizedBox(height: 6),
              Text('Toutes les boutiques d’Adjamé, livrées chez vous.', style: AppText.title1.copyWith(color: Colors.white, fontSize: 25, height: 1.15)),
              const SizedBox(height: 16),
              Row(children: [
                _stat('${totals['shops'] ?? 0}', 'boutiques'),
                const SizedBox(width: 8),
                _stat('${totals['products'] ?? 0}', 'produits'),
                const Spacer(),
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                  child: Row(children: [
                    Text('Explorer', style: AppText.label.copyWith(color: AppColors.primary)),
                    const SizedBox(width: 4),
                    const Icon(CupertinoIcons.arrow_right, size: 15, color: AppColors.primary),
                  ]),
                ),
              ]),
            ]),
          ),
        ),
      ),
    ),
  );

  Widget _stat(String n, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(10)),
    child: Text.rich(TextSpan(children: [
      TextSpan(text: n, style: AppText.label.copyWith(color: Colors.white)),
      TextSpan(text: ' $label', style: AppText.caption.copyWith(color: Colors.white.withValues(alpha: 0.85))),
    ])),
  );

  /// Grille des rayons (4 colonnes) : les 7 premiers + « Tous les rayons »
  Widget _departments(List cats, Map counts) {
    final shown = cats.take(7).toList();
    Widget tile(Widget icon, Color tint, String name, String? sub, VoidCallback onTap) => Pressable(
      onTap: onTap,
      child: Column(children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(decoration: BoxDecoration(color: tint.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18)), child: Center(child: icon)),
        ),
        const SizedBox(height: 6),
        Text(name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: AppColors.ink, fontSize: 12, height: 1.2, fontWeight: FontWeight.w500)),
        if (sub != null) Text(sub, style: AppText.caption.copyWith(fontSize: 11)),
      ]),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        mainAxisSpacing: 14,
        crossAxisSpacing: 12,
        childAspectRatio: 0.62,
        children: [
          for (var i = 0; i < shown.length; i++)
            () {
              final c = shown[i] as Map;
              final tint = brandTints[i % brandTints.length];
              final n = (counts[c['id']] as num?)?.toInt();
              return tile(Icon(categoryIcon(c['icon'] as String?), color: tint, size: 30), tint, c['name'] as String, n == null || n == 0 ? null : '$n', () => _open(CatalogScreen(title: c['name'] as String, category: c)));
            }(),
          tile(const Icon(CupertinoIcons.square_grid_2x2, color: AppColors.ink, size: 28), AppColors.ink, 'Tous les rayons', '${cats.length}', widget.onSearch),
        ],
      ),
    );
  }

  Widget _featuredCard(Map s) => Pressable(
    onTap: () => _open(ShopPage(slug: s['slug'] as String)),
    child: SizedBox(
      width: 270,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(clipBehavior: Clip.none, children: [
          ClipRRect(borderRadius: BorderRadius.circular(16), child: AspectRatio(aspectRatio: 16 / 10, child: NetImage((s['storefrontUrl'] ?? s['logoUrl']) as String?, width: 270, placeholder: CupertinoIcons.building_2_fill))),
          Positioned(
            left: 12,
            bottom: -20,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.surface, width: 2.5), boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 10, offset: Offset(0, 3))]),
              child: ClipRRect(borderRadius: BorderRadius.circular(11), child: NetImage(s['logoUrl'] as String?, width: 48, placeholder: CupertinoIcons.building_2_fill)),
            ),
          ),
        ]),
        const SizedBox(height: 26),
        Text(s['name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title.copyWith(fontSize: 16)),
        Text([if (s['type'] == 'GROSSISTE') 'Grossiste', s['market'], '${s['productCount'] ?? 0} produits'].whereType<String>().join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
      ]),
    ),
  );

  Widget _marketCard(Map m, int i) => Pressable(
    onTap: () => _open(CatalogScreen(title: m['name'] as String, market: m['name'] as String)),
    child: SizedBox(
      width: 168,
      height: 116,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: WaxPattern(
          background: brandTints[(i + 3) % brandTints.length],
          accent: i.isEven ? AppColors.accent : Colors.white,
          seed: i * 3 + 1,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(m['name'] as String, maxLines: 2, style: AppText.title.copyWith(color: Colors.white, fontSize: 16, height: 1.15)),
              const SizedBox(height: 2),
              Text('${m['shops']} ${(m['shops'] as int) > 1 ? 'boutiques' : 'boutique'}', style: AppText.caption.copyWith(color: Colors.white.withValues(alpha: 0.85))),
            ]),
          ),
        ),
      ),
    ),
  );

  List<Widget> _skeleton() => [
    const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(16, 6, 16, 0), child: Skeleton(height: 168, radius: 22))),
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 30, 16, 0),
        child: Row(children: [for (var i = 0; i < 4; i++) ...[if (i > 0) const SizedBox(width: 12), const Expanded(child: AspectRatio(aspectRatio: 1, child: Skeleton(height: double.infinity, radius: 18)))]]),
      ),
    ),
    const SliverToBoxAdapter(child: SizedBox(height: 30)),
    const SliverPadding(padding: EdgeInsets.symmetric(horizontal: 16), sliver: ProductGridSkeleton()),
  ];

  @override
  Widget build(BuildContext context) {
    final h = _home;
    List list(String k) => (h?[k] as List?) ?? [];
    final featured = list('featuredShops');
    final markets = list('markets');
    final newShops = list('newShops');
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()), slivers: [
        CupertinoSliverRefreshControl(onRefresh: () => _load(fresh: true)),
        // En-tête de marque
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, top + 8, 8, 4),
            child: Row(children: [
              const BrandMark(),
              const Spacer(),
              CupertinoButton(padding: EdgeInsets.zero, minimumSize: const Size(44, 44), onPressed: widget.onAccount, child: const Icon(CupertinoIcons.person_crop_circle, size: 28, color: AppColors.primary)),
            ]),
          ),
        ),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 2, 20, 0), child: Text(_greeting, style: AppText.bodyMuted))),
        // Recherche collante
        SliverPersistentHeader(
          pinned: true,
          delegate: StickyHeader(
            height: 58,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: GestureDetector(
                onTap: widget.onSearch,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: const Color(0xFFEEEEEF), borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(CupertinoIcons.search, color: AppColors.muted, size: 19),
                    const SizedBox(width: 6),
                    Expanded(child: Text(((h?['totals']?['products'] as num?) ?? 0) > 0 ? 'Rechercher parmi ${h!['totals']['products']} produits' : 'Rechercher un produit, une boutique', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body.copyWith(color: AppColors.muted))),
                  ]),
                ),
              ),
            ),
          ),
        ),
        if (_failed)
          SliverToBoxAdapter(child: EmptyState(icon: CupertinoIcons.wifi_slash, title: 'Pas de connexion', text: 'Vérifiez votre connexion Internet puis réessayez.', action: 'Réessayer', onAction: _load))
        else if (h == null)
          ..._skeleton()
        else ...[
          SliverToBoxAdapter(child: _hero((h['totals'] as Map?) ?? {})),
          if ((_cats ?? []).isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader('Rayons', action: 'Tout voir', onAction: widget.onSearch)),
            SliverToBoxAdapter(child: _departments(_cats!, (h['categoryCounts'] as Map?) ?? {})),
          ],
          if (featured.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader('Boutiques à la une', action: 'Tout voir', onAction: widget.onShops)),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 248,
                child: ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 16), scrollDirection: Axis.horizontal, itemCount: featured.length, separatorBuilder: (_, _) => const SizedBox(width: 14), itemBuilder: (_, i) => _featuredCard(featured[i] as Map)),
              ),
            ),
          ],
          if (list('newProducts').isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader('Nouveautés', action: 'Tout voir', onAction: () => _open(const CatalogScreen(title: 'Nouveautés')))),
            SliverToBoxAdapter(child: ProductRail(list('newProducts'))),
          ],
          if (markets.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SectionHeader('Les marchés d’Adjamé')),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 116,
                child: ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 16), scrollDirection: Axis.horizontal, itemCount: markets.length, separatorBuilder: (_, _) => const SizedBox(width: 12), itemBuilder: (_, i) => _marketCard(markets[i] as Map, i)),
              ),
            ),
          ],
          if (list('cheapProducts').isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader('Petits prix', action: 'Tout voir', onAction: () => _open(const CatalogScreen(title: 'Petits prix', sort: 'popular', maxPrice: 5000)))),
            SliverToBoxAdapter(child: ProductRail(list('cheapProducts'))),
          ],
          if (list('wholesaleProducts').isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader('Vente en gros', action: 'Tout voir', onAction: () => _open(const CatalogScreen(title: 'Vente en gros', sort: 'popular', wholesale: true)))),
            SliverToBoxAdapter(child: ProductRail(list('wholesaleProducts'))),
          ],
          if (newShops.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader('Nouvelles boutiques', action: 'Toutes', onAction: widget.onShops)),
            SliverList.separated(itemCount: newShops.take(4).length, separatorBuilder: (_, _) => const Divider(indent: 88), itemBuilder: (_, i) => ShopRow(newShops[i] as Map)),
          ],
          if (list('popularProducts').isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader('Les plus vus', action: 'Tout voir', onAction: () => _open(const CatalogScreen(title: 'Les plus vus', sort: 'popular')))),
            SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 16), sliver: ProductSliverGrid(list('popularProducts').take(6).toList())),
          ],
          const SliverToBoxAdapter(child: SectionHeader('Acheter en toute sérénité')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Group(color: AppColors.surfaceAlt, dividerIndent: 60, children: const [
                Cell(leading: SettingsIcon(PhosphorIconsFill.moped), title: 'Livré par LETO', subtitle: 'Une course par boutique, frais payés au livreur'),
                Cell(leading: SettingsIcon(CupertinoIcons.creditcard, color: AppColors.accent), title: 'Paiement Mobile Money', subtitle: 'Colis remis une fois le paiement confirmé'),
                Cell(leading: SettingsIcon(CupertinoIcons.checkmark_shield_fill, color: Color(0xFF2F6F7E)), title: 'Boutiques vérifiées', subtitle: 'Chaque vendeur est contrôlé par notre équipe'),
              ]),
            ),
          ),
        ],
        SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.bottom + 90)),
      ]),
    );
  }
}
