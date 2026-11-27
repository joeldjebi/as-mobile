import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets.dart';
import 'home_screen.dart' show categoryIcon;
import 'product_card.dart';

const _sorts = {'new': 'Nouveautés', 'popular': 'Populaires', 'price_asc': 'Prix croissant', 'price_desc': 'Prix décroissant'};

/// Recherche : mot-clé, catégorie, prix, prix de gros, tri ; chargement par pages
class SearchScreen extends StatefulWidget {
  final String? categoryId;
  final String? categoryName;
  final String sort;
  /// Onglet de la barre du bas (catégories proposées, pas de retour)
  final bool embedded;
  const SearchScreen({super.key, this.categoryId, this.categoryName, this.sort = 'new', this.embedded = false});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _q = TextEditingController();
  final _scroll = ScrollController();
  late String _sort = widget.sort;
  bool _wholesale = false;
  int? _min;
  int? _max;
  final List<dynamic> _items = [];
  List<dynamic>? _cats;
  int _page = 0;
  int _pages = 1;
  int _total = 0;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _search();
    if (widget.embedded) {
      Api.instance.categories().then((c) => mounted ? setState(() => _cats = c) : null).catchError((_) => null);
    }
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 500) _more();
    });
  }

  @override
  void dispose() {
    _q.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Map<String, String> get _params => {
    if (_q.text.trim().isNotEmpty) 'q': _q.text.trim(),
    'categoryId': ?widget.categoryId,
    if (_wholesale) 'wholesale': 'true',
    if (_min != null) 'minPrice': '$_min',
    if (_max != null) 'maxPrice': '$_max',
    'sort': _sort,
  };

  bool get _browsing => widget.embedded && _q.text.trim().isEmpty && _activeFilters == 0;

  Future<void> _search() async {
    setState(() { _items.clear(); _page = 0; _pages = 1; _failed = false; });
    await _more();
  }

  Future<void> _more() async {
    if (_loading || _page >= _pages) return;
    setState(() => _loading = true);
    try {
      final r = await Api.instance.searchProducts({..._params, 'page': '${_page + 1}'});
      if (!mounted) return;
      setState(() {
        _items.addAll(r['items'] as List);
        _page = r['page'] as int;
        _pages = r['pages'] as int;
        _total = r['total'] as int;
      });
    } catch (e) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _filters() async {
    final min = TextEditingController(text: _min?.toString() ?? '');
    final max = TextEditingController(text: _max?.toString() ?? '');
    var sort = _sort;
    var wholesale = _wholesale;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
          child: SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: Row(children: [
                  BarButton('Effacer', onTap: () => set(() { min.clear(); max.clear(); sort = widget.sort; wholesale = false; })),
                  const Expanded(child: Text('Filtres', textAlign: TextAlign.center, style: AppText.title)),
                  BarButton('OK', bold: true, onTap: () => Navigator.pop(c, true)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const SectionTitle('Trier par'),
                  Group(children: [
                    for (final e in _sorts.entries)
                      Cell(
                        title: e.value,
                        trailing: sort == e.key ? const Icon(CupertinoIcons.checkmark_alt, color: AppColors.primary, size: 20) : const SizedBox(width: 20),
                        onTap: () => set(() => sort = e.key),
                      ),
                  ]),
                  const SectionTitle('Prix'),
                  Group(children: [
                    _priceRow('Minimum', min),
                    _priceRow('Maximum', max),
                  ]),
                  const SizedBox(height: 26),
                  Group(children: [
                    Cell(
                      title: 'Vente en gros uniquement',
                      trailing: CupertinoSwitch(value: wholesale, activeTrackColor: AppColors.primary, onChanged: (v) => set(() => wholesale = v)),
                    ),
                  ]),
                  const SectionFooter('Produits proposés avec un prix revendeur.'),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
    if (ok != true) return;
    setState(() {
      _sort = sort;
      _wholesale = wholesale;
      _min = int.tryParse(min.text.replaceAll(RegExp(r'\D'), ''));
      _max = int.tryParse(max.text.replaceAll(RegExp(r'\D'), ''));
    });
    _search();
  }

  Widget _priceRow(String label, TextEditingController c) => Padding(
    padding: const EdgeInsets.only(left: 16, right: 16),
    child: Row(children: [
      SizedBox(width: 110, child: Text(label, style: AppText.body)),
      Expanded(
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.end,
          style: AppText.body,
          decoration: const InputDecoration(hintText: 'Aucun', suffixText: ' F', filled: false, contentPadding: EdgeInsets.symmetric(vertical: 13)),
        ),
      ),
    ]),
  );

  int get _activeFilters => (_sort != widget.sort ? 1 : 0) + (_wholesale ? 1 : 0) + (_min != null || _max != null ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final title = widget.categoryName ?? (widget.embedded ? 'Rechercher' : _sorts[widget.sort]!);
    final cats = _cats ?? [];
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(controller: _scroll, physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()), slivers: [
        LargeTitleBar(
          title,
          background: AppColors.surface,
          trailing: BarButton(_activeFilters > 0 ? 'Filtres ($_activeFilters)' : 'Filtres', onTap: _filters),
        ),
        CupertinoSliverRefreshControl(onRefresh: _search),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: CupertinoSearchTextField(
              controller: _q,
              placeholder: widget.categoryName == null ? 'Produits, marques, boutiques' : 'Rechercher dans ${widget.categoryName}',
              style: AppText.body,
              onSubmitted: (_) => _search(),
              onSuffixTap: () {
                _q.clear();
                _search();
              },
            ),
          ),
        ),
        if (_browsing && cats.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SectionHeader('Catégories')),
          SliverList.separated(
            itemCount: cats.length,
            separatorBuilder: (_, _) => const Divider(indent: 62),
            itemBuilder: (_, i) {
              final c = cats[i] as Map;
              return Cell(
                leading: Icon(categoryIcon(c['icon'] as String?), color: AppColors.primary, size: 26),
                title: c['name'] as String,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SearchScreen(categoryId: c['id'] as String, categoryName: c['name'] as String))),
              );
            },
          ),
          const SliverToBoxAdapter(child: SectionHeader('Nouveautés')),
        ] else
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Text(_loading && _items.isEmpty ? 'Recherche…' : '$_total ${_total > 1 ? 'résultats' : 'résultat'} · ${_sorts[_sort]}', style: AppText.caption),
            ),
          ),
        if (_failed && _items.isEmpty)
          SliverToBoxAdapter(child: EmptyState(icon: CupertinoIcons.wifi_slash, title: 'Pas de connexion', text: 'Vérifiez votre connexion Internet puis réessayez.', action: 'Réessayer', onAction: _search))
        else if (_items.isEmpty && !_loading)
          SliverToBoxAdapter(child: EmptyState(icon: CupertinoIcons.search, title: 'Aucun résultat', text: _q.text.trim().isEmpty ? 'Retirez des filtres pour voir plus de produits.' : 'Aucun résultat pour « ${_q.text.trim()} ». Vérifiez l’orthographe ou essayez un autre mot.'))
        else
          SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 16), sliver: ProductSliverGrid(_items)),
        if (_loading) const SliverToBoxAdapter(child: Loader()),
        SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.bottom + (widget.embedded ? 90 : 24))),
      ]),
    );
  }
}
