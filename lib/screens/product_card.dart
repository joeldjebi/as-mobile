import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import '../cart.dart';
import '../catalog.dart';
import '../theme.dart';
import '../widgets.dart';
import 'product_screen.dart';

/// Carte d'un produit : photo pleine, prix sur pastille de verre, ajout rapide « + », nom et boutique
class ProductCard extends StatelessWidget {
  final Map p;
  final double? width;
  const ProductCard(this.p, {super.key, this.width});

  void _open(BuildContext context) => Navigator.push(
    context,
    CupertinoPageRoute(
      builder: (_) => ProductScreen(id: p['id'] as String, preview: p),
    ),
  );

  /// Ajout direct au panier (produit sans option) ; sinon ouverture de la fiche pour choisir
  void _quickAdd(BuildContext context) {
    final variants = (p['variants'] as List?) ?? [];
    final shop = p['shop'] as Map?;
    if (variants.isNotEmpty || shop == null) return _open(context);
    final photos = (p['photos'] as List?) ?? [];
    Cart.instance.add(
      CartItem(
        productId: p['id'] as String,
        name: p['name'] as String,
        photo: photos.isEmpty ? null : photos.first as String,
        price: (p['price'] as num).toInt(),
        shopId: shop['id'] as String,
        shopName: shop['name'] as String,
        prepayPercent: (p['prepayPercent'] as num?)?.toInt() ?? 100,
      ),
    );
    HapticFeedback.mediumImpact();
    showInfo(context, 'Ajouté au panier');
  }

  @override
  Widget build(BuildContext context) {
    final photos = (p['photos'] as List?) ?? [];
    final out = p['inStock'] == false;
    final prepay = (p['prepayPercent'] as num?)?.toInt() ?? 100;
    final card = Pressable(
      onTap: () => _open(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 4 / 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'product-${p['id']}',
                    child: NetImage(
                      photos.isEmpty ? null : photos.first as String,
                      width: 180,
                    ),
                  ),
                  Positioned(
                    left: 7,
                    top: 7,
                    right: 7,
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (out)
                          Pill(
                            'Épuisé',
                            background: Colors.white.withValues(alpha: 0.92),
                            foreground: AppColors.ink,
                          ),
                        if (p['hasWholesale'] == true)
                          const Pill('Gros', background: AppColors.primary),
                        if (prepay < 100)
                          Pill(
                            'Acompte $prepay %',
                            background: AppColors.accent,
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 7,
                    bottom: 7,
                    child: Glass(
                      radius: BorderRadius.circular(14),
                      opacity: 0.78,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        child: Text(
                          formatMoney(p['price'] as num),
                          style: AppText.price.copyWith(fontSize: 13.5),
                        ),
                      ),
                    ),
                  ),
                  if (!out)
                    Positioned(
                      right: 7,
                      bottom: 7,
                      child: GestureDetector(
                        onTap: () => _quickAdd(context),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: AppColors.ink,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            CupertinoIcons.plus,
                            size: 17,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            p['name'] as String,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.subhead.copyWith(fontSize: 13.5, height: 1.25),
          ),
          if (p['shop'] != null) ...[
            const SizedBox(height: 2),
            Text(
              p['shop']['name'] as String,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
    return width == null ? card : SizedBox(width: width, child: card);
  }
}

const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  mainAxisSpacing: 18,
  crossAxisSpacing: 10,
  childAspectRatio: 0.66,
);

/// Grille de produits dans un CustomScrollView
class ProductSliverGrid extends StatelessWidget {
  final List items;
  const ProductSliverGrid(this.items, {super.key});
  @override
  Widget build(BuildContext context) => SliverGrid.builder(
    gridDelegate: _gridDelegate,
    itemCount: items.length,
    itemBuilder: (_, i) => ProductCard(items[i] as Map),
  );
}

/// Rangée horizontale de produits
class ProductRail extends StatelessWidget {
  final List items;
  const ProductRail(this.items, {super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 254,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (_, i) => ProductCard(items[i] as Map, width: 146),
    ),
  );
}

/// Résultats d'un catalogue : nombre, grille, chargement par pages, états vides
class CatalogResults extends StatelessWidget {
  final CatalogController c;
  final String emptyText;
  const CatalogResults(
    this.c, {
    super.key,
    this.emptyText = 'Aucun produit ne correspond pour le moment.',
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
            child: Text(
              !c.loaded
                  ? ' '
                  : '${c.total} ${c.total > 1 ? 'produits' : 'produit'}',
              style: AppText.caption,
            ),
          ),
        ),
        if (!c.loaded && c.loading)
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            sliver: ProductGridSkeleton(),
          )
        else if (c.failed && c.items.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              icon: CupertinoIcons.wifi_slash,
              title: 'Pas de connexion',
              text: 'Vérifiez votre connexion Internet puis réessayez.',
              action: 'Réessayer',
              onAction: c.reload,
            ),
          )
        else if (c.loaded && c.items.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              icon: CupertinoIcons.cube_box,
              title: 'Aucun produit',
              text: c.activeFilters > 0
                  ? 'Retirez des filtres pour voir plus de produits.'
                  : emptyText,
              action: c.activeFilters > 0 ? 'Effacer les filtres' : null,
              onAction: c.clearFilters,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: ProductSliverGrid(c.items),
          ),
        if (c.loaded && c.loading) const SliverToBoxAdapter(child: Loader()),
      ],
    ),
  );
}
