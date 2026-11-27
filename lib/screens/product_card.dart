import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets.dart';
import 'product_screen.dart';

/// Carte d'un produit : photo, nom, prix, boutique
class ProductCard extends StatelessWidget {
  final Map p;
  final double? width;
  const ProductCard(this.p, {super.key, this.width});

  @override
  Widget build(BuildContext context) {
    final photos = (p['photos'] as List?) ?? [];
    final card = Pressable(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductScreen(id: p['id'] as String, preview: p))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 4 / 5,
            child: Stack(fit: StackFit.expand, children: [
              Hero(tag: 'product-${p['id']}', child: NetImage(photos.isEmpty ? null : photos.first as String)),
              if (p['inStock'] == false) Positioned(left: 8, top: 8, child: Pill('Épuisé', background: Colors.white.withValues(alpha: 0.9), foreground: AppColors.ink)),
              if (p['hasWholesale'] == true) const Positioned(right: 8, top: 8, child: Pill('Gros', background: AppColors.primary)),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Text(p['name'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.subhead.copyWith(height: 1.25)),
        const SizedBox(height: 3),
        Text(formatMoney(p['price'] as num), style: AppText.price.copyWith(fontSize: 15)),
        if (p['shop'] != null) Text(p['shop']['name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
      ]),
    );
    return width == null ? card : SizedBox(width: width, child: card);
  }
}

const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 20, crossAxisSpacing: 12, childAspectRatio: 0.56);

/// Grille de produits (2 colonnes) dans une liste
class ProductGrid extends StatelessWidget {
  final List items;
  const ProductGrid(this.items, {super.key});
  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: EdgeInsets.zero,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: _gridDelegate,
    itemCount: items.length,
    itemBuilder: (_, i) => ProductCard(items[i] as Map),
  );
}

/// Grille de produits dans un CustomScrollView
class ProductSliverGrid extends StatelessWidget {
  final List items;
  const ProductSliverGrid(this.items, {super.key});
  @override
  Widget build(BuildContext context) => SliverGrid.builder(gridDelegate: _gridDelegate, itemCount: items.length, itemBuilder: (_, i) => ProductCard(items[i] as Map));
}

