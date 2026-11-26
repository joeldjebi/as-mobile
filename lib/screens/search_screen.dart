import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets.dart';
import 'product_card.dart';

const _sorts = {
  'new': 'Nouveautés',
  'popular': 'Populaires',
  'price_asc': 'Prix croissant',
  'price_desc': 'Prix décroissant',
};

/// Recherche de produits : mot-clé, catégorie, prix, détail ou gros, tri ; chargement par pages
class SearchScreen extends StatefulWidget {
  final String? categoryId;
  final String? categoryName;
  final bool autofocus;
  const SearchScreen({
    super.key,
    this.categoryId,
    this.categoryName,
    this.autofocus = false,
  });
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _q = TextEditingController();
  final _scroll = ScrollController();
  String _sort = 'new';
  bool _wholesale = false;
  int? _min;
  int? _max;
  final List<dynamic> _items = [];
  int _page = 0;
  int _pages = 1;
  int _total = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        _more();
      }
    });
  }

  Map<String, String> get _params => {
    if (_q.text.trim().isNotEmpty) 'q': _q.text.trim(),
    'categoryId': ?widget.categoryId,
    if (_wholesale) 'wholesale': 'true',
    if (_min != null) 'minPrice': '$_min',
    if (_max != null) 'maxPrice': '$_max',
    'sort': _sort,
  };

  Future<void> _search() async {
    setState(() {
      _items.clear();
      _page = 0;
      _pages = 1;
    });
    await _more();
  }

  Future<void> _more() async {
    if (_loading || _page >= _pages) return;
    setState(() => _loading = true);
    try {
      final r = await Api.instance.searchProducts({
        ..._params,
        'page': '${_page + 1}',
      });
      if (!mounted) return;
      setState(() {
        _items.addAll(r['items'] as List);
        _page = r['page'] as int;
        _pages = r['pages'] as int;
        _total = r['total'] as int;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _priceFilter() async {
    final min = TextEditingController(text: _min?.toString() ?? '');
    final max = TextEditingController(text: _max?.toString() ?? '');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(c).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Prix',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: min,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Minimum',
                      suffixText: 'F',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: max,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Maximum',
                      suffixText: 'F',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Appliquer'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    setState(() {
      _min = int.tryParse(min.text.replaceAll(RegExp(r'\D'), ''));
      _max = int.tryParse(max.text.replaceAll(RegExp(r'\D'), ''));
    });
    _search();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      titleSpacing: 0,
      title: TextField(
        controller: _q,
        autofocus: widget.autofocus,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _search(),
        decoration: InputDecoration(
          hintText: widget.categoryName == null
              ? 'Rechercher un produit'
              : 'Rechercher dans ${widget.categoryName}',
          prefixIcon: const Icon(PhosphorIconsBold.magnifyingGlass),
        ),
      ),
    ),
    body: RefreshIndicator(
      onRefresh: _search,
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                PopupMenuButton<String>(
                  initialValue: _sort,
                  onSelected: (v) {
                    setState(() => _sort = v);
                    _search();
                  },
                  itemBuilder: (_) => [
                    for (final e in _sorts.entries)
                      PopupMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  child: Chip(
                    avatar: const Icon(
                      PhosphorIconsBold.sortAscending,
                      size: 16,
                    ),
                    label: Text(_sorts[_sort]!),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Prix de gros'),
                  selected: _wholesale,
                  onSelected: (v) {
                    setState(() => _wholesale = v);
                    _search();
                  },
                ),
                const SizedBox(width: 8),
                ActionChip(
                  label: Text(
                    _min == null && _max == null
                        ? 'Prix'
                        : '${_min != null ? formatMoney(_min) : '0 F'} – ${_max != null ? formatMoney(_max) : '…'}',
                  ),
                  onPressed: _priceFilter,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '$_total produit(s)',
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          if (_items.isEmpty && !_loading)
            const StatusBanner(
              icon: PhosphorIconsBold.magnifyingGlass,
              color: AppColors.muted,
              title: 'Aucun produit trouvé',
              text: 'Essayez un autre mot ou retirez des filtres.',
            )
          else
            ProductGrid(_items),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    ),
  );
}
