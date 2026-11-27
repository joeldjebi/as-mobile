import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../api.dart';
import '../cart.dart';
import '../theme.dart';
import '../widgets.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'reseller_screen.dart';
import 'shop_page.dart';

/// Fiche produit : galerie plein écran, variantes, prix de gros, boutique, ajout au panier (sans compte)
class ProductScreen extends StatefulWidget {
  final String id;
  /// Données déjà connues (carte cliquée) : affichage immédiat pendant le chargement
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
    if (!await requireAuth(context, reason: 'Connectez-vous pour signaler un produit')) return;
    if (!mounted) return;
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.fromLTRB(12, 8, 12, 4), child: Text('Signaler ce produit', style: AppText.headline)),
            const Padding(padding: EdgeInsets.fromLTRB(12, 0, 12, 12), child: Text('L’équipe Adjamé-Smart vérifiera rapidement.', style: AppText.bodyMuted)),
            for (final r in ['Contrefaçon', 'Produit interdit', 'Photo ou description trompeuse', 'Prix abusif', 'Autre problème'])
              ListTile(title: Text(r, style: AppText.body), trailing: const Icon(PhosphorIconsRegular.caretRight, size: 16, color: AppColors.faint), onTap: () => Navigator.pop(c, r)),
          ]),
        ),
      ),
    );
    if (reason == null) return;
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
    ));
    _addedSheet(p['name'] as String);
  }

  void _addedSheet(String name) => showModalBottomSheet(
    context: context,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(width: 44, height: 44, decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle), child: const Icon(PhosphorIconsBold.check, color: AppColors.primary, size: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Ajouté au panier', style: AppText.title),
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
              ]),
            ),
          ]),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              Navigator.pop(c);
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen(initialTab: 2)), (_) => false);
            },
            child: const Text('Voir le panier'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => Navigator.pop(c), child: const Text('Continuer mes achats')),
        ]),
      ),
    ),
  );

  Widget _stepper() => Container(
    height: 52,
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(28), border: Border.all(color: AppColors.line)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(icon: const Icon(PhosphorIconsBold.minus, size: 16), onPressed: _qty > 1 ? () => setState(() => _qty--) : null),
      SizedBox(width: 22, child: Text('$_qty', textAlign: TextAlign.center, style: AppText.title)),
      IconButton(icon: const Icon(PhosphorIconsBold.plus, size: 16), onPressed: () => setState(() => _qty++)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final p = _p ?? (widget.preview == null ? null : Map<String, dynamic>.from(widget.preview!));
    final top = MediaQuery.of(context).padding.top;
    if (p == null) {
      return Scaffold(
        body: Stack(children: [
          Center(
            child: _failed
                ? EmptyState(icon: PhosphorIconsLight.wifiSlash, title: 'Produit indisponible', text: 'Vérifiez votre connexion puis réessayez.', action: 'Réessayer', onAction: _load)
                : const CircularProgressIndicator(color: AppColors.ink, strokeWidth: 2),
          ),
          Positioned(top: top + 8, left: 16, child: RoundIconButton(PhosphorIconsRegular.arrowLeft, onTap: () => Navigator.pop(context))),
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

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Stack(children: [
            AspectRatio(
              aspectRatio: 4 / 5,
              child: photos.isEmpty
                  ? const NetImage(null, placeholder: PhosphorIconsLight.image)
                  : PageView.builder(
                      itemCount: photos.length,
                      onPageChanged: (i) => setState(() => _photo = i),
                      itemBuilder: (_, i) {
                        final img = NetImage(photos[i]);
                        return i == 0 ? Hero(tag: 'product-${p['id']}', child: img) : img;
                      },
                    ),
            ),
            Positioned(top: top + 8, left: 16, child: RoundIconButton(PhosphorIconsRegular.arrowLeft, onTap: () => Navigator.pop(context))),
            Positioned(top: top + 8, right: 16, child: RoundIconButton(PhosphorIconsRegular.flag, onTap: _report)),
            if (photos.length > 1)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < photos.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: i == _photo ? 20 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: i == _photo ? Colors.white : Colors.white60),
                    ),
                ]),
              ),
          ]),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (shop != null) Text((shop['name'] as String).toUpperCase(), style: AppText.overline),
              const SizedBox(height: 6),
              Text(p['name'] as String, style: AppText.headline),
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(formatMoney(price), style: AppText.price.copyWith(fontSize: 24)),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    out ? 'Épuisé' : stock == null ? 'Disponible' : stock <= 5 ? 'Plus que $stock' : 'En stock',
                    style: AppText.label.copyWith(color: out ? AppColors.warning : AppColors.success),
                  ),
                ),
              ]),
              if (p['hasWholesale'] == true) ...[
                const SizedBox(height: 18),
                p['wholesalePrice'] != null
                    ? StatusBanner(
                        icon: PhosphorIconsLight.package,
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
                          icon: PhosphorIconsLight.lockKey,
                          color: AppColors.accent,
                          title: 'Prix de gros pour les revendeurs',
                          text: reseller ? null : 'Vous revendez ? Demandez le statut pour voir ce prix.',
                        ),
                      ),
              ],
              if (variants.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(v == null ? 'CHOISIR UNE OPTION' : 'OPTION · ${(v['label'] as String).toUpperCase()}', style: AppText.overline),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final x in variants)
                    ChoiceChip(
                      showCheckmark: false,
                      label: Text(x['label'] as String),
                      selected: _variant == x['id'],
                      onSelected: (s) => setState(() => _variant = s ? x['id'] as String : null),
                    ),
                ]),
              ],
              if ((p['description'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 26),
                const Text('DESCRIPTION', style: AppText.overline),
                const SizedBox(height: 8),
                Text(p['description'] as String, style: AppText.body),
              ],
              if (shop != null) ...[
                const SizedBox(height: 26),
                Pressable(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopPage(slug: shop['slug'] as String))),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.line)),
                    child: Row(children: [
                      Container(width: 48, height: 48, decoration: const BoxDecoration(shape: BoxShape.circle), clipBehavior: Clip.antiAlias, child: NetImage(shop['logoUrl'] as String?, placeholder: PhosphorIconsLight.storefront)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(shop['name'] as String, style: AppText.title.copyWith(fontSize: 15.5)),
                          Text([if (shop['type'] == 'GROSSISTE') 'Grossiste', shop['market']].whereType<String>().join(' · '), style: AppText.caption),
                        ]),
                      ),
                      const Text('Voir', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(children: [
                const Icon(PhosphorIconsLight.moped, size: 20, color: AppColors.muted),
                const SizedBox(width: 10),
                Expanded(child: Text('Livré par LETO · frais de livraison payés en espèces au livreur', style: AppText.caption.copyWith(fontSize: 13))),
              ]),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ]),
      bottomNavigationBar: BottomActionBar(
        child: Row(children: [
          _stepper(),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: !loaded || out || shop == null ? null : () => _add(p, variants),
                child: Text(out ? 'Épuisé' : 'Ajouter · ${formatMoney(price * _qty)}'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
