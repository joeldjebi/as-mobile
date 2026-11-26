import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets.dart';
import 'reseller_screen.dart';
import 'shop_page.dart';

/// Fiche d'un produit : photos, prix (variante choisie), prix de gros pour les revendeurs, boutique
class ProductScreen extends StatefulWidget {
  final String id;
  const ProductScreen({super.key, required this.id});
  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  Map<String, dynamic>? _p;
  String? _variant;
  int _photo = 0;

  @override
  void initState() {
    super.initState();
    Api.instance
        .product(widget.id)
        .then((p) => mounted ? setState(() => _p = p) : null)
        .catchError((Object e) {
          if (mounted) showError(context, e);
          return null;
        });
  }

  Future<void> _report() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Signaler ce produit',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            for (final r in [
              'Contrefaçon',
              'Produit interdit',
              'Photo ou description trompeuse',
              'Prix abusif',
              'Autre problème',
            ])
              ListTile(title: Text(r), onTap: () => Navigator.pop(c, r)),
          ],
        ),
      ),
    );
    if (reason == null) return;
    try {
      await Api.instance.reportProduct(widget.id, reason);
      if (mounted) {
        showInfo(
          context,
          'Merci, l’équipe Adjamé-Smart va vérifier ce produit',
        );
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    if (p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final photos = (p['photos'] as List).cast<String>();
    final variants = ((p['variants'] as List?) ?? []).cast<Map>();
    final v = variants.where((x) => x['id'] == _variant).firstOrNull;
    final price = (v?['price'] ?? p['price']) as num;
    final stock = v != null ? v['stock'] as num? : p['stock'] as num?;
    final shop = p['shop'] as Map?;
    final reseller = Api.instance.user?['resellerStatus'] == 'APPROVED';
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Signaler',
            icon: const Icon(PhosphorIconsBold.flag),
            onPressed: _report,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                PageView(
                  onPageChanged: (i) => setState(() => _photo = i),
                  children: [
                    for (final u in photos)
                      Image.network(
                        photoUrl(u),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            Container(color: Colors.white),
                      ),
                  ],
                ),
                if (photos.length > 1)
                  Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < photos.length; i++)
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == _photo
                                  ? Colors.white
                                  : Colors.white54,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p['name'] as String,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  formatMoney(price),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                Text(
                  stock == null
                      ? 'Disponible'
                      : stock > 0
                      ? '$stock en stock'
                      : 'En rupture de stock',
                  style: TextStyle(
                    color: stock != null && stock <= 0
                        ? AppColors.warning
                        : AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (p['hasWholesale'] == true) ...[
                  const SizedBox(height: 12),
                  p['wholesalePrice'] != null
                      ? StatusBanner(
                          icon: PhosphorIconsFill.package,
                          color: AppColors.primary,
                          title:
                              'Prix de gros : ${formatMoney(p['wholesalePrice'] as num)}',
                          text: 'À partir de ${p['wholesaleMinQty']} pièces',
                        )
                      : InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ResellerScreen(),
                            ),
                          ),
                          child: StatusBanner(
                            icon: PhosphorIconsBold.lockKey,
                            color: AppColors.muted,
                            title: 'Prix de gros réservé aux revendeurs',
                            text: reseller
                                ? null
                                : 'Demandez le statut revendeur pour le voir',
                          ),
                        ),
                ],
                if (variants.isNotEmpty) ...[
                  const SectionTitle('Choix'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final x in variants)
                        ChoiceChip(
                          label: Text(x['label'] as String),
                          selected: _variant == x['id'],
                          onSelected: (s) => setState(
                            () => _variant = s ? x['id'] as String : null,
                          ),
                        ),
                    ],
                  ),
                ],
                if ((p['description'] ?? '').toString().isNotEmpty) ...[
                  const SectionTitle('Description'),
                  Text(p['description'] as String),
                ],
                if (shop != null) ...[
                  const SectionTitle('Vendu par'),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        PhosphorIconsFill.storefront,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        shop['name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        [
                          if (shop['type'] == 'GROSSISTE') 'Grossiste',
                          shop['market'],
                        ].whereType<String>().join(' · '),
                      ),
                      trailing: const Icon(
                        PhosphorIconsBold.caretRight,
                        size: 18,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ShopPage(slug: shop['slug'] as String),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const StatusBanner(
                  icon: PhosphorIconsFill.truck,
                  color: AppColors.primary,
                  title: 'Commande et livraison LETO bientôt',
                  text:
                      'Vous pourrez commander ce produit et être livré chez vous.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
