import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../cart.dart';
import '../theme.dart';
import '../widgets.dart';
import 'auth_screen.dart';

/// Panier : articles groupés par boutique (une livraison LETO par boutique). La connexion est demandée ici, à la commande.
class CartScreen extends StatelessWidget {
  final VoidCallback onBrowse;
  const CartScreen({super.key, required this.onBrowse});

  Future<void> _checkout(BuildContext context) async {
    if (!await requireAuth(context, reason: 'Connectez-vous pour finaliser votre commande')) return;
    if (!context.mounted) return;
    showCupertinoDialog(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: const Text('La commande arrive bientôt'),
        content: const Text('Votre panier est gardé. Vous pourrez très vite payer par Mobile Money et être livré par LETO.'),
        actions: [CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(c), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _clear(BuildContext context) async {
    final ok = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (c) => CupertinoActionSheet(
        message: const Text('Tous les articles seront retirés du panier.'),
        actions: [CupertinoActionSheetAction(isDestructiveAction: true, onPressed: () => Navigator.pop(c, true), child: const Text('Vider le panier'))],
        cancelButton: CupertinoActionSheetAction(isDefaultAction: true, onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
      ),
    );
    if (ok == true) Cart.instance.clear();
  }

  Widget _line(CartItem i) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 68, height: 68, child: NetImage(i.photo))),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(i.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.subhead.copyWith(height: 1.25)),
          if (i.variantLabel != null) Text(i.variantLabel!, style: AppText.caption),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text(formatMoney(i.price * i.qty), style: AppText.price.copyWith(fontSize: 16))),
            QtyStepper(qty: i.qty, min: 0, compact: true, onChanged: (q) => Cart.instance.setQty(i, q)),
          ]),
        ]),
      ),
    ]),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Cart.instance,
    builder: (context, _) {
      final cart = Cart.instance;
      final groups = cart.byShop.values.toList();
      final tabBar = MediaQuery.of(context).padding.bottom + 52;
      return Scaffold(
        body: Stack(children: [CustomScrollView(physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()), slivers: [
          LargeTitleBar('Panier', trailing: cart.items.isEmpty ? null : BarButton('Vider', onTap: () => _clear(context))),
          if (cart.items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.only(bottom: tabBar + 40),
                child: Center(child: EmptyState(icon: CupertinoIcons.bag, title: 'Votre panier est vide', text: 'Parcourez les boutiques d’Adjamé et ajoutez vos coups de cœur.', action: 'Découvrir', onAction: onBrowse)),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, tabBar + 96),
              sliver: SliverList.list(children: [
                for (final g in groups) ...[
                  SectionTitle('${g.first.shopName} · ${g.fold<int>(0, (t, i) => t + i.qty)} ${g.fold<int>(0, (t, i) => t + i.qty) > 1 ? 'articles' : 'article'}'),
                  Group(dividerIndent: 94, children: [for (final i in g) _line(i)]),
                ],
                const SectionTitle('Récapitulatif'),
                Group(children: [
                  Cell(title: 'Articles (${cart.count})', value: formatMoney(cart.total)),
                  Cell(title: groups.length > 1 ? 'Livraisons (${groups.length})' : 'Livraison', value: 'Au livreur'),
                  Cell(title: 'Total à payer en ligne', trailing: Text(formatMoney(cart.total), style: AppText.price)),
                ]),
                SectionFooter(groups.length > 1
                    ? 'Une livraison LETO par boutique. Les frais de livraison sont payés en espèces à chaque livreur.'
                    : 'Les frais de livraison LETO sont payés en espèces au livreur.'),
                const SizedBox(height: 8),
                Row(children: [
                  const SizedBox(width: 16),
                  const Icon(PhosphorIconsRegular.shieldCheck, size: 15, color: AppColors.muted),
                  const SizedBox(width: 6),
                  Flexible(child: Text('Paiement Mobile Money sécurisé', style: AppText.caption)),
                ]),
              ]),
            ),
        ]),
          if (cart.items.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: tabBar,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    color: AppColors.background.withValues(alpha: 0.86),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Row(children: [
                      Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Total', style: AppText.caption),
                        Text(formatMoney(cart.total), style: AppText.price.copyWith(fontSize: 20)),
                      ]),
                      const SizedBox(width: 16),
                      Expanded(child: FilledButton(onPressed: () => _checkout(context), child: const Text('Passer la commande'))),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      );
    },
  );
}
