import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../api.dart';
import '../cart.dart';
import '../theme.dart';
import '../widgets.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'reseller_screen.dart';
import 'shop_page.dart';

/// Fiche produit : galerie plein écran, options, prix de gros, boutique, ajout au panier (sans compte)
class ProductScreen extends StatefulWidget {
  final String id;
  /// Données déjà connues (carte touchée) : affichage immédiat pendant le chargement
  final Map? preview;
  const ProductScreen({super.key, required this.id, this.preview});
  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  Map<String, dynamic>? _p;
  String? _variant;
  int _photo = 0;
  int _qty = 1;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final p = await Api.instance.product(widget.id);
      if (mounted) setState(() => _p = p);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _report() async {
    final reason = await showCupertinoModalPopup<String>(
      context: context,
      builder: (c) => CupertinoActionSheet(
        title: const Text('Signaler ce produit'),
        message: const Text('L’équipe Adjamé-Smart vérifiera rapidement.'),
        actions: [
          for (final r in ['Contrefaçon', 'Produit interdit', 'Photo ou description trompeuse', 'Prix abusif', 'Autre problème'])
            CupertinoActionSheetAction(onPressed: () => Navigator.pop(c, r), child: Text(r)),
        ],
        cancelButton: CupertinoActionSheetAction(isDefaultAction: true, onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
      ),
    );
    if (reason == null || !mounted) return;
    if (!await requireAuth(context, reason: 'Connectez-vous pour signaler un produit')) return;
    try {
      await Api.instance.reportProduct(widget.id, reason);
      if (mounted) showInfo(context, 'Merci, nous allons vérifier ce produit');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _add(Map<String, dynamic> p, List<Map> variants) {
    if (variants.isNotEmpty && _variant == null) {
      showError(context, 'Choisissez d’abord une option');
      return;
    }
    final v = variants.where((x) => x['id'] == _variant).firstOrNull;
    final shop = p['shop'] as Map;
    final photos = (p['photos'] as List).cast<String>();
    Cart.instance.add(CartItem(
      productId: p['id'] as String,
      variantId: v?['id'] as String?,
      name: p['name'] as String,
      variantLabel: v?['label'] as String?,
      photo: photos.isEmpty ? null : photos.first,
      price: ((v?['price'] ?? p['price']) as num).toInt(),
      shopId: shop['id'] as String,
      shopName: shop['name'] as String,
      qty: _qty,
      prepayPercent: (p['prepayPercent'] as num?)?.toInt() ?? 100,
    ));
    HapticFeedback.mediumImpact();
    _addedSheet(p['name'] as String, photos.isEmpty ? null : photos.first);
  }

  void _addedSheet(String name, String? photo) => showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 56, height: 56, child: NetImage(photo, width: 56))),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(CupertinoIcons.checkmark_alt_circle_fill, color: AppColors.success, size: 18),
                  const SizedBox(width: 6),
                  Text('Ajouté au panier', style: AppText.label.copyWith(color: AppColors.success)),
                ]),
                const SizedBox(height: 2),
                Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.subhead),
              ]),
            ),
          ]),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              Navigator.pop(c);
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen(initialTab: HomeScreen.cartTab)), (_) => false);
            },
            child: const Text('Voir le panier'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: () => Navigator.pop(c), child: const Text('Continuer mes achats')),
        ]),
      ),
    ),
  );

  /// Option (taille, couleur…) : contour fin, contour teinté une fois choisie
  Widget _option(Map x, bool selected) => Pressable(
    onTap: () => setState(() => _variant = selected ? null : x['id'] as String),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.primarySoft : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? AppColors.primary : AppColors.separator, width: selected ? 2 : 1),
      ),
      child: Text(x['label'] as String, style: AppText.subhead.copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? AppColors.primary : AppColors.ink)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = _p ?? (widget.preview == null ? null : Map<String, dynamic>.from(widget.preview!));
    final top = MediaQuery.of(context).padding.top;
    final back = Positioned(top: top + 6, left: 16, child: RoundIconButton(CupertinoIcons.chevron_back, onTap: () => Navigator.pop(context)));
    if (p == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: Stack(children: [
          Center(child: _failed ? EmptyState(icon: CupertinoIcons.wifi_slash, title: 'Produit indisponible', text: 'Vérifiez votre connexion Internet puis réessayez.', action: 'Réessayer', onAction: _load) : const Loader()),
          back,
        ]),
      );
    }
    final photos = ((p['photos'] as List?) ?? []).cast<String>();
    final variants = ((p['variants'] as List?) ?? []).cast<Map>();
    final v = variants.where((x) => x['id'] == _variant).firstOrNull;
    final price = (v?['price'] ?? p['price']) as num;
    final stock = v != null ? v['stock'] as num? : p['stock'] as num?;
    final out = stock != null && stock <= 0;
    final shop = p['shop'] as Map?;
    final loaded = _p != null;
    final reseller = Api.instance.user?['resellerStatus'] == 'APPROVED';
    final prepay = (p['prepayPercent'] as num?)?.toInt() ?? 100;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(physics: const BouncingScrollPhysics(), slivers: [
        SliverToBoxAdapter(
          child: Stack(children: [
            AspectRatio(
              aspectRatio: 4 / 5,
              child: photos.isEmpty
                  ? const NetImage(null)
                  : PageView.builder(
                      itemCount: photos.length,
                      onPageChanged: (i) => setState(() => _photo = i),
                      itemBuilder: (_, i) {
                        final img = NetImage(photos[i], width: 430, previewWidth: 180);
                        return i == 0 ? Hero(tag: 'product-${p['id']}', child: img) : img;
                      },
                    ),
            ),
            back,
            Positioned(top: top + 6, right: 16, child: RoundIconButton(CupertinoIcons.flag, onTap: _report)),
            if (photos.length > 1)
              Positioned(
                bottom: 14,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      for (var i = 0; i < photos.length; i++)
                        Container(width: 7, height: 7, margin: const EdgeInsets.symmetric(horizontal: 3.5), decoration: BoxDecoration(shape: BoxShape.circle, color: i == _photo ? Colors.white : Colors.white54)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (shop != null)
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopPage(slug: shop['slug'] as String))),
                  child: Text(shop['name'] as String, style: AppText.subhead.copyWith(color: AppColors.primary)),
                ),
              const SizedBox(height: 4),
              Text(p['name'] as String, style: AppText.title1.copyWith(fontSize: 22)),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text(formatMoney(price), style: AppText.price.copyWith(fontSize: 19)),
                const SizedBox(width: 10),
                Text(
                  out ? 'Épuisé' : stock == null ? 'Disponible' : stock <= 5 ? 'Plus que $stock' : 'En stock',
                  style: AppText.subhead.copyWith(color: out ? AppColors.warning : AppColors.success),
                ),
              ]),
              if (p['hasWholesale'] == true) ...[
                const SizedBox(height: 18),
                p['wholesalePrice'] != null
                    ? StatusBanner(
                        background: AppColors.primarySoft,
                        icon: CupertinoIcons.cube_box_fill,
                        color: AppColors.primary,
                        title: 'Prix de gros : ${formatMoney(p['wholesalePrice'] as num)}',
                        text: 'À partir de ${p['wholesaleMinQty']} pièces',
                      )
                    : Pressable(
                        onTap: () async {
                          if (!await requireAuth(context, reason: 'Connectez-vous pour demander le statut revendeur')) return;
                          if (!context.mounted) return;
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => const ResellerScreen()));
                          _load();
                        },
                        child: StatusBanner(
                          background: AppColors.surfaceAlt,
                          icon: CupertinoIcons.lock_fill,
                          color: AppColors.accent,
                          title: 'Prix de gros réservé aux revendeurs',
                          text: reseller ? null : 'Vous revendez ? Demandez le statut pour voir ce prix.',
                        ),
                      ),
              ],
              if (variants.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(v == null ? 'Choisissez une option' : 'Option : ${v['label']}', style: AppText.label),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [for (final x in variants) _option(x, _variant == x['id'])]),
              ],
              if ((p['description'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 26),
                const Text('Description', style: AppText.headline),
                const SizedBox(height: 8),
                Text(p['description'] as String, style: AppText.body.copyWith(height: 1.45)),
              ],
              const SizedBox(height: 26),
              Group(color: AppColors.surfaceAlt, dividerIndent: 60, children: [
                if (shop != null)
                  Cell(
                    leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 30, height: 30, child: NetImage(shop['logoUrl'] as String?, width: 30, placeholder: CupertinoIcons.building_2_fill))),
                    title: shop['name'] as String,
                    subtitle: [shop['type'] == 'GROSSISTE' ? 'Grossiste' : 'Boutique', shop['market']].whereType<String>().join(' · '),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopPage(slug: shop['slug'] as String))),
                  ),
                const Cell(leading: SettingsIcon(PhosphorIconsFill.moped), title: 'Livré par LETO', subtitle: 'Frais de livraison payés en espèces au livreur'),
                Cell(
                  leading: const SettingsIcon(CupertinoIcons.creditcard, color: AppColors.accent),
                  title: prepay >= 100 ? 'Payé en entier à la commande' : 'Acompte de $prepay % à la commande',
                  subtitle: prepay >= 100
                      ? 'Mobile Money ; colis remis une fois le paiement confirmé'
                      : '${formatMoney((price * _qty * prepay / 100).round())} en Mobile Money, ${formatMoney(price * _qty - (price * _qty * prepay / 100).round())} à la livraison',
                ),
              ]),
              SizedBox(height: tabBarHeight(context) + 20),
            ]),
          ),
        ),
      ]),
      extendBody: true,
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(14, 0, 14, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom - 6 : 12),
        child: Glass(
          radius: BorderRadius.circular(30),
          opacity: 0.8,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(children: [
              QtyStepper(qty: _qty, onChanged: (q) => setState(() => _qty = q)),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: !loaded || out || shop == null ? null : () => _add(p, variants),
                  child: FittedBox(child: Text(out ? 'Épuisé' : 'Ajouter · ${formatMoney(price * _qty)}')),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
