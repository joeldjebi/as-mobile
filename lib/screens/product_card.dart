import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../catalog.dart';
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
      onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => ProductScreen(id: p['id'] as String, preview: p))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 4 / 5,
            child: Stack(fit: StackFit.expand, children: [
              Hero(tag: 'product-${p['id']}', child: NetImage(photos.isEmpty ? null : photos.first as String, width: 180)),
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

/// Grille de produits dans un CustomScrollView
class ProductSliverGrid extends StatelessWidget {
  final List items;
  const ProductSliverGrid(this.items, {super.key});
  @override
  Widget build(BuildContext context) => SliverGrid.builder(gridDelegate: _gridDelegate, itemCount: items.length, itemBuilder: (_, i) => ProductCard(items[i] as Map));
}

/// Rangée horizontale de produits
class ProductRail extends StatelessWidget {
  final List items;
  const ProductRail(this.items, {super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 292,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (_, i) => ProductCard(items[i] as Map, width: 160),
    ),
  );
}

/// Résultats d'un catalogue : nombre, grille, chargement par pages, états vides
class CatalogResults extends StatelessWidget {
  final CatalogController c;
  final String emptyText;
  const CatalogResults(this.c, {super.key, this.emptyText = 'Aucun produit ne correspond pour le moment.'});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => SliverMainAxisGroup(slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
          child: Text(!c.loaded ? ' ' : '${c.total} ${c.total > 1 ? 'produits' : 'produit'}', style: AppText.caption),
        ),
      ),
      if (!c.loaded && c.loading)
        const SliverPadding(padding: EdgeInsets.symmetric(horizontal: 16), sliver: ProductGridSkeleton())
      else if (c.failed && c.items.isEmpty)
        SliverToBoxAdapter(child: EmptyState(icon: CupertinoIcons.wifi_slash, title: 'Pas de connexion', text: 'Vérifiez votre connexion Internet puis réessayez.', action: 'Réessayer', onAction: c.reload))
      else if (c.loaded && c.items.isEmpty)
        SliverToBoxAdapter(
          child: EmptyState(
            icon: CupertinoIcons.cube_box,
            title: 'Aucun produit',
            text: c.activeFilters > 0 ? 'Retirez des filtres pour voir plus de produits.' : emptyText,
            action: c.activeFilters > 0 ? 'Effacer les filtres' : null,
            onAction: c.clearFilters,
          ),
        )
      else
        SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 16), sliver: ProductSliverGrid(c.items)),
      if (c.loaded && c.loading) const SliverToBoxAdapter(child: Loader()),
    ]),
  );
}
