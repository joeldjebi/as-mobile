import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets.dart';
import 'shop_page.dart';

const _shopSorts = {'name': 'Recommandées', 'popular': 'Plus de produits', 'new': 'Nouvelles'};

/// Annuaire des boutiques : recherche, marchés, boutiques ou grossistes, tri ; chargé par pages
class ShopsScreen extends StatefulWidget {
  final bool embedded;
  final String title;
  final String? market;
  final String? categoryId;
  const ShopsScreen({super.key, this.embedded = false, this.title = 'Boutiques', this.market, this.categoryId});
  @override
  State<ShopsScreen> createState() => _ShopsScreenState();
}

class _ShopsScreenState extends State<ShopsScreen> {
  final _q = TextEditingController();
  Timer? _debounce;
  late String? _market = widget.market;
  String? _type;
  String _sort = 'name';
  Map<String, dynamic> _markets = {};
  final List<dynamic> _items = [];
  int _page = 0;
  int _pages = 1;
  int _total = 0;
  bool _loading = false;
  bool _loaded = false;
  bool _failed = false;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _reload();
    if (widget.market == null) {
      Api.instance.shopsMeta().then((m) {
        if (mounted) setState(() => _markets = ((m['marketCounts'] as Map?) ?? {}).cast<String, dynamic>());
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    _gen++;
    setState(() { _items.clear(); _page = 0; _pages = 1; _loaded = false; _failed = false; _loading = false; });
    await _more();
  }

  Future<void> _more() async {
    if (_loading || _page >= _pages) return;
    final gen = _gen;
    setState(() => _loading = true);
    try {
      final r = await Api.instance.shops({
        if (_q.text.trim().isNotEmpty) 'q': _q.text.trim(),
        'market': ?_market,
        'type': ?_type,
        'categoryId': ?widget.categoryId,
        'sort': _sort,
        'page': '${_page + 1}',
        'limit': '24',
      });
      if (!mounted || gen != _gen) return;
      setState(() {
        _items.addAll(r['items'] as List);
        _page = r['page'] as int;
        _pages = r['pages'] as int;
        _total = r['total'] as int;
        _loaded = true;
      });
    } catch (_) {
      if (mounted && gen == _gen) setState(() => _failed = true);
    } finally {
      if (mounted && gen == _gen) setState(() => _loading = false);
    }
  }

  void _onQuery(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _reload);
  }

  Future<void> _pickSort() async {
    final v = await showCupertinoModalPopup<String>(
      context: context,
      builder: (p) => CupertinoActionSheet(
        title: const Text('Trier les boutiques'),
        actions: [for (final e in _shopSorts.entries) CupertinoActionSheetAction(onPressed: () => Navigator.pop(p, e.key), child: Text(e.key == _sort ? '${e.value}  ✓' : e.value))],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(p), child: const Text('Annuler')),
      ),
    );
    if (v != null && v != _sort) {
      _sort = v;
      _reload();
    }
  }

  Widget _marketChip(String label, String? value, [int? n]) {
    final on = _market == value;
    return Pressable(
      onTap: () {
        if (on) return;
        _market = value;
        _reload();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: on ? AppColors.primary : AppColors.primarySoft, borderRadius: BorderRadius.circular(17)),
        child: Text(n == null ? label : '$label  $n', style: AppText.subhead.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: on ? Colors.white : AppColors.primary)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final markets = _markets.keys.toList()..sort();
    final showMarkets = widget.market == null && markets.isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.axis == Axis.vertical && n.metrics.pixels > n.metrics.maxScrollExtent - 700) _more();
          return false;
        },
        child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()), slivers: [
          LargeTitleBar(widget.title, background: AppColors.surface, trailing: BarButton('Trier', onTap: _pickSort)),
          CupertinoSliverRefreshControl(onRefresh: _reload),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: CupertinoSearchTextField(controller: _q, placeholder: 'Nom, marché, allée…', style: AppText.body, onChanged: _onQuery, onSubmitted: (_) => _reload()),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: StickyHeader(
              height: showMarkets ? 98 : 56,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoSlidingSegmentedControl<String>(
                      groupValue: _type ?? 'ALL',
                      children: const {'ALL': Text('Toutes'), 'BOUTIQUE': Text('Boutiques'), 'GROSSISTE': Text('Grossistes')},
                      onValueChanged: (v) {
                        _type = v == 'ALL' ? null : v;
                        _reload();
                      },
                    ),
                  ),
                ),
                if (showMarkets)
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      children: [
                        _marketChip('Tous les marchés', null),
                        for (final m in markets) ...[const SizedBox(width: 8), _marketChip(m, m, _markets[m] as int?)],
                      ],
                    ),
                  ),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(_loaded ? '$_total ${_total > 1 ? 'boutiques' : 'boutique'} · ${_shopSorts[_sort]}' : ' ', style: AppText.caption),
            ),
          ),
          if (!_loaded && _loading)
            SliverList.builder(itemCount: 6, itemBuilder: (_, _) => const ShopRowSkeleton())
          else if (_failed && _items.isEmpty)
            SliverToBoxAdapter(child: EmptyState(icon: CupertinoIcons.wifi_slash, title: 'Pas de connexion', text: 'Vérifiez votre connexion Internet puis réessayez.', action: 'Réessayer', onAction: _reload))
          else if (_loaded && _items.isEmpty)
            const SliverToBoxAdapter(child: EmptyState(icon: CupertinoIcons.building_2_fill, title: 'Aucune boutique', text: 'Essayez un autre nom ou un autre marché.'))
          else
            SliverList.separated(
              itemCount: _items.length,
              separatorBuilder: (_, _) => const Divider(indent: 88),
              itemBuilder: (_, i) => ShopRow(_items[i] as Map),
            ),
          if (_loaded && _loading) const SliverToBoxAdapter(child: Loader()),
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.bottom + (widget.embedded ? 90 : 24))),
        ]),
      ),
    );
  }
}

/// Ligne d'une boutique : logo, nom, marché, nombre de produits, ouverte ou fermée
class ShopRow extends StatelessWidget {
  final Map s;
  const ShopRow(this.s, {super.key});
  @override
  Widget build(BuildContext context) {
    final n = (s['productCount'] as num?)?.toInt() ?? 0;
    final open = s['isOpen'] != false;
    return Cell(
      onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => ShopPage(slug: s['slug'] as String))),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(width: 58, height: 58, child: NetImage((s['logoUrl'] ?? s['storefrontUrl']) as String?, width: 58, placeholder: CupertinoIcons.building_2_fill)),
      ),
      title: s['name'] as String,
      subtitle: [
        [if (s['type'] == 'GROSSISTE') 'Grossiste', s['market']].whereType<String>().join(' · '),
        '$n ${n > 1 ? 'produits' : 'produit'}${open ? '' : ' · Fermée'}',
      ].where((x) => x.isNotEmpty).join('\n'),
      trailing: s['featured'] == true ? const Icon(CupertinoIcons.star_fill, size: 15, color: AppColors.accent) : null,
    );
  }
}

class ShopRowSkeleton extends StatelessWidget {
  const ShopRowSkeleton({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(children: [
      Skeleton(width: 58, height: 58, radius: 14),
      SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Skeleton(height: 15, width: 160), SizedBox(height: 8), Skeleton(height: 12, width: 110)])),
    ]),
  );
}
