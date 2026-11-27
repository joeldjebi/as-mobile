import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../mode.dart';
import '../theme.dart';
import '../widgets.dart';
import 'orders_screen.dart';
import 'product_form_screen.dart';
import 'products_screen.dart';
import 'shop_form_screen.dart';
import 'shop_page.dart';

/// Repasse en profil client (même compte, même app)
Future<void> switchToClient(BuildContext context) async {
  Navigator.of(context).popUntil((r) => r.isFirst);
  await AppMode.instance.setSeller(false);
}

/// Profil boutique : Accueil · Commandes · Produits · Boutique
class SellerShell extends StatefulWidget {
  const SellerShell({super.key});
  @override
  State<SellerShell> createState() => _SellerShellState();
}

class _SellerShellState extends State<SellerShell> {
  List<Map<String, dynamic>>? _shops;
  String? _shopId;
  int _tab = 0;
  int _toConfirm = 0;
  Timer? _timer;

  Map<String, dynamic>? get _shop => _shops?.where((s) => s['id'] == _shopId).firstOrNull ?? _shops?.firstOrNull;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _countOrders());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final saved = (await SharedPreferences.getInstance()).getString('seller_shop');
    try {
      final list = (await Api.instance.myShops()).cast<Map>().map((s) => Map<String, dynamic>.from(s)).toList();
      if (!mounted) return;
      setState(() {
        _shops = list;
        _shopId = list.any((s) => s['id'] == (_shopId ?? saved)) ? (_shopId ?? saved) : list.firstOrNull?['id'] as String?;
      });
      _countOrders();
    } catch (_) {
      if (mounted) setState(() => _shops ??= []);
    }
  }

  Future<void> _countOrders() async {
    final s = _shop;
    if (s == null || s['status'] != 'APPROVED') return;
    try {
      final o = (await Api.instance.shopOrders(s['id'] as String)).cast<Map>();
      final n = o.where((x) => x['status'] == 'PAYMENT_DECLARED' && (x['payment'] as Map?)?['mode'] == 'DIRECT').length;
      if (mounted && n != _toConfirm) {
        if (n > _toConfirm) HapticFeedback.mediumImpact();
        setState(() => _toConfirm = n);
      }
    } catch (_) {}
  }

  Future<void> _pickShop() async {
    final id = await showCupertinoModalPopup<String>(
      context: context,
      builder: (c) => CupertinoActionSheet(
        title: const Text('Choisir la boutique'),
        actions: [
          for (final s in _shops!)
            CupertinoActionSheetAction(onPressed: () => Navigator.pop(c, s['id'] as String), child: Text(s['id'] == _shop?['id'] ? '${s['name']}  ✓' : s['name'] as String)),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
      ),
    );
    if (id == null || id == _shop?['id']) return;
    (await SharedPreferences.getInstance()).setString('seller_shop', id);
    setState(() { _shopId = id; _toConfirm = 0; });
    _countOrders();
  }

  @override
  Widget build(BuildContext context) {
    final shop = _shop;
    if (_shops == null) return const Scaffold(body: Loader(padding: 80));
    if (shop == null) return _NoShop(onCreated: _load);
    final key = ValueKey(shop['id']);
    return Scaffold(
      body: IndexedStack(index: _tab, children: [
        SellerHome(key: key, shop: shop, shopCount: _shops!.length, onPickShop: _pickShop, onTab: (i) => setState(() => _tab = i), onChanged: _load),
        ShopOrdersScreen(key: key, shop: shop),
        ProductsScreen(key: key, shop: shop),
        ShopFormScreen(key: key, shop: shop),
      ]),
      bottomNavigationBar: _SellerTabBar(index: _tab, badge: _toConfirm, onTap: (i) {
        setState(() => _tab = i);
        if (i == 0) _load();
      }),
    );
  }
}

class _SellerTabBar extends StatelessWidget {
  final int index;
  final int badge;
  final ValueChanged<int> onTap;
  const _SellerTabBar({required this.index, required this.badge, required this.onTap});

