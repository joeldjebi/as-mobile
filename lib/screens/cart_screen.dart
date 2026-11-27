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
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 56, height: 56, alignment: Alignment.center, decoration: const BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle), child: const Icon(PhosphorIconsLight.moped, color: AppColors.accent, size: 28)),
            const SizedBox(height: 16),
            const Text('La commande arrive très bientôt', textAlign: TextAlign.center, style: AppText.headline),
            const SizedBox(height: 8),
            const Text('Votre panier est gardé. Vous pourrez bientôt payer vos articles par Mobile Money et être livré par LETO.', textAlign: TextAlign.center, style: AppText.bodyMuted),
            const SizedBox(height: 22),
            FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Compris')),
          ]),
        ),
      ),
    );
  }

  Widget _line(CartItem i) => Padding(
    padding: const EdgeInsets.all(14),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(borderRadius: BorderRadius.circular(14), child: SizedBox(width: 76, height: 92, child: NetImage(i.photo))),
      const SizedBox(width: 14),
      Expanded(
        child: SizedBox(
          height: 92,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(i.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.label.copyWith(fontWeight: FontWeight.w500, fontSize: 14, height: 1.3)),
            if (i.variantLabel != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(i.variantLabel!, style: AppText.caption)),
            const Spacer(),
            Row(children: [
              Expanded(child: Text(formatMoney(i.price * i.qty), style: AppText.price)),
              _Stepper(qty: i.qty, onChanged: (q) => Cart.instance.setQty(i, q)),
            ]),
          ]),
        ),
      ),
    ]),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Cart.instance,
    builder: (context, _) {
      final cart = Cart.instance;
      final groups = cart.byShop.values.toList();
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: cart.items.isEmpty
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 0), child: Text('Panier', style: AppText.display)),
                  Expanded(child: Center(child: EmptyState(icon: PhosphorIconsLight.handbag, title: 'Votre panier est vide', text: 'Parcourez les boutiques d’Adjamé et ajoutez vos coups de cœur.', action: 'Découvrir', onAction: onBrowse))),
                ])
              : ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Expanded(child: Text('Panier', style: AppText.display)),
                    TextButton(
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Vider le panier ?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
                              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Vider')),
                            ],
                          ),
                        );
                        if (ok == true) cart.clear();
                      },
                      child: const Text('Vider', style: TextStyle(color: AppColors.muted)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text('${cart.count} ${cart.count > 1 ? 'articles' : 'article'} · ${groups.length} ${groups.length > 1 ? 'boutiques' : 'boutique'}', style: AppText.caption),
                  for (final g in groups) ...[
                    const SizedBox(height: 22),
                    Row(children: [
                      const Icon(PhosphorIconsLight.storefront, size: 18, color: AppColors.ink),
                      const SizedBox(width: 8),
                      Expanded(child: Text(g.first.shopName, style: AppText.title.copyWith(fontSize: 15.5))),
                      Text(formatMoney(g.fold<int>(0, (t, i) => t + i.price * i.qty)), style: AppText.caption),
                    ]),
                    const SizedBox(height: 10),
                    Group(children: [for (final i in g) _line(i)]),
                  ],
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(18)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(PhosphorIconsLight.moped, color: AppColors.ink, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          groups.length > 1
                              ? 'Une livraison LETO par boutique (${groups.length}). Les frais sont payés en espèces aux livreurs.'
                              : 'Livraison LETO : les frais sont payés en espèces au livreur.',
                          style: AppText.body.copyWith(fontSize: 13.5),
                        ),
                      ),
                    ]),
                  ),
                ]),
        ),
        bottomNavigationBar: cart.items.isEmpty
            ? null
            : BottomActionBar(
                child: Row(children: [
                  Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Articles', style: AppText.caption),
                    Text(formatMoney(cart.total), style: AppText.price.copyWith(fontSize: 20)),
                  ]),
                  const SizedBox(width: 16),
                  Expanded(child: SizedBox(height: 52, child: FilledButton(onPressed: () => _checkout(context), child: const Text('Passer la commande')))),
                ]),
              ),
      );
    },
  );
}

class _Stepper extends StatelessWidget {
  final int qty;
  final ValueChanged<int> onChanged;
  const _Stepper({required this.qty, required this.onChanged});
  Widget _btn(IconData icon, VoidCallback onTap) => Pressable(
    onTap: onTap,
    child: Container(width: 30, height: 30, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.line)), child: Icon(icon, size: 14, color: AppColors.ink)),
  );
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    _btn(qty == 1 ? PhosphorIconsRegular.trash : PhosphorIconsBold.minus, () => onChanged(qty - 1)),
    SizedBox(width: 32, child: Text('$qty', textAlign: TextAlign.center, style: AppText.label)),
    _btn(PhosphorIconsBold.plus, () => onChanged(qty + 1)),
  ]);
}
