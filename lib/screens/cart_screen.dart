import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../cart.dart';
import '../theme.dart';
import '../widgets.dart';
import 'auth_screen.dart';
import 'orders_screen.dart';

/// Panier : articles groupés par boutique (une livraison VITE par boutique). La connexion est demandée ici, à la commande.
class CartScreen extends StatelessWidget {
  final VoidCallback onBrowse;
  const CartScreen({super.key, required this.onBrowse});

  Future<void> _checkout(BuildContext context) async {
    if (!await requireAuth(
      context,
      reason: 'Connectez-vous pour finaliser votre commande',
    ))
      return;
    if (!context.mounted) return;
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => const CheckoutScreen()),
    );
  }

  Future<void> _clear(BuildContext context) async {
    final ok = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (c) => CupertinoActionSheet(
        message: const Text('Tous les articles seront retirés du panier.'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Vider le panier'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Annuler'),
        ),
      ),
    );
    if (ok == true) Cart.instance.clear();
  }

  Widget _line(CartItem i) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 62,
            height: 62,
            child: NetImage(i.photo, width: 62),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                i.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.subhead.copyWith(height: 1.25),
              ),
              if (i.variantLabel != null)
                Text(i.variantLabel!, style: AppText.caption),
              if (i.prepayPercent < 100)
                Text(
                  'Acompte ${i.prepayPercent} % à la commande',
                  style: AppText.caption.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatMoney(i.price * i.qty),
                      style: AppText.price,
                    ),
                  ),
                  QtyStepper(
                    qty: i.qty,
                    min: 0,
                    compact: true,
                    onChanged: (q) => Cart.instance.setQty(i, q),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Cart.instance,
    builder: (context, _) {
      final cart = Cart.instance;
      final groups = cart.byShop.values.toList();
      final tabBar = tabBarHeight(context);
      return Scaffold(
        body: Stack(
          children: [
            CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                LargeTitleBar(
                  'Panier',
                  trailing: cart.items.isEmpty
                      ? null
                      : BarButton('Vider', onTap: () => _clear(context)),
                ),
                if (cart.items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: tabBar + 40),
                      child: Center(
                        child: EmptyState(
                          icon: CupertinoIcons.bag,
                          title: 'Votre panier est vide',
                          text:
                              'Parcourez les boutiques d’Adjamé et ajoutez vos coups de cœur.',
                          action: 'Découvrir',
                          onAction: onBrowse,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, tabBar + 96),
                    sliver: SliverList.list(
                      children: [
                        for (final g in groups) ...[
                          SectionTitle(
                            '${g.first.shopName} · ${g.fold<int>(0, (t, i) => t + i.qty)} ${g.fold<int>(0, (t, i) => t + i.qty) > 1 ? 'articles' : 'article'}',
                          ),
                          Group(
                            dividerIndent: 88,
                            children: [for (final i in g) _line(i)],
                          ),
                        ],
                        const SectionTitle('Récapitulatif'),
                        Group(
                          children: [
                            Cell(
                              title: 'Articles (${cart.count})',
                              value: formatMoney(cart.total),
                            ),
                            Cell(
                              title: 'À payer à la commande',
                              subtitle: 'Mobile Money',
                              trailing: Text(
                                formatMoney(cart.dueNow),
                                style: AppText.price,
                              ),
                            ),
                            if (cart.dueOnDelivery > 0)
                              Cell(
                                title: 'Reste à la livraison',
                                subtitle: 'Au livreur, à la remise',
                                value: formatMoney(cart.dueOnDelivery),
                              ),
                            Cell(
                              title: groups.length > 1
                                  ? 'Livraisons (${groups.length})'
                                  : 'Livraison',
                              value: 'Au livreur',
                            ),
                          ],
                        ),
                        if (cart.dueOnDelivery > 0)
                          const SectionFooter(
                            'Certaines boutiques demandent seulement un acompte à la commande : le reste est payé à la livraison.',
                          ),
                        SectionFooter(
                          groups.length > 1
                              ? 'Une livraison VITE par boutique. Les frais de livraison sont payés en espèces à chaque livreur.'
                              : 'Les frais de livraison VITE sont payés en espèces au livreur.',
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const SizedBox(width: 16),
                            const Icon(
                              PhosphorIconsRegular.shieldCheck,
                              size: 15,
                              color: AppColors.muted,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Paiement Mobile Money sécurisé',
                                style: AppText.caption,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (cart.items.isNotEmpty)
              Positioned(
                left: 14,
                right: 14,
                bottom: tabBar - 6,
                child: Glass(
                  radius: BorderRadius.circular(30),
                  opacity: 0.8,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 7, 7, 7),
                    child: Row(
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cart.dueOnDelivery > 0
                                  ? 'À payer maintenant'
                                  : 'Total',
                              style: AppText.caption.copyWith(fontSize: 11),
                            ),
                            Text(
                              formatMoney(cart.dueNow),
                              style: AppText.price.copyWith(fontSize: 17),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _checkout(context),
                            child: const Text('Commander'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