  Widget _item(int i, IconData icon, IconData active, String label, {int count = 0}) {
    final on = index == i;
    final color = on ? AppColors.primary : AppColors.ink.withValues(alpha: 0.72);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: on ? AppColors.primary.withValues(alpha: 0.11) : Colors.transparent, borderRadius: BorderRadius.circular(24)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Stack(clipBehavior: Clip.none, children: [
              Icon(on ? active : icon, size: 21, color: color),
              if (count > 0)
                Positioned(
                  right: -9,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 0.5),
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(9)),
                    child: Text('$count', textAlign: TextAlign.center, style: AppText.caption.copyWith(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white, height: 1.4)),
                  ),
                ),
            ]),
            const SizedBox(height: 2),
            Text(label, style: AppText.caption.copyWith(fontSize: 10, fontWeight: on ? FontWeight.w600 : FontWeight.w500, color: color, letterSpacing: 0)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 6, 14, b > 0 ? b - 6 : 12),
      child: SizedBox(
        height: 58,
        child: Glass(
          radius: BorderRadius.circular(29),
          child: Row(children: [
            _item(0, CupertinoIcons.square_grid_2x2, CupertinoIcons.square_grid_2x2_fill, 'Accueil'),
            _item(1, CupertinoIcons.tray, CupertinoIcons.tray_full_fill, 'Commandes', count: badge),
            _item(2, CupertinoIcons.cube_box, CupertinoIcons.cube_box_fill, 'Produits'),
            _item(3, CupertinoIcons.building_2_fill, CupertinoIcons.building_2_fill, 'Boutique'),
          ]),
        ),
      ),
    );
  }
}

/// Accueil du profil boutique : à traiter, ventes, catalogue, raccourcis
class SellerHome extends StatefulWidget {
  final Map<String, dynamic> shop;
  final int shopCount;
  final VoidCallback onPickShop;
  final ValueChanged<int> onTab;
  final VoidCallback onChanged;
  const SellerHome({super.key, required this.shop, required this.shopCount, required this.onPickShop, required this.onTab, required this.onChanged});
  @override
  State<SellerHome> createState() => _SellerHomeState();
}

class _SellerHomeState extends State<SellerHome> {
  List<Map>? _orders;
  List<Map>? _products;
  late bool _open = widget.shop['isOpen'] != false;

