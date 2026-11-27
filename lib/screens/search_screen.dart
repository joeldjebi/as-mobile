import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../catalog.dart';
import '../theme.dart';
import '../widgets.dart';
import 'catalog_screen.dart';
import 'home_screen.dart' show categoryIcon;
import 'product_card.dart';
import 'product_screen.dart';
import 'shop_page.dart';
import 'shops_screen.dart';

/// Onglet Rechercher : suggestions pendant la frappe, recherches récentes, rayons ; résultats produits ou boutiques
class SearchTab extends StatefulWidget {
  const SearchTab({super.key});
  @override
  State<SearchTab> createState() => SearchTabState();
}

class SearchTabState extends State<SearchTab> {
  final _q = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  Map<String, dynamic>? _suggest;
  List<String> _recent = [];
  List<dynamic> _cats = [];
  /// Recherche validée (résultats affichés)
  String? _submitted;
  bool _shopsMode = false;
  final _catalog = CatalogController(defaultSort: 'popular');
  List<dynamic>? _shopResults;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _recent = p.getStringList('recent_searches') ?? []);
    });
    Api.instance.categories().then((c) => mounted ? setState(() => _cats = c) : null).catchError((_) => null);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    _focus.dispose();
    _catalog.dispose();
    super.dispose();
  }

  /// Place le curseur dans la recherche (appelé depuis l'accueil)
  void focus() => _focus.requestFocus();

  void _onChanged(String v) {
    if (_submitted != null) setState(() => _submitted = null);
    _debounce?.cancel();
    if (v.trim().length < 2) {
      setState(() => _suggest = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 220), () async {
      try {
        final r = await Api.instance.suggest(v.trim());
        if (mounted && _q.text.trim() == v.trim()) setState(() => _suggest = r);
      } catch (_) {}
    });
  }

  Future<void> _submit(String v) async {
    final q = v.trim();
    if (q.isEmpty) return;
    _q.text = q;
    _focus.unfocus();
    final p = await SharedPreferences.getInstance();
    _recent = [q, ..._recent.where((x) => x.toLowerCase() != q.toLowerCase())].take(8).toList();
    await p.setStringList('recent_searches', _recent);
    setState(() { _submitted = q; _shopResults = null; });
    _catalog.base = {'q': q};
    _catalog.reload();
    Api.instance.shops({'q': q, 'limit': '24'}).then((r) {
      if (mounted && _submitted == q) setState(() => _shopResults = r['items'] as List);
    }).catchError((_) {
      if (mounted) setState(() => _shopResults = []);
    });
  }

  Future<void> _clearRecent() async {
    (await SharedPreferences.getInstance()).remove('recent_searches');
    setState(() => _recent = []);
  }

  void _push(Widget w) => Navigator.push(context, CupertinoPageRoute(builder: (_) => w));

  List<Widget> _idle() => [
    if (_recent.isNotEmpty) ...[
      SliverToBoxAdapter(child: SectionHeader('Récentes', action: 'Effacer', onAction: _clearRecent, padding: const EdgeInsets.fromLTRB(20, 18, 12, 6))),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final r in _recent) FilterPill(r, icon: CupertinoIcons.clock, dropdown: false, onTap: () => _submit(r)),
          ]),
        ),
      ),
    ],
    if (_cats.isNotEmpty) ...[
      const SliverToBoxAdapter(child: SectionHeader('Parcourir les rayons')),
      SliverList.separated(
        itemCount: _cats.length,
        separatorBuilder: (_, _) => const Divider(indent: 62),
        itemBuilder: (_, i) {
          final c = _cats[i] as Map;
          final kids = ((c['children'] as List?) ?? []).map((k) => k['name']).take(3).join(', ');
          return Cell(
            leading: Icon(categoryIcon(c['icon'] as String?), color: AppColors.primary, size: 26),
            title: c['name'] as String,
            subtitle: kids,
            onTap: () => _push(CatalogScreen(title: c['name'] as String, category: c)),
          );
        },
      ),
    ],
  ];

  List<Widget> _suggestions() {
    final s = _suggest ?? {};
    final cats = (s['categories'] as List?) ?? [];
    final shops = (s['shops'] as List?) ?? [];
    final products = (s['products'] as List?) ?? [];
    return [
      SliverToBoxAdapter(
        child: Cell(
          leading: const Icon(CupertinoIcons.search, color: AppColors.primary, size: 22),
          title: 'Rechercher « ${_q.text.trim()} »',
          titleColor: AppColors.primary,
          onTap: () => _submit(_q.text),
        ),
      ),
      if (cats.isNotEmpty) ...[
        const SliverToBoxAdapter(child: SectionTitle('Rayons')),
        SliverList.builder(
          itemCount: cats.length,
          itemBuilder: (_, i) {
            final c = cats[i] as Map;
            return Cell(
              leading: Icon(categoryIcon(c['icon'] as String?), color: AppColors.primary, size: 24),
              title: c['name'] as String,
              subtitle: c['parentName'] as String?,
              onTap: () {
                final full = _cats.cast<Map>().where((x) => x['id'] == c['id']).firstOrNull;
                _push(CatalogScreen(title: c['name'] as String, category: full ?? c));
              },
            );
          },
        ),
      ],
      if (shops.isNotEmpty) ...[
        const SliverToBoxAdapter(child: SectionTitle('Boutiques')),
        SliverList.builder(
          itemCount: shops.length,
          itemBuilder: (_, i) {
            final b = shops[i] as Map;
            return Cell(
              leading: ClipRRect(borderRadius: BorderRadius.circular(9), child: SizedBox(width: 36, height: 36, child: NetImage(b['logoUrl'] as String?, width: 36, placeholder: CupertinoIcons.building_2_fill))),
              title: b['name'] as String,
              subtitle: b['market'] as String?,
              onTap: () => _push(ShopPage(slug: b['slug'] as String)),
            );
          },
        ),
      ],
      if (products.isNotEmpty) ...[
        const SliverToBoxAdapter(child: SectionTitle('Produits')),
        SliverList.builder(
          itemCount: products.length,
          itemBuilder: (_, i) {
            final p = products[i] as Map;
            return Cell(
              leading: ClipRRect(borderRadius: BorderRadius.circular(9), child: SizedBox(width: 36, height: 36, child: NetImage(p['photo'] as String?, width: 36))),
              title: p['name'] as String,
              value: formatMoney(p['price'] as num),
              onTap: () => _push(ProductScreen(id: p['id'] as String)),
            );
          },
        ),
      ],
    ];
  }

  List<Widget> _results() => [
    SliverPersistentHeader(
      pinned: true,
      delegate: StickyHeader(
        height: _shopsMode ? 52 : 102,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<bool>(
                groupValue: _shopsMode,
                children: {
                  false: Text(_catalog.loaded ? 'Produits (${_catalog.total})' : 'Produits'),
                  true: Text(_shopResults == null ? 'Boutiques' : 'Boutiques (${_shopResults!.length})'),
                },
                onValueChanged: (v) => setState(() => _shopsMode = v ?? false),
              ),
            ),
          ),
          if (!_shopsMode) SizedBox(height: 50, child: CatalogFilterBar(_catalog)),
        ]),
      ),
    ),
    if (_shopsMode) ...[
      if (_shopResults == null)
        SliverList.builder(itemCount: 4, itemBuilder: (_, _) => const ShopRowSkeleton())
      else if (_shopResults!.isEmpty)
        SliverToBoxAdapter(child: EmptyState(icon: CupertinoIcons.building_2_fill, title: 'Aucune boutique', text: 'Aucune boutique ne correspond à « $_submitted ».'))
      else
        SliverList.separated(itemCount: _shopResults!.length, separatorBuilder: (_, _) => const Divider(indent: 88), itemBuilder: (_, i) => ShopRow(_shopResults![i] as Map)),
    ] else
      CatalogResults(_catalog, emptyText: 'Aucun résultat pour « $_submitted ». Vérifiez l’orthographe ou essayez un autre mot.'),
  ];

  @override
  Widget build(BuildContext context) {
    final typing = _submitted == null && _q.text.trim().length >= 2;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollStartNotification && n.dragDetails != null) _focus.unfocus();
          return _submitted != null && !_shopsMode ? loadMoreOnScroll(n, _catalog) : false;
        },
        child: ListenableBuilder(
          listenable: _catalog,
          builder: (context, _) => CustomScrollView(physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()), slivers: [
            const LargeTitleBar('Rechercher', background: AppColors.surface),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: CupertinoSearchTextField(
                  controller: _q,
                  focusNode: _focus,
                  placeholder: 'Produits, boutiques, rayons',
                  style: AppText.body,
                  onChanged: _onChanged,
                  onSubmitted: _submit,
                  onSuffixTap: () {
                    _q.clear();
                    setState(() { _submitted = null; _suggest = null; });
                  },
                ),
              ),
            ),
            ...(_submitted != null ? _results() : typing ? _suggestions() : _idle()),
            SliverToBoxAdapter(child: SizedBox(height: tabBarHeight(context) + 20)),
          ]),
        ),
      ),
    );
  }
}
