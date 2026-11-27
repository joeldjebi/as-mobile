import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets.dart';
import 'product_card.dart';

const _sorts = {'new': 'Nouveautés', 'popular': 'Populaires', 'price_asc': 'Prix croissant', 'price_desc': 'Prix décroissant'};

/// Recherche : mot-clé, catégorie, prix, prix de gros, tri ; chargement par pages
class SearchScreen extends StatefulWidget {
  final String? categoryId;
  final String? categoryName;
  final String sort;
  /// Onglet de la barre du bas (pas de bouton retour)
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
  int _page = 0;
  int _pages = 1;
  int _total = 0;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _search();
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
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(c).viewInsets.bottom + 24 + MediaQuery.of(c).padding.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Expanded(child: Text('Filtres', style: AppText.headline)),
              TextButton(
                onPressed: () => set(() { min.clear(); max.clear(); sort = 'new'; wholesale = false; }),
                child: const Text('Effacer'),
              ),
            ]),
            const SizedBox(height: 18),
            const Text('TRIER PAR', style: AppText.overline),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in _sorts.entries)
                ChoiceChip(label: Text(e.value), selected: sort == e.key, showCheckmark: false, onSelected: (_) => set(() => sort = e.key)),
            ]),
            const SizedBox(height: 22),
            const Text('PRIX', style: AppText.overline),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: min, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Minimum', suffixText: 'F'))),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('—', style: AppText.bodyMuted)),
              Expanded(child: TextField(controller: max, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Maximum', suffixText: 'F'))),
            ]),
            const SizedBox(height: 14),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: wholesale,
              activeTrackColor: AppColors.primary,
              onChanged: (v) => set(() => wholesale = v),
              title: const Text('Vente en gros uniquement', style: AppText.title),
              subtitle: const Text('Produits avec un prix revendeur', style: AppText.caption),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Voir les résultats')),
          ]),
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

  int get _activeFilters => (_sort != widget.sort ? 1 : 0) + (_wholesale ? 1 : 0) + (_min != null || _max != null ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final title = widget.categoryName ?? (widget.embedded ? 'Rechercher' : _sorts[widget.sort]!);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.ink,
          onRefresh: _search,
          child: CustomScrollView(controller: _scroll, slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (!widget.embedded) ...[
                    Align(alignment: Alignment.centerLeft, child: RoundIconButton(PhosphorIconsRegular.arrowLeft, onTap: () => Navigator.pop(context))),
                    const SizedBox(height: 14),
                  ] else
                    const SizedBox(height: 8),
                  Text(title, style: AppText.display.copyWith(fontSize: 30)),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _q,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _search(),
                        style: AppText.body,
                        decoration: InputDecoration(
                          hintText: widget.categoryName == null ? 'Un produit, une marque…' : 'Rechercher ici',
                          prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, color: AppColors.ink, size: 20),
                          filled: true,
                          fillColor: AppColors.surface,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: const BorderSide(color: AppColors.line)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: const BorderSide(color: AppColors.line)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: const BorderSide(color: AppColors.ink)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Pressable(
                      onTap: _filters,
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(color: _activeFilters > 0 ? AppColors.ink : AppColors.surface, shape: BoxShape.circle, border: Border.all(color: _activeFilters > 0 ? AppColors.ink : AppColors.line)),
                        child: Icon(PhosphorIconsRegular.slidersHorizontal, color: _activeFilters > 0 ? Colors.white : AppColors.ink, size: 21),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  Text(
                    _loading && _items.isEmpty ? 'Recherche…' : '$_total ${_total > 1 ? 'articles' : 'article'} · ${_sorts[_sort]}',
                    style: AppText.caption,
                  ),
                  const SizedBox(height: 14),
                ]),
              ),
            ),
            if (_failed && _items.isEmpty)
              SliverToBoxAdapter(child: EmptyState(icon: PhosphorIconsLight.wifiSlash, title: 'Connexion impossible', text: 'Vérifiez votre connexion puis réessayez.', action: 'Réessayer', onAction: _search))
            else if (_items.isEmpty && !_loading)
              const SliverToBoxAdapter(child: EmptyState(icon: PhosphorIconsLight.magnifyingGlass, title: 'Aucun résultat', text: 'Essayez un autre mot ou retirez des filtres.'))
            else
              SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 20), sliver: ProductSliverGrid(_items)),
            if (_loading)
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: AppColors.ink, strokeWidth: 2)))),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ]),
        ),
      ),
    );
  }
}
