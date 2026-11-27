import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../catalog.dart';
import '../theme.dart';
import '../widgets.dart';
import 'product_card.dart';

const _days = ['', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

/// Page d'une boutique : vitrine, informations, rayons de la boutique, recherche dans son catalogue
class ShopPage extends StatefulWidget {
  final String slug;
  const ShopPage({super.key, required this.slug});
  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  Map<String, dynamic>? _s;
  bool _failed = false;
  CatalogController? _c;
  String? _shelf;
  final _q = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _s = Api.instance.peek('/shops/${widget.slug}') as Map<String, dynamic>?;
    if (_s != null) _startCatalog();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    _c?.dispose();
    super.dispose();
  }

  void _startCatalog() {
    if (_c != null) return;
    _c = CatalogController(base: {'shopId': _s!['id'] as String})..reload();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final s = await Api.instance.shop(widget.slug);
      if (!mounted) return;
      setState(() => _s = s);
      _startCatalog();
    } catch (_) {
      if (mounted && _s == null) setState(() => _failed = true);
    }
  }

  void _apply() {
    _c!.base = {
      'shopId': _s!['id'] as String,
      'categoryId': ?_shelf,
      if (_q.text.trim().isNotEmpty) 'q': _q.text.trim(),
    };
    _c!.reload();
  }

  Widget _shelfChip(String label, String? id, [int? n]) {
    final on = _shelf == id;
    return Pressable(
      onTap: () {
        if (on) return;
        setState(() => _shelf = id);
        _apply();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? AppColors.primary : AppColors.primarySoft,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Text(
          n == null ? label : '$label  $n',
          style: AppText.subhead.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: on ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final top = MediaQuery.of(context).padding.top;
    final back = Positioned(
      top: top + 6,
      left: 16,
      child: RoundIconButton(
        CupertinoIcons.chevron_back,
        onTap: () => Navigator.pop(context),
      ),
    );
    if (s == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: Stack(
          children: [
            Center(
              child: _failed
                  ? EmptyState(
                      icon: CupertinoIcons.arrow_clockwise,
                      title: 'Un petit instant',
                      text: 'La boutique arrive, réessayez dans un instant.',
                      action: 'Réessayer',
                      onAction: _load,
                    )
                  : const Loader(),
            ),
            back,
          ],
        ),
      );
    }
    final hours = s['hours'] as Map?;
    final open = s['isOpen'] != false;
    final shelves = ((s['shelves'] as List?) ?? []).cast<Map>();
    final count = (s['productCount'] as num?)?.toInt() ?? 0;
    final c = _c!;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) => loadMoreOnScroll(n, c),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: s['storefrontUrl'] == null
                        ? WaxPattern(seed: (s['name'] as String).length)
                        : NetImage(
                            s['storefrontUrl'] as String?,
                            width: 430,
                            placeholder: CupertinoIcons.building_2_fill,
                          ),
                  ),
                  back,
                  Positioned(
                    left: 20,
                    bottom: -34,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.surface, width: 3),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: NetImage(
                          s['logoUrl'] as String?,
                          width: 76,
                          placeholder: CupertinoIcons.building_2_fill,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 46, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s['name'] as String, style: AppText.title1),
                    const SizedBox(height: 2),
                    Text(
                      [
                        s['type'] == 'GROSSISTE' ? 'Grossiste' : 'Boutique',
                        s['market'],
                        '$count ${count > 1 ? 'produits' : 'produit'}',
                      ].whereType<String>().join(' · '),
                      style: AppText.bodyMuted,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.circle_fill,
                          size: 9,
                          color: open ? AppColors.success : AppColors.faint,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          open ? 'Ouverte' : 'Fermée',
                          style: AppText.label.copyWith(
                            color: open ? AppColors.success : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                    if ((s['description'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        s['description'] as String,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.subhead.copyWith(height: 1.4),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Group(
                      color: AppColors.surfaceAlt,
                      dividerIndent: 52,
                      children: [
                        Cell(
                          leading: const Icon(
                            CupertinoIcons.location_fill,
                            color: AppColors.primary,
                            size: 22,
                          ),
                          // Le marché figure déjà sous le nom de la boutique
                          title: (s['location'] as String?) ?? 'Adjamé',
                        ),
                        if (hours != null)
                          Cell(
                            leading: const Icon(
                              CupertinoIcons.clock_fill,
                              color: AppColors.primary,
                              size: 22,
                            ),
                            title: '${hours['open']} – ${hours['close']}',
                            subtitle: (hours['days'] as List)
                                .map((d) => _days[d as int])
                                .join(', '),
                          ),
                        if (s['phone'] != null)
                          Cell(
                            leading: const Icon(
                              CupertinoIcons.phone_fill,
                              color: AppColors.primary,
                              size: 22,
                            ),
                            title: formatPhone(s['phone'] as String),
                            subtitle: 'Appeler la boutique',
                            trailing: const Icon(
                              CupertinoIcons.arrow_up_right,
                              size: 16,
                              color: AppColors.faint,
                            ),
                            onTap: () =>
                                launchUrl(Uri.parse('tel:${s['phone']}')),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    if (count > 8)
                      CupertinoSearchTextField(
                        controller: _q,
                        placeholder: 'Rechercher dans la boutique',
                        style: AppText.body,
                        onChanged: (_) {
                          _debounce?.cancel();
                          _debounce = Timer(
                            const Duration(milliseconds: 300),
                            _apply,
                          );
                        },
                        onSuffixTap: () {
                          _q.clear();
                          _apply();
                        },
                      ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: StickyHeader(
                height: shelves.length > 1 ? 92 : 50,
                child: Column(
                  children: [
                    if (shelves.length > 1)
                      SizedBox(
                        height: 42,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          children: [
                            _shelfChip('Tout', null, count),
                            for (final r in shelves) ...[
                              const SizedBox(width: 8),
                              _shelfChip(
                                r['name'] as String,
                                r['id'] as String,
                                (r['count'] as num).toInt(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    SizedBox(
                      height: 50,
                      child: CatalogFilterBar(c, showMarket: false),
                    ),
                  ],
                ),
              ),
            ),
            CatalogResults(c, emptyText: 'Cette boutique ajoute ses produits.'),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 32 + MediaQuery.of(context).padding.bottom,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
