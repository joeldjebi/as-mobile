import 'dart:io';

import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets.dart';
import 'prepay_picker.dart';

/// Ajout / modification d'un produit : photos (6 max), nom, catégorie, prix, prix de gros (grossistes), stock, variantes
class ProductFormScreen extends StatefulWidget {
  final Map<String, dynamic> shop;
  final Map<String, dynamic>? product;
  const ProductFormScreen({super.key, required this.shop, this.product});
  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _Variant {
  String? id;
  final label = TextEditingController();
  final price = TextEditingController();
  final stock = TextEditingController();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final api = Api.instance;
  late final Map<String, dynamic>? p = widget.product;
  late final _name = TextEditingController(text: p?['name']);
  late final _description = TextEditingController(text: p?['description']);
  late final _price = TextEditingController(text: p?['price']?.toString());
  late final _wholesale = TextEditingController(
    text: p?['wholesalePrice']?.toString(),
  );
  late final _minQty = TextEditingController(
    text: p?['wholesaleMinQty']?.toString(),
  );
  late final _stock = TextEditingController(text: p?['stock']?.toString());
  late final List<String> _photos = [
    ...((p?['photos'] as List?) ?? []).cast<String>(),
  ];
  late String? _categoryId = p?['categoryId'];
  late bool _trackStock = p?['stock'] != null;
  late int? _prepay = (p?['prepayPercent'] as num?)?.toInt();
  late bool _active = p == null || p!['status'] == 'ACTIVE';
  late final List<_Variant> _variants = [
    for (final v in ((p?['variants'] as List?) ?? []).cast<Map>())
      _Variant()
        ..id = v['id']
        ..label.text = v['label']
        ..price.text = v['price']?.toString() ?? ''
        ..stock.text = v['stock']?.toString() ?? '',
  ];
  List<dynamic> _categories = [];
  bool _uploading = false;
  bool _busy = false;

  bool get _grossiste => widget.shop['type'] == 'GROSSISTE';

  @override
  void initState() {
    super.initState();
    api
        .categories()
        .then((c) => mounted ? setState(() => _categories = c) : null)
        .catchError((Object e) {
          if (mounted) showError(context, e);
          return null;
        });
  }

  String get _categoryLabel {
    for (final c in _categories) {
      if (c['id'] == _categoryId) return c['name'];
      for (final s in (c['children'] as List)) {
        if (s['id'] == _categoryId) return '${c['name']} › ${s['name']}';
      }
    }
    return 'Choisir la catégorie';
  }

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(PhosphorIconsBold.camera),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(c, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(PhosphorIconsBold.image),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(c, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final f = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1400,
      imageQuality: 75,
    );
    if (f == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final url = await api.upload(File(f.path));
      if (mounted) setState(() => _photos.add(url));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickCategory() async {
    final shopCats = ((widget.shop['categoryIds'] as List?) ?? [])
        .cast<String>();
    final sorted = [..._categories]
      ..sort(
        (a, b) =>
            (shopCats.contains(b['id']) ? 1 : 0) -
            (shopCats.contains(a['id']) ? 1 : 0),
      );
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        builder: (_, scroll) => ListView(
          controller: scroll,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Catégorie', style: AppText.headline),
            ),
            for (final cat in sorted) ...[
              ListTile(
                title: Text(
                  cat['name'],
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () => Navigator.pop(c, cat['id'] as String),
              ),
              for (final s in (cat['children'] as List))
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 32, right: 16),
                  title: Text(s['name']),
                  onTap: () => Navigator.pop(c, s['id'] as String),
                ),
            ],
          ],
        ),
      ),
    );
    if (id != null) setState(() => _categoryId = id);
  }

  int? _int(TextEditingController c) =>
      int.tryParse(c.text.replaceAll(RegExp(r'\D'), ''));

  Future<void> _save() async {
    if (_photos.isEmpty) {
      return showError(context, 'Ajoutez au moins une photo');
    }
    if (_name.text.trim().isEmpty) {
      return showError(context, 'Indiquez le nom du produit');
    }
    if (_categoryId == null) {
      return showError(context, 'Choisissez la catégorie');
    }
    final price = _int(_price);
    if (price == null || price < 1) {
      return showError(context, 'Indiquez le prix');
    }
    final wholesale = _grossiste ? _int(_wholesale) : null;
    final body = {
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'categoryId': _categoryId,
      'photos': _photos,
      'price': price,
      'wholesalePrice': wholesale,
      'wholesaleMinQty': wholesale == null ? null : _int(_minQty),
      'stock': _trackStock && _variants.isEmpty ? (_int(_stock) ?? 0) : null,
      'prepayPercent': _prepay,
      'variants': [
        for (final v in _variants)
          if (v.label.text.trim().isNotEmpty)
            {
              'id': ?v.id,
              'label': v.label.text.trim(),
              'price': _int(v.price),
              'stock': _trackStock ? (_int(v.stock) ?? 0) : null,
            },
      ],
      'active': _active,
    };
    setState(() => _busy = true);
    try {
      if (p == null) {
        await api.createProduct({...body, 'shopId': widget.shop['id']});
      } else {
        await api.updateProduct(p!['id'], body);
      }
      if (!mounted) return;
      showInfo(context, p == null ? 'Produit ajouté' : 'Produit enregistré');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(p == null ? 'Nouveau produit' : 'Modifier le produit'),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: FilledButton(
          onPressed: _busy || _uploading ? null : _save,
          child: Text(_busy ? '…' : 'Enregistrer'),
        ),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (p?['status'] == 'REMOVED')
          StatusBanner(
            icon: PhosphorIconsFill.warningCircle,
            color: AppColors.accent,
            title: 'Retiré par Adjamé-Smart',
            text: p?['moderationNote'] as String?,
          ),
        const SectionTitle('Photos (6 maximum, la première est la principale)'),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < _photos.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 96,
                          height: 96,
                          child: NetImage(_photos[i], width: 96),
                        ),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: InkWell(
                          onTap: () => setState(() => _photos.removeAt(i)),
                          child: const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.black54,
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_photos.length < 6)
                InkWell(
                  onTap: _uploading ? null : _addPhoto,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 96,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _uploading
                        ? const Center(child: CupertinoActivityIndicator())
                        : const Icon(
                            PhosphorIconsBold.plus,
                            color: AppColors.primary,
                            size: 30,
                          ),
                  ),
                ),
            ],
          ),
        ),
        const SectionTitle('Le produit'),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Nom (ex. Écouteurs sans fil)',
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            title: Text(_categoryLabel),
            trailing: const Icon(PhosphorIconsBold.caretRight, size: 18),
            onTap: _pickCategory,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _description,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Description (facultatif)',
          ),
        ),
        const SectionTitle('Prix'),
        TextField(
          controller: _price,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Prix au détail',
            suffixText: 'F',
          ),
        ),
        if (_grossiste) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _wholesale,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Prix de gros',
                    suffixText: 'F',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _minQty,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'À partir de',
                    suffixText: 'pièces',
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Visible seulement par les revendeurs validés.',
              style: TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
          ),
        ],
        const SectionTitle('Paiement avant livraison'),
        PrepayPicker(
          value: _prepay,
          allowInherit: true,
          shopDefault: (widget.shop['prepayPercent'] as num?)?.toInt(),
          onChanged: (v) => setState(() => _prepay = v),
        ),
        const SectionTitle('Stock'),
        Card(
          child: SwitchListTile(
            title: const Text('Suivre le stock'),
            subtitle: const Text(
              'Sinon, le produit est toujours affiché disponible',
            ),
            value: _trackStock,
            onChanged: (v) => setState(() => _trackStock = v),
          ),
        ),
        if (_trackStock && _variants.isEmpty) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _stock,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Quantité en stock'),
          ),
        ],
        const SectionTitle('Variantes (taille, couleur…)'),
        for (final v in _variants)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: v.label,
                    decoration: const InputDecoration(hintText: 'Ex. Taille M'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: v.price,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Prix',
                      suffixText: 'F',
                    ),
                  ),
                ),
                if (_trackStock) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: v.stock,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Stock'),
                    ),
                  ),
                ],
                IconButton(
                  icon: const Icon(PhosphorIconsBold.trash, size: 20),
                  onPressed: () => setState(() => _variants.remove(v)),
                ),
              ],
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => setState(() => _variants.add(_Variant())),
          icon: const Icon(PhosphorIconsBold.plus),
          label: const Text('Ajouter une variante'),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'Prix de la variante vide = prix du produit.',
            style: TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
        ),
        const SizedBox(height: 12),
        if (p?['status'] != 'REMOVED')
          Card(
            child: SwitchListTile(
              title: const Text('Visible dans l’app'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
          ),
      ],
    ),
  );
}
