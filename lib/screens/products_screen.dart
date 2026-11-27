import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets.dart';
import 'product_form_screen.dart';

/// Vendeur : produits d'une boutique (visible / masqué, stock, dupliquer, supprimer)
class ProductsScreen extends StatefulWidget {
  final Map<String, dynamic> shop;
  const ProductsScreen({super.key, required this.shop});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final api = Api.instance;
  List<dynamic>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await api.myProducts(widget.shop['id']);
      if (mounted) setState(() => _items = r);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _edit([Map<String, dynamic>? p]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(shop: widget.shop, product: p),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _run(Future<void> Function() f, String done) async {
    try {
      await f();
      if (!mounted) return;
      showInfo(context, done);
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _menu(Map p) async {
    final a = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(PhosphorIconsBold.pencilSimple),
              title: const Text('Modifier'),
              onTap: () => Navigator.pop(c, 'edit'),
            ),
            ListTile(
              leading: const Icon(PhosphorIconsBold.copy),
              title: const Text('Dupliquer'),
              onTap: () => Navigator.pop(c, 'dup'),
            ),
            if (p['status'] != 'REMOVED' && p['totalStock'] != 0)
              ListTile(
                leading: const Icon(PhosphorIconsBold.prohibit),
                title: const Text('Marquer en rupture'),
                onTap: () => Navigator.pop(c, 'out'),
              ),
            ListTile(
              leading: const Icon(
                PhosphorIconsBold.trash,
                color: AppColors.danger,
              ),
              title: const Text('Supprimer'),
              onTap: () => Navigator.pop(c, 'del'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || a == null) return;
    switch (a) {
      case 'edit':
        return _edit(Map<String, dynamic>.from(p));
      case 'dup':
        return _run(
          () => api.duplicateProduct(p['id']),
          'Copie créée (masquée) : modifiez-la puis rendez-la visible',
        );
      case 'out':
        final variants = ((p['variants'] as List?) ?? []).cast<Map>();
        return _run(
          () => api.updateProduct(
            p['id'],
            variants.isEmpty
                ? {'stock': 0}
                : {
                    'variants': [
                      for (final v in variants) {...v, 'stock': 0},
                    ],
                  },
          ),
          'Produit en rupture',
        );
      case 'del':
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Supprimer ce produit ?'),
            content: Text(p['name'] as String),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        );
        if (ok == true) {
          return _run(() => api.deleteProduct(p['id']), 'Produit supprimé');
        }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mes produits')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _edit(),
      icon: const Icon(PhosphorIconsBold.plus),
      label: const Text('Ajouter'),
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: _items == null
          ? const Center(child: CupertinoActivityIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                if (widget.shop['status'] != 'APPROVED')
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: StatusBanner(
                      icon: PhosphorIconsBold.info,
                      color: AppColors.accent,
                      title: 'Boutique pas encore en ligne',
                      text:
                          'Préparez vos produits : ils seront visibles dès que la boutique sera validée.',
                    ),
                  ),
                if (_items!.isEmpty)
                  const StatusBanner(
                    icon: PhosphorIconsFill.package,
                    color: AppColors.primary,
                    title: 'Aucun produit',
                    text:
                        'Touchez « Ajouter » : une photo, un nom, un prix, et c’est en ligne.',
                  ),
                for (final p in _items!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(8),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            // Miniature en cache plutôt que la photo pleine taille
                            child: NetImage(
                              (p['photos'] as List).firstOrNull as String?,
                              width: 56,
                            ),
                          ),
                        ),
                        title: Text(
                          p['name'] as String,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          [
                            formatMoney(p['price'] as num),
                            p['totalStock'] == null
                                ? 'stock non suivi'
                                : p['totalStock'] == 0
                                ? 'rupture'
                                : '${p['totalStock']} en stock',
                            if (p['status'] == 'REMOVED')
                              'retiré par Adjamé-Smart'
                            else if ((p['reports'] ?? 0) > 0)
                              'signalé',
                          ].join(' · '),
                        ),
                        trailing: p['status'] == 'REMOVED'
                            ? const Icon(
                                PhosphorIconsFill.warningCircle,
                                color: AppColors.warning,
                              )
                            : Switch(
                                value: p['status'] == 'ACTIVE',
                                onChanged: (v) => _run(
                                  () =>
                                      api.updateProduct(p['id'], {'active': v}),
                                  v ? 'Produit visible' : 'Produit masqué',
                                ),
                              ),
                        onTap: () => _menu(p as Map),
                      ),
                    ),
                  ),
              ],
            ),
    ),
  );
}
