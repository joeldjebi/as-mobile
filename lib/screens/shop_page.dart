import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets.dart';
import 'product_card.dart';

const _days = ['', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

/// Page publique d'une boutique : vitrine, informations, produits
class ShopPage extends StatefulWidget {
  final String slug;
  const ShopPage({super.key, required this.slug});
  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  Map<String, dynamic>? _s;
  List<dynamic>? _products;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final s = await Api.instance.shop(widget.slug);
      if (!mounted) return;
      setState(() => _s = s);
      final r = await Api.instance.searchProducts({'shopId': s['id'] as String, 'sort': 'new'});
      if (mounted) setState(() => _products = r['items'] as List);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final top = MediaQuery.of(context).padding.top;
    final back = Positioned(top: top + 6, left: 16, child: RoundIconButton(CupertinoIcons.chevron_back, onTap: () => Navigator.pop(context)));
    if (s == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: Stack(children: [
          Center(child: _failed ? EmptyState(icon: CupertinoIcons.wifi_slash, title: 'Boutique indisponible', text: 'Vérifiez votre connexion Internet puis réessayez.', action: 'Réessayer', onAction: _load) : const Loader()),
          back,
        ]),
      );
    }
    final hours = s['hours'] as Map?;
    final open = s['isOpen'] != false;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(physics: const BouncingScrollPhysics(), slivers: [
        SliverToBoxAdapter(
          child: Stack(clipBehavior: Clip.none, children: [
            AspectRatio(aspectRatio: 16 / 11, child: NetImage(s['storefrontUrl'] as String?, placeholder: CupertinoIcons.building_2_fill)),
            back,
            Positioned(
              left: 20,
              bottom: -34,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.surface, width: 3), boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 4))]),
                clipBehavior: Clip.antiAlias,
                child: ClipRRect(borderRadius: BorderRadius.circular(15), child: NetImage(s['logoUrl'] as String?, placeholder: CupertinoIcons.building_2_fill)),
              ),
            ),
          ]),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 46, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s['name'] as String, style: AppText.title1),
              const SizedBox(height: 2),
              Text([s['type'] == 'GROSSISTE' ? 'Grossiste' : 'Boutique', s['market']].whereType<String>().join(' · '), style: AppText.bodyMuted),
              const SizedBox(height: 10),
              Row(children: [
                Icon(CupertinoIcons.circle_fill, size: 9, color: open ? AppColors.success : AppColors.faint),
                const SizedBox(width: 6),
                Text(open ? 'Ouverte' : 'Fermée', style: AppText.label.copyWith(color: open ? AppColors.success : AppColors.muted)),
                if (hours != null) Text('  ·  ${hours['open']} – ${hours['close']}', style: AppText.bodyMuted),
              ]),
              if ((s['description'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(s['description'] as String, style: AppText.subhead.copyWith(height: 1.4)),
              ],
              const SizedBox(height: 20),
              Group(color: AppColors.surfaceAlt, dividerIndent: 52, children: [
                Cell(leading: const Icon(CupertinoIcons.location_fill, color: AppColors.primary, size: 22), title: (s['location'] as String?) ?? 'Adjamé', subtitle: s['market'] as String?),
                if (hours != null) Cell(leading: const Icon(CupertinoIcons.clock_fill, color: AppColors.primary, size: 22), title: '${hours['open']} – ${hours['close']}', subtitle: (hours['days'] as List).map((d) => _days[d as int]).join(', ')),
                if (s['phone'] != null)
                  Cell(
                    leading: const Icon(CupertinoIcons.phone_fill, color: AppColors.primary, size: 22),
                    title: formatPhone(s['phone'] as String),
                    subtitle: 'Appeler la boutique',
                    trailing: const Icon(CupertinoIcons.arrow_up_right, size: 16, color: AppColors.faint),
                    onTap: () => launchUrl(Uri.parse('tel:${s['phone']}')),
                  ),
              ]),
            ]),
          ),
        ),
        SliverToBoxAdapter(child: SectionHeader(_products == null ? 'Produits' : '${_products!.length} ${_products!.length > 1 ? 'produits' : 'produit'}')),
        if (_products == null)
          const SliverToBoxAdapter(child: Loader())
        else if (_products!.isEmpty)
          const SliverToBoxAdapter(child: EmptyState(icon: CupertinoIcons.cube_box, title: 'Bientôt en rayon', text: 'Cette boutique ajoute ses produits.'))
        else
          SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 16), sliver: ProductSliverGrid(_products!)),
        SliverToBoxAdapter(child: SizedBox(height: 32 + MediaQuery.of(context).padding.bottom)),
      ]),
    );
  }
}
