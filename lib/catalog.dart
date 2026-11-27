import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'api.dart';
import 'theme.dart';
import 'widgets.dart';

const sortLabels = {'new': 'Nouveautés', 'popular': 'Populaires', 'price_asc': 'Prix croissant', 'price_desc': 'Prix décroissant'};

/// Liste de produits filtrable, chargée par pages (rayon, marché, boutique, recherche)
class CatalogController extends ChangeNotifier {
  /// Critères fixes (q, categoryId, shopId…)
  Map<String, String> base;
  final String defaultSort;
  late String sort = defaultSort;
  int? minPrice;
  int? maxPrice;
  String? market;
  bool wholesale = false;
  bool inStock = false;

  final List<dynamic> items = [];
  int _page = 0;
  int _pages = 1;
  int total = 0;
  bool loading = false;
  bool failed = false;
  bool loaded = false;
  int _generation = 0;

  CatalogController({Map<String, String>? base, this.defaultSort = 'new'}) : base = base ?? {};

  int get activeFilters => (sort != defaultSort ? 1 : 0) + (minPrice != null || maxPrice != null ? 1 : 0) + (market != null ? 1 : 0) + (wholesale ? 1 : 0) + (inStock ? 1 : 0);
  bool get hasMore => _page < _pages;

  Map<String, String> get params => {
    ...base,
    'sort': sort,
    if (minPrice != null) 'minPrice': '$minPrice',
    if (maxPrice != null) 'maxPrice': '$maxPrice',
    'market': ?market,
    if (wholesale) 'wholesale': 'true',
    if (inStock) 'inStock': 'true',
    'limit': '20',
  };

  Future<void> reload() async {
    _generation++;
    items.clear();
    _page = 0;
    _pages = 1;
    failed = false;
    loading = false;
    loaded = false;
    notifyListeners();
    await more();
  }

