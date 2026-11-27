import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
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

  Widget _info(IconData icon, String title, String? sub, {VoidCallback? onTap, Widget? trailing}) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    leading: Icon(icon, color: AppColors.ink, size: 22),
    title: Text(title, style: AppText.label.copyWith(fontSize: 14.5)),
    subtitle: sub == null || sub.isEmpty ? null : Text(sub, style: AppText.caption),
    trailing: trailing,
    onTap: onTap,
  );

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final top = MediaQuery.of(context).padding.top;
    if (s == null) {
      return Scaffold(
        body: Stack(children: [
          Center(
            child: _failed
                ? EmptyState(icon: PhosphorIconsLight.wifiSlash, title: 'Boutique indisponible', text: 'Vérifiez votre connexion puis réessayez.', action: 'Réessayer', onAction: _load)
                : const CircularProgressIndicator(color: AppColors.ink, strokeWidth: 2),
          ),
          Positioned(top: top + 8, left: 16, child: RoundIconButton(PhosphorIconsRegular.arrowLeft, onTap: () => Navigator.pop(context))),
        ]),
      );
    }
    final hours = s['hours'] as Map?;
    final open = s['isOpen'] != false;
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Stack(clipBehavior: Clip.none, children: [
            AspectRatio(aspectRatio: 4 / 3, child: NetImage(s['storefrontUrl'] as String?, placeholder: PhosphorIconsLight.storefront)),
            Positioned(top: top + 8, left: 16, child: RoundIconButton(PhosphorIconsRegular.arrowLeft, onTap: () => Navigator.pop(context))),
            Positioned(
              left: 20,
              bottom: -36,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, border: Border.all(color: AppColors.background, width: 4)),
                clipBehavior: Clip.antiAlias,
                child: NetImage(s['logoUrl'] as String?, placeholder: PhosphorIconsLight.storefront),
              ),
            ),
          ]),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text([s['type'] == 'GROSSISTE' ? 'GROSSISTE' : 'BOUTIQUE', (s['market'] as String?)?.toUpperCase()].whereType<String>().join(' · '), style: AppText.overline),
              const SizedBox(height: 6),
              Text(s['name'] as String, style: AppText.display.copyWith(fontSize: 30)),
              const SizedBox(height: 10),
              Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: open ? AppColors.success : AppColors.faint, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(open ? 'Ouverte' : 'Fermée pour le moment', style: AppText.label.copyWith(color: open ? AppColors.success : AppColors.muted)),
                if (hours != null) Text('  ·  ${hours['open']} – ${hours['close']}', style: AppText.caption),
              ]),
              if ((s['description'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(s['description'] as String, style: AppText.bodyMuted),
              ],
              const SizedBox(height: 20),
              Group(children: [
                _info(PhosphorIconsLight.mapPin, (s['location'] as String?) ?? 'Adjamé', s['market'] as String?),
                if (hours != null) _info(PhosphorIconsLight.clock, '${hours['open']} – ${hours['close']}', (hours['days'] as List).map((d) => _days[d as int]).join(', ')),
                if (s['phone'] != null)
                  _info(
                    PhosphorIconsLight.phone,
                    formatPhone(s['phone'] as String),
                    'Appeler la boutique',
                    trailing: const Icon(PhosphorIconsRegular.arrowUpRight, size: 18, color: AppColors.muted),
                    onTap: () => launchUrl(Uri.parse('tel:${s['phone']}')),
                  ),
              ]),
            ]),
          ),
        ),
        SliverToBoxAdapter(child: SectionHeader(_products == null ? 'Produits' : '${_products!.length} ${_products!.length > 1 ? 'produits' : 'produit'}')),
        if (_products == null)
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: AppColors.ink, strokeWidth: 2))))
        else if (_products!.isEmpty)
          const SliverToBoxAdapter(child: EmptyState(icon: PhosphorIconsLight.package, title: 'Bientôt en rayon', text: 'Cette boutique ajoute ses produits.'))
        else
          SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 20), sliver: ProductSliverGrid(_products!)),
        SliverToBoxAdapter(child: SizedBox(height: 32 + MediaQuery.of(context).padding.bottom)),
      ]),
    );
  }
}