  Map<String, dynamic> get s => widget.shop;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([
        if (s['status'] == 'APPROVED') Api.instance.shopOrders(s['id'] as String) else Future.value(<dynamic>[]),
        Api.instance.myProducts(s['id'] as String),
      ]);
      if (mounted) setState(() { _orders = r[0].cast<Map>(); _products = r[1].cast<Map>(); });
    } catch (_) {
      if (mounted) setState(() { _orders ??= []; _products ??= []; });
    }
  }

  Future<void> _toggleOpen(bool v) async {
    setState(() => _open = v);
    try {
      await Api.instance.updateShop(s['id'] as String, {'isOpen': v});
      if (mounted) showInfo(context, v ? 'Boutique ouverte' : 'Boutique fermée pour le moment');
      widget.onChanged();
    } catch (e) {
      if (mounted) { setState(() => _open = !v); showError(context, e); }
    }
  }

  Widget _tile(String label, String value, String foot, IconData icon, Color color, {VoidCallback? onTap}) => Expanded(
    child: Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 6), Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption))]),
          const SizedBox(height: 8),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: AppText.title1.copyWith(fontSize: 24))),
          const SizedBox(height: 2),
          Text(foot, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(fontSize: 11)),
        ]),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final o = _orders ?? [];
    final p = _products ?? [];
    final since = DateTime.now().subtract(const Duration(days: 30));
    final toConfirm = o.where((x) => x['status'] == 'PAYMENT_DECLARED' && (x['payment'] as Map?)?['mode'] == 'DIRECT').length;
    final live = o.where((x) => x['status'] == 'IN_DELIVERY' || x['status'] == 'PAID').length;
    final sold = o.where((x) => ['PAID', 'IN_DELIVERY', 'DELIVERED'].contains(x['status']) && DateTime.parse(x['createdAt'] as String).isAfter(since)).toList();
    final revenue = sold.fold<num>(0, (t, x) => t + (x['goodsTotal'] as num));
    final online = p.where((x) => x['status'] == 'ACTIVE').length;
    final out = p.where((x) => x['status'] == 'ACTIVE' && x['totalStock'] != null && (x['totalStock'] as num) <= 0).length;
    final status = s['status'] as String?;
    final note = switch (status) {
      'DRAFT' => ('Dossier à compléter', 'Finalisez et envoyez votre dossier dans l’onglet Boutique.'),
      'PENDING' => ('Dossier en vérification', 'Vous pouvez déjà ajouter vos produits.'),
      'REJECTED' => ('Dossier à corriger', (s['reviewNote'] as String?) ?? 'Corrigez puis renvoyez votre dossier.'),
      'SUSPENDED' => ('Boutique suspendue', 'Contactez l’équipe Adjamé-Smart.'),
      _ => null,
    };
    return Scaffold(
      body: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()), slivers: [
        LargeTitleBar(s['name'] as String, trailing: BarButton('Mode client', onTap: () => switchToClient(context))),
        CupertinoSliverRefreshControl(onRefresh: _load),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverList.list(children: [
            if (widget.shopCount > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Group(children: [Cell(leading: const SettingsIcon(CupertinoIcons.building_2_fill), title: 'Changer de boutique', value: '${widget.shopCount} boutiques', onTap: widget.onPickShop)]),
              ),
            if (note != null) ...[
              StatusBanner(icon: CupertinoIcons.info_circle_fill, color: AppColors.accent, title: note.$1, text: note.$2),
              const SizedBox(height: 12),
            ],
            Row(children: [
              _tile('À confirmer', '$toConfirm', toConfirm > 0 ? 'Paiements reçus ?' : 'Rien en attente', CupertinoIcons.tray_full_fill, AppColors.accent, onTap: () => widget.onTab(1)),
              const SizedBox(width: 10),
              _tile('En livraison', '$live', 'Livreurs VITE', CupertinoIcons.car_fill, AppColors.primary, onTap: () => widget.onTab(1)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _tile('Ventes 30 jours', formatMoney(revenue), '${sold.length} commande(s) payée(s)', CupertinoIcons.money_dollar_circle_fill, AppColors.success),
              const SizedBox(width: 10),
              _tile('En ligne', '$online', out > 0 ? '$out épuisé(s)' : '${p.length} produit(s)', CupertinoIcons.cube_box_fill, const Color(0xFF2F6F7E), onTap: () => widget.onTab(2)),
            ]),
            const SectionTitle('Raccourcis'),
            Group(dividerIndent: 56, children: [
              Cell(
                leading: const SettingsIcon(CupertinoIcons.plus),
                title: 'Ajouter un produit',
                onTap: () async {
                  await Navigator.push(context, CupertinoPageRoute(builder: (_) => ProductFormScreen(shop: s)));
                  _load();
                },
              ),
              if (status == 'APPROVED')
                Cell(
                  leading: SettingsIcon(_open ? CupertinoIcons.lock_open_fill : CupertinoIcons.lock_fill, color: _open ? AppColors.success : AppColors.muted),
                  title: _open ? 'Boutique ouverte' : 'Boutique fermée',
                  subtitle: _open ? 'Les clients peuvent commander' : 'Les clients voient « Fermée »',
                  trailing: CupertinoSwitch(value: _open, activeTrackColor: AppColors.primary, onChanged: _toggleOpen),
                ),
              if (status == 'APPROVED')
                Cell(leading: const SettingsIcon(CupertinoIcons.eye_fill, color: AppColors.accent), title: 'Voir ma boutique comme un client', onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => ShopPage(slug: s['slug'] as String)))),
              Cell(leading: const SettingsIcon(CupertinoIcons.desktopcomputer, color: Color(0xFF2F6F7E)), title: 'Gérer depuis un ordinateur', subtitle: 'boutique.vite.ci, avec le même compte'),
            ]),
            if (o.isNotEmpty) ...[
              const SectionTitle('Dernières commandes'),
              Group(children: [
                for (final x in o.take(4))
                  Cell(
                    title: '${x['number']} · ${x['recipientName']}',
                    subtitle: orderStatusLabel(x),
                    value: formatMoney(x['goodsTotal'] as num),
                    onTap: () => widget.onTab(1),
                  ),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// Pas encore de boutique : l'ouvrir, ou revenir au profil client
class _NoShop extends StatelessWidget {
  final VoidCallback onCreated;
  const _NoShop({required this.onCreated});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: EmptyState(
          icon: CupertinoIcons.building_2_fill,
          title: 'Ouvrez votre boutique',
          text: 'Vendez à tout Abidjan depuis votre téléphone. Inscription gratuite, livraison par VITE.',
          action: 'Ouvrir ma boutique',
          onAction: () async {
            await Navigator.push(context, CupertinoPageRoute(builder: (_) => const ShopFormScreen()));
            onCreated();
          },
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(child: TextButton(onPressed: () => switchToClient(context), child: const Text('Revenir au profil client'))),
  );
}