  Future<void> more() async {
    if (loading || !hasMore) return;
    final gen = _generation;
    loading = true;
    notifyListeners();
    try {
      final r = await Api.instance.searchProducts({...params, 'page': '${_page + 1}'});
      if (gen != _generation) return; // filtres changés entre-temps
      items.addAll(r['items'] as List);
      _page = r['page'] as int;
      _pages = r['pages'] as int;
      total = r['total'] as int;
      loaded = true;
    } catch (_) {
      if (gen == _generation) failed = true;
    } finally {
      if (gen == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void clearFilters() {
    sort = defaultSort;
    minPrice = null;
    maxPrice = null;
    market = null;
    wholesale = false;
    inStock = false;
    reload();
  }
}

/// Fourchettes de prix proposées
const _priceRanges = <(String, int?, int?)>[
  ('Moins de 5 000 F', null, 5000),
  ('5 000 à 20 000 F', 5000, 20000),
  ('20 000 à 50 000 F', 20000, 50000),
  ('50 000 à 150 000 F', 50000, 150000),
  ('Plus de 150 000 F', 150000, null),
];

/// Barre de filtres horizontale (Trier, Prix, Marché, Gros, En stock)
class CatalogFilterBar extends StatelessWidget {
  final CatalogController c;
  final bool showMarket;
  final bool showWholesale;
  const CatalogFilterBar(this.c, {super.key, this.showMarket = true, this.showWholesale = true});

  Future<void> _sort(BuildContext context) async {
    final v = await showCupertinoModalPopup<String>(
      context: context,
      builder: (p) => CupertinoActionSheet(
        title: const Text('Trier par'),
        actions: [
          for (final e in sortLabels.entries)
            CupertinoActionSheetAction(isDefaultAction: e.key == c.sort, onPressed: () => Navigator.pop(p, e.key), child: Text(e.key == c.sort ? '${e.value}  ✓' : e.value)),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(p), child: const Text('Annuler')),
      ),
    );
    if (v != null && v != c.sort) {
      c.sort = v;
      c.reload();
    }
  }

  Future<void> _price(BuildContext context) async {
    final min = TextEditingController(text: c.minPrice?.toString() ?? '');
    final max = TextEditingController(text: c.maxPrice?.toString() ?? '');
    final r = await showModalBottomSheet<(int?, int?)?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (p) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(p).viewInsets.bottom),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(children: [
                BarButton('Effacer', onTap: () => Navigator.pop(p, (null, null))),
                const Expanded(child: Text('Prix', textAlign: TextAlign.center, style: AppText.title)),
                BarButton('OK', bold: true, onTap: () => Navigator.pop(p, (int.tryParse(min.text.replaceAll(RegExp(r'\D'), '')), int.tryParse(max.text.replaceAll(RegExp(r'\D'), ''))))),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Group(children: [
                  for (final (label, lo, hi) in _priceRanges)
                    Cell(
                      title: label,
                      trailing: c.minPrice == lo && c.maxPrice == hi ? const Icon(CupertinoIcons.checkmark_alt, color: AppColors.primary, size: 20) : const SizedBox(width: 20),
                      onTap: () => Navigator.pop(p, (lo, hi)),
                    ),
                ]),
                const SectionTitle('Fourchette personnalisée'),
                Group(children: [_field('Minimum', min), _field('Maximum', max)]),
              ]),
            ),
          ]),
        ),
      ),
    );
    if (r == null) return;
    c.minPrice = r.$1;
    c.maxPrice = r.$2;
    c.reload();
  }

  Widget _field(String label, TextEditingController t) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(children: [
      SizedBox(width: 100, child: Text(label, style: AppText.body)),
      Expanded(child: TextField(controller: t, keyboardType: TextInputType.number, textAlign: TextAlign.end, style: AppText.body, decoration: const InputDecoration(hintText: 'Aucun', suffixText: ' F', filled: false, contentPadding: EdgeInsets.symmetric(vertical: 13)))),
    ]),
  );

  Future<void> _market(BuildContext context) async {
    Map<String, dynamic> counts = {};
    try {
      counts = ((await Api.instance.shopsMeta())['marketCounts'] as Map?)?.cast<String, dynamic>() ?? {};
    } catch (_) {}
    if (!context.mounted) return;
    final names = counts.keys.toList()..sort();
    final v = await showCupertinoModalPopup<String>(
      context: context,
      builder: (p) => CupertinoActionSheet(
        title: const Text('Marché'),
        message: names.isEmpty ? const Text('Aucun marché pour le moment') : null,
        actions: [
          CupertinoActionSheetAction(onPressed: () => Navigator.pop(p, ''), child: Text(c.market == null ? 'Tous les marchés  ✓' : 'Tous les marchés')),
          for (final m in names) CupertinoActionSheetAction(onPressed: () => Navigator.pop(p, m), child: Text('$m${c.market == m ? '  ✓' : ''}')),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(p), child: const Text('Annuler')),
      ),
    );
    if (v == null) return;
    c.market = v.isEmpty ? null : v;
    c.reload();
  }

  String get _priceLabel {
    if (c.minPrice == null && c.maxPrice == null) return 'Prix';
    if (c.minPrice == null) return '≤ ${formatMoney(c.maxPrice)}';
    if (c.maxPrice == null) return '≥ ${formatMoney(c.minPrice)}';
    return '${formatMoney(c.minPrice)} – ${formatMoney(c.maxPrice)}';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        if (c.activeFilters > 0) ...[
          FilterPill('Effacer', icon: CupertinoIcons.xmark, dropdown: false, onTap: c.clearFilters),
          const SizedBox(width: 8),
        ],
        FilterPill(sortLabels[c.sort]!, icon: CupertinoIcons.arrow_up_arrow_down, active: c.sort != c.defaultSort, onTap: () => _sort(context)),
        const SizedBox(width: 8),
        FilterPill(_priceLabel, active: c.minPrice != null || c.maxPrice != null, onTap: () => _price(context)),
        if (showMarket) ...[
          const SizedBox(width: 8),
          FilterPill(c.market ?? 'Marché', active: c.market != null, onTap: () => _market(context)),
        ],
        if (showWholesale) ...[
          const SizedBox(width: 8),
          FilterPill('Prix de gros', dropdown: false, active: c.wholesale, onTap: () {
            c.wholesale = !c.wholesale;
            c.reload();
          }),
        ],
        const SizedBox(width: 8),
        FilterPill('Disponible', dropdown: false, active: c.inStock, onTap: () {
          c.inStock = !c.inStock;
          c.reload();
        }),
      ],
    ),
  );
}

/// Charge la page suivante quand on approche du bas de la liste
bool loadMoreOnScroll(ScrollNotification n, CatalogController c) {
  if (n.metrics.axis == Axis.vertical && n.metrics.pixels > n.metrics.maxScrollExtent - 900) c.more();
  return false;
}
