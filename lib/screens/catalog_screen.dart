import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../catalog.dart';
import '../theme.dart';
import '../widgets.dart';
import 'product_card.dart';
import 'shop_page.dart';
import 'shops_screen.dart';

/// Liste de produits d'un rayon, d'un marché ou d'une collection : sous-rayons et filtres collants, boutiques du rayon
class CatalogScreen extends StatefulWidget {
  final String title;
  /// Rayon (avec « children ») : sous-rayons proposés en puces
  final Map? category;
  final String? market;
  final String sort;
  final bool wholesale;
  final int? maxPrice;
  const CatalogScreen({super.key, required this.title, this.category, this.market, this.sort = 'new', this.wholesale = false, this.maxPrice});
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  /// Critères qui définissent l'écran (non effaçables par « Effacer »)
  Map<String, String> _fixed([String? categoryId]) => {
    'categoryId': ?categoryId,
    'market': ?widget.market,
    if (widget.wholesale) 'wholesale': 'true',
    if (widget.maxPrice != null) 'maxPrice': '${widget.maxPrice}',
  };
  late final c = CatalogController(base: _fixed(widget.category?['id'] as String?), defaultSort: widget.sort);
  String? _sub;
  List<dynamic>? _shops;

  List<Map> get _children => ((widget.category?['children'] as List?) ?? []).cast<Map>();

  @override
  void initState() {
    super.initState();
    c.reload();
    _loadShops();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Future<void> _loadShops() async {
    if (widget.category == null && widget.market == null) return;
    try {
      final r = await Api.instance.shops({
        if (widget.category != null) 'categoryId': (_sub ?? widget.category!['id']) as String,
        'market': ?widget.market,
        'sort': 'popular',
        'limit': '12',
      });
      if (mounted) setState(() => _shops = r['items'] as List);
    } catch (_) {}
  }

  void _pickSub(String? id) {
    if (id == _sub) return;
    setState(() { _sub = id; _shops = null; });
    c.base = _fixed(id ?? widget.category!['id'] as String);
    c.reload();
    _loadShops();
  }

  Widget _subChip(String label, String? id) {
    final on = _sub == id;
    return Pressable(
      onTap: () => _pickSub(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: on ? AppColors.primary : AppColors.primarySoft, borderRadius: BorderRadius.circular(17)),
        child: Text(label, style: AppText.subhead.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: on ? Colors.white : AppColors.primary)),
      ),
    );
  }

  Widget _shopBubble(Map s) => Pressable(
    onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => ShopPage(slug: s['slug'] as String))),
    child: SizedBox(
      width: 76,
      child: Column(children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.line)),
          clipBehavior: Clip.antiAlias,
          child: NetImage((s['logoUrl'] ?? s['storefrontUrl']) as String?, width: 62, placeholder: CupertinoIcons.building_2_fill),
        ),
        const SizedBox(height: 6),
        Text(s['name'] as String, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: AppColors.ink, fontSize: 12, height: 1.2)),
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final kids = _children;
    final shops = _shops ?? [];
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) => loadMoreOnScroll(n, c),
        child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()), slivers: [
          LargeTitleBar(widget.title, background: AppColors.surface),
          CupertinoSliverRefreshControl(onRefresh: c.reload),
          if (shops.isNotEmpty) ...[
            SectionHeader(
              widget.market != null ? 'Boutiques du marché' : 'Boutiques du rayon',
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
              action: 'Tout voir',
              onAction: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => ShopsScreen(title: widget.title, market: widget.market, categoryId: widget.category == null ? null : (_sub ?? widget.category!['id']) as String))),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 104,
                child: ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 12), scrollDirection: Axis.horizontal, itemCount: shops.length, separatorBuilder: (_, _) => const SizedBox(width: 4), itemBuilder: (_, i) => _shopBubble(shops[i] as Map)),
              ),
            ),
          ].map((w) => w is SectionHeader ? SliverToBoxAdapter(child: w) : w),
          SliverPersistentHeader(
            pinned: true,
            delegate: StickyHeader(
              height: kids.isEmpty ? 50 : 92,
              child: Column(children: [
                if (kids.isNotEmpty)
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      scrollDirection: Axis.horizontal,
                      itemCount: kids.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => i == 0 ? _subChip('Tout', null) : _subChip(kids[i - 1]['name'] as String, kids[i - 1]['id'] as String),
                    ),
                  ),
                SizedBox(height: 50, child: CatalogFilterBar(c, showMarket: widget.market == null, showWholesale: !widget.wholesale)),
              ]),
            ),
          ),
          CatalogResults(c),
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.bottom + 24)),
        ]),
      ),
    );
  }
}
