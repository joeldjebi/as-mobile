import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets.dart';
import 'product_screen.dart';

/// Carte d'un produit (grilles et listes horizontales)
class ProductCard extends StatelessWidget {
  final Map p;
  final double? width;
  const ProductCard(this.p, {super.key, this.width});

  @override
  Widget build(BuildContext context) {
    final photos = (p['photos'] as List?) ?? [];
    final card = InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductScreen(id: p['id'] as String)),
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  photos.isEmpty
                      ? Container(
                          color: AppColors.background,
                          child: const Icon(
                            PhosphorIconsFill.image,
                            color: AppColors.muted,
                          ),
                        )
                      : Image.network(
                          photoUrl(photos.first as String),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              Container(color: AppColors.background),
                        ),
                  if (p['inStock'] == false)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: _pill('Rupture', AppColors.ink),
                    ),
                  if (p['hasWholesale'] == true)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: _pill('Gros', AppColors.primary),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p['name'] as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatMoney(p['price'] as num),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  if (p['shop'] != null)
                    Text(
                      p['shop']['name'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.muted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return width == null ? card : SizedBox(width: width, child: card);
  }

  static Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// Grille de produits (2 colonnes)
class ProductGrid extends StatelessWidget {
  final List items;
  const ProductGrid(this.items, {super.key});
  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.66,
    ),
    itemCount: items.length,
    itemBuilder: (_, i) => ProductCard(items[i] as Map),
  );
}
