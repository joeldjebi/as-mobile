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

/// Barre d'onglets flottante en verre (style iOS 26) + bouton de recherche rond séparé
class _TabBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _TabBar({required this.index, required this.onTap});

  Widget _item(int i, IconData icon, IconData active, String label, {int badge = 0}) {
    final on = index == i;
    final color = on ? AppColors.primary : AppColors.ink.withValues(alpha: 0.72);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: on ? AppColors.primary.withValues(alpha: 0.11) : Colors.transparent, borderRadius: BorderRadius.circular(24)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Stack(clipBehavior: Clip.none, children: [
              Icon(on ? active : icon, size: 21, color: color),
              if (badge > 0)
                Positioned(
                  right: -9,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 0.5),
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(9)),
                    child: Text('$badge', textAlign: TextAlign.center, style: AppText.caption.copyWith(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white, height: 1.4)),
                  ),
                ),
            ]),
            const SizedBox(height: 2),
            Text(label, style: AppText.caption.copyWith(fontSize: 10, fontWeight: on ? FontWeight.w600 : FontWeight.w500, color: color, letterSpacing: 0)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = MediaQuery.of(context).padding.bottom;
    final searchOn = index == 2;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, b > 0 ? b - 6 : 12),
      child: SizedBox(
        height: 58,
        child: Row(children: [
          Expanded(
            child: Glass(
              radius: BorderRadius.circular(29),
              child: ListenableBuilder(
                listenable: Cart.instance,
                builder: (_, _) => Row(children: [
                  _item(0, CupertinoIcons.house, CupertinoIcons.house_fill, 'Accueil'),
                  _item(1, CupertinoIcons.building_2_fill, CupertinoIcons.building_2_fill, 'Boutiques'),
                  _item(3, CupertinoIcons.bag, CupertinoIcons.bag_fill, 'Panier', badge: Cart.instance.count),
                  _item(4, CupertinoIcons.person_crop_circle, CupertinoIcons.person_crop_circle_fill, 'Compte'),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => onTap(2),
            child: SizedBox(
              width: 58,
              height: 58,
              child: Glass(
                radius: BorderRadius.circular(29),
                opacity: searchOn ? 0.0 : 0.72,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  decoration: BoxDecoration(color: searchOn ? AppColors.primary : Colors.transparent, shape: BoxShape.circle),
                  child: Icon(CupertinoIcons.search, size: 22, color: searchOn ? Colors.white : AppColors.ink),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
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
      TextSpan(text: 'Adjamé', style: AppText.headline.copyWith(fontSize: 20, letterSpacing: -0.2)),
      TextSpan(text: 'Smart', style: AppText.headline.copyWith(fontSize: 20, letterSpacing: -0.2, color: AppColors.accent)),
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('LE MARCHÉ D’ADJAMÉ', style: AppText.overline.copyWith(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, letterSpacing: 0.6)),
              const SizedBox(height: 6),
              Text('Toutes les boutiques d’Adjamé, livrées chez vous.', style: AppText.title1.copyWith(color: Colors.white, fontSize: 20, height: 1.18)),
              const SizedBox(height: 12),
              Row(children: [
                _stat('${totals['shops'] ?? 0}', 'boutiques'),
                const SizedBox(width: 8),
                _stat('${totals['products'] ?? 0}', 'produits'),
                const Spacer(),
                Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
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

  /// Rayons en rangée compacte (pastille teintée + nom)
  Widget _departments(List cats, Map counts) => SizedBox(
    height: 86,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      scrollDirection: Axis.horizontal,
      itemCount: cats.length,
      separatorBuilder: (_, _) => const SizedBox(width: 2),
      itemBuilder: (_, i) {
        final c = cats[i] as Map;
        final tint = brandTints[i % brandTints.length];
        return Pressable(
          onTap: () => _open(CatalogScreen(title: c['name'] as String, category: c)),
          child: SizedBox(
            width: 68,
            child: Column(children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(color: tint.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(categoryIcon(c['icon'] as String?), color: tint, size: 23),
              ),
              const SizedBox(height: 6),
              Text((c['name'] as String).split(' et ').first, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: AppColors.ink, fontSize: 11, height: 1.15, fontWeight: FontWeight.w500)),
            ]),
          ),
        );
      },
    ),
  );

  /// Collections en « bento » : une grande tuile photo, deux tuiles motif
  Widget _bento(Map h) {
    final fresh = (h['newProducts'] as List?) ?? [];
    final photo = fresh.isEmpty ? null : ((fresh.first as Map)['photos'] as List?)?.firstOrNull as String?;
    Widget label(String title, String sub, {bool dark = false}) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(title, style: AppText.title.copyWith(fontSize: 15, color: dark ? AppColors.ink : Colors.white)),
      Text(sub, style: AppText.caption.copyWith(fontSize: 11, color: dark ? AppColors.muted : Colors.white.withValues(alpha: 0.85))),
    ]);
    Widget tile({required Widget background, required Widget child, required VoidCallback onTap}) => Pressable(
      onTap: onTap,
      child: ClipRRect(borderRadius: BorderRadius.circular(20), child: Stack(fit: StackFit.expand, children: [background, Padding(padding: const EdgeInsets.all(10), child: child)])),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: SizedBox(
        height: 214,
        child: Row(children: [
          Expanded(
            flex: 11,
            child: tile(
              background: photo == null ? const WaxPattern(seed: 5) : NetImage(photo, width: 200),
              onTap: () => _open(const CatalogScreen(title: 'Nouveautés')),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Glass(radius: BorderRadius.circular(14), opacity: 0.8, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7), child: label('Nouveautés', '${fresh.length} cette semaine', dark: true))),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 9,
            child: Column(children: [
              Expanded(
                child: tile(
                  background: const WaxPattern(background: AppColors.accent, accent: Color(0x40FFFFFF), seed: 3),
                  onTap: () => _open(const CatalogScreen(title: 'Petits prix', sort: 'popular', maxPrice: 5000)),
                  child: Align(alignment: Alignment.bottomLeft, child: label('Petits prix', 'Jusqu’à 5 000 F')),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: tile(
                  background: const WaxPattern(background: Color(0xFF2F6F7E), seed: 7),
                  onTap: () => _open(const CatalogScreen(title: 'Vente en gros', sort: 'popular', wholesale: true)),
                  child: Align(alignment: Alignment.bottomLeft, child: label('Vente en gros', 'Prix revendeurs')),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _featuredCard(Map s) => Pressable(
    onTap: () => _open(ShopPage(slug: s['slug'] as String)),
    child: SizedBox(
      width: 236,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(clipBehavior: Clip.none, children: [
          ClipRRect(borderRadius: BorderRadius.circular(16), child: AspectRatio(aspectRatio: 16 / 10, child: NetImage((s['storefrontUrl'] ?? s['logoUrl']) as String?, width: 236, placeholder: CupertinoIcons.building_2_fill))),
          Positioned(
            left: 12,
            bottom: -20,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.surface, width: 2.5), boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 10, offset: Offset(0, 3))]),
              child: ClipRRect(borderRadius: BorderRadius.circular(11), child: NetImage(s['logoUrl'] as String?, width: 48, placeholder: CupertinoIcons.building_2_fill)),
            ),
          ),
        ]),
        const SizedBox(height: 24),
        Text(s['name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title.copyWith(fontSize: 14.5)),
        Text([if (s['type'] == 'GROSSISTE') 'Grossiste', s['market'], '${s['productCount'] ?? 0} produits'].whereType<String>().join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
      ]),
    ),
  );

  Widget _marketCard(Map m, int i) => Pressable(
    onTap: () => _open(CatalogScreen(title: m['name'] as String, market: m['name'] as String)),
    child: SizedBox(
      width: 148,
      height: 100,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: WaxPattern(
          background: brandTints[(i + 3) % brandTints.length],
          accent: i.isEven ? AppColors.accent : Colors.white,
          seed: i * 3 + 1,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(m['name'] as String, maxLines: 2, style: AppText.title.copyWith(color: Colors.white, fontSize: 14, height: 1.15)),
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
              const BrandMark(size: 30),
              const Spacer(),
              CupertinoButton(padding: EdgeInsets.zero, minimumSize: const Size(44, 44), onPressed: widget.onAccount, child: const Icon(CupertinoIcons.person_crop_circle, size: 25, color: AppColors.primary)),
            ]),
          ),
        ),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 2, 20, 0), child: Text(_greeting, style: AppText.bodyMuted))),
        // Recherche collante
        SliverPersistentHeader(
          pinned: true,
          delegate: StickyHeader(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: GestureDetector(
                onTap: widget.onSearch,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: const Color(0xFFEEEEEF), borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(CupertinoIcons.search, color: AppColors.muted, size: 17),
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
          const SliverToBoxAdapter(child: SectionHeader('Sélections')),
          SliverToBoxAdapter(child: _bento(h)),
          if (featured.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader('Boutiques à la une', action: 'Tout voir', onAction: widget.onShops)),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 220,
                child: ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 16), scrollDirection: Axis.horizontal, itemCount: featured.length, separatorBuilder: (_, _) => const SizedBox(width: 12), itemBuilder: (_, i) => _featuredCard(featured[i] as Map)),
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
                height: 100,
                child: ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 16), scrollDirection: Axis.horizontal, itemCount: markets.length, separatorBuilder: (_, _) => const SizedBox(width: 12), itemBuilder: (_, i) => _marketCard(markets[i] as Map, i)),
              ),
            ),
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
                Cell(leading: SettingsIcon(PhosphorIconsFill.moped), title: 'Livré par VITE', subtitle: 'Une course par boutique, frais payés au livreur'),
                Cell(leading: SettingsIcon(CupertinoIcons.creditcard, color: AppColors.accent), title: 'Paiement Mobile Money', subtitle: 'Colis remis une fois le paiement confirmé'),
                Cell(leading: SettingsIcon(CupertinoIcons.checkmark_shield_fill, color: Color(0xFF2F6F7E)), title: 'Boutiques vérifiées', subtitle: 'Chaque vendeur est contrôlé par notre équipe'),
              ]),
            ),
          ),
        ],
        SliverToBoxAdapter(child: SizedBox(height: tabBarHeight(context) + 20)),
      ]),
    );
  }
}
