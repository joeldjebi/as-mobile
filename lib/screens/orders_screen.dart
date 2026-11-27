import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../addresses.dart';
import '../api.dart';
import '../cart.dart';
import '../theme.dart';
import '../widgets.dart';

// ============================================================================
// Statuts
// ============================================================================

String orderStatusLabel(Map o) => switch (o['status']) {
  'AWAITING_PAYMENT' => 'À payer',
  'PAYMENT_DECLARED' => 'Paiement en vérification',
  'PAID' => 'Payée · livreur demandé',
  'IN_DELIVERY' => (o['deliveryLabel'] as String?) ?? 'En livraison',
  'DELIVERED' => 'Livrée',
  'CANCELLED' => 'Annulée',
  'FAILED' => 'Livraison impossible',
  _ => '${o['status']}',
};

Color orderStatusColor(String? s) => switch (s) {
  'AWAITING_PAYMENT' => AppColors.accent,
  'DELIVERED' => AppColors.success,
  'CANCELLED' || 'FAILED' => AppColors.muted,
  _ => AppColors.primary,
};

String _date(String? iso) {
  if (iso == null) return '';
  final d = DateTime.parse(iso).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)} à ${two(d.hour)}:${two(d.minute)}';
}

/// Saisie d'un motif (refus, annulation)
Future<String?> askNote(BuildContext context, String title, {String placeholder = 'Motif'}) {
  final c = TextEditingController();
  return showCupertinoDialog<String>(
    context: context,
    builder: (d) => CupertinoAlertDialog(
      title: Text(title),
      content: Padding(padding: const EdgeInsets.only(top: 12), child: CupertinoTextField(controller: c, placeholder: placeholder, autofocus: true)),
      actions: [
        CupertinoDialogAction(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
        CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(d, c.text.trim().isEmpty ? null : c.text.trim()), child: const Text('Valider')),
      ],
    ),
  );
}

// ============================================================================
// Finaliser la commande
// ============================================================================

/// Adresse, destinataire, récapitulatif par boutique (acompte, reste, livraison estimée), confirmation
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final api = Api.instance;
  String? _addressId;
  late final _name = TextEditingController(text: api.user?['name'] as String? ?? '');
  late final _phone = TextEditingController(text: ((api.user?['phone'] as String?) ?? '').replaceFirst('+225', ''));
  final _note = TextEditingController();
  Map<String, dynamic>? _quote;
  String? _quoteError;
  bool _busy = false;

  List<Map> get _addresses => ((api.user?['addresses'] as List?) ?? []).cast<Map>();
  List<Map<String, dynamic>> get _items => [for (final i in Cart.instance.items) {'productId': i.productId, 'variantId': i.variantId, 'qty': i.qty}];

  @override
  void initState() {
    super.initState();
    _addressId = _addresses.firstOrNull?['id'] as String?;
    api.refreshMe().then((_) {
      if (!mounted) return;
      setState(() => _addressId ??= _addresses.firstOrNull?['id'] as String?);
      _loadQuote();
    }).catchError((_) {
      _loadQuote();
    });
  }

  Future<void> _loadQuote() async {
    setState(() { _quoteError = null; });
    try {
      final q = await api.orderQuote({'items': _items, 'addressId': ?_addressId});
      if (mounted) setState(() => _quote = q);
    } catch (e) {
      if (mounted) setState(() => _quoteError = e.toString());
    }
  }

  Future<void> _addAddress() async {
    final id = await addAddressSheet(context);
    if (id != null && mounted) {
      setState(() => _addressId = id);
      _loadQuote();
    }
  }

  Future<void> _confirm() async {
    if (_addressId == null) return showError(context, 'Ajoutez une adresse de livraison');
    final phone = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (phone.length != 10) return showError(context, 'Téléphone du destinataire : 10 chiffres');
    setState(() => _busy = true);
    try {
      final r = await api.checkout({
        'items': _items,
        'addressId': _addressId,
        'recipientName': _name.text.trim(),
        'recipientPhone': phone,
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
      });
      Cart.instance.clear();
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.pushReplacement(context, CupertinoPageRoute(builder: (_) => CheckoutDoneScreen(orders: (r['orders'] as List).cast<Map>())));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _row(String label, Widget field) => Padding(
    padding: const EdgeInsets.only(left: 14),
    child: Row(children: [SizedBox(width: 92, child: Text(label, style: AppText.body)), Expanded(child: field)]),
  );

  @override
  Widget build(BuildContext context) {
    final q = _quote;
    final shops = ((q?['shops'] as List?) ?? []).cast<Map>();
    final fee = q?['deliveryFeeEstimate'] as num?;
    return Scaffold(
      body: Stack(children: [
        CustomScrollView(physics: const BouncingScrollPhysics(), slivers: [
          const LargeTitleBar('Commande'),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, tabBarHeight(context) + 40),
            sliver: SliverList.list(children: [
              const SectionTitle('Livraison'),
              Group(dividerIndent: 48, children: [
                for (final a in _addresses)
                  Cell(
                    leading: Icon(CupertinoIcons.location_fill, size: 20, color: _addressId == a['id'] ? AppColors.primary : AppColors.faint),
                    title: a['label'] as String,
                    subtitle: [a['address'], a['landmark']].where((x) => (x ?? '').toString().isNotEmpty).join(' · '),
                    trailing: _addressId == a['id'] ? const Icon(CupertinoIcons.checkmark_alt, color: AppColors.primary, size: 20) : const SizedBox(width: 20),
                    onTap: () {
                      setState(() => _addressId = a['id'] as String);
                      _loadQuote();
                    },
                  ),
                Cell(leading: const Icon(CupertinoIcons.plus_circle_fill, color: AppColors.primary, size: 20), title: 'Ajouter une adresse', titleColor: AppColors.primary, trailing: const SizedBox.shrink(), onTap: _addAddress),
              ]),
              const SectionTitle('Destinataire'),
              Group(children: [
                _row('Nom', TextField(controller: _name, style: AppText.body, decoration: const InputDecoration(hintText: 'Nom et prénom', filled: false))),
                _row('Téléphone', TextField(controller: _phone, keyboardType: TextInputType.phone, style: AppText.body, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)], decoration: const InputDecoration(hintText: '07 01 02 03 04', prefixText: '+225 ', filled: false))),
                _row('Note', TextField(controller: _note, style: AppText.body, decoration: const InputDecoration(hintText: 'Pour le livreur (facultatif)', filled: false))),
              ]),
              if (_quoteError != null) ...[
                const SizedBox(height: 18),
                StatusBanner(icon: CupertinoIcons.info_circle_fill, color: AppColors.warning, title: 'Panier à vérifier', text: _quoteError),
              ] else if (q == null)
                const Loader(padding: 30)
              else ...[
                for (final s in shops) ...[
                  SectionTitle(s['shopName'] as String),
                  Group(children: [
                    Cell(title: 'Articles', value: formatMoney(s['goodsTotal'] as num)),
                    Cell(title: 'À payer à la commande', trailing: Text(formatMoney(s['dueNow'] as num), style: AppText.price)),
                    if ((s['dueOnDelivery'] as num) > 0) Cell(title: 'Reste à la livraison', value: formatMoney(s['dueOnDelivery'] as num)),
                    Cell(title: 'Livraison LETO', value: s['deliveryFeeEstimate'] == null ? 'Au livreur' : '≈ ${formatMoney(s['deliveryFeeEstimate'] as num)}'),
                    Cell(title: 'Paiement reçu par', value: (s['payment'] as Map)['payee'] as String),
                  ]),
                ],
                const SectionTitle('Total'),
                Group(children: [
                  Cell(title: 'Maintenant', subtitle: 'Mobile Money', trailing: Text(formatMoney(q['dueNow'] as num), style: AppText.price.copyWith(fontSize: 17))),
                  Cell(
                    title: 'À la livraison',
                    subtitle: fee == null ? 'Reste de la marchandise + frais du livreur' : 'Marchandise ${formatMoney(q['dueOnDelivery'] as num)} + livraison ≈ ${formatMoney(fee)}',
                    value: formatMoney((q['dueOnDelivery'] as num) + (fee ?? 0)),
                  ),
                ]),
                const SectionFooter('Après la commande, payez par Mobile Money et indiquez la référence reçue par SMS. Dès que le paiement est confirmé, un livreur LETO est envoyé à la boutique. Une livraison par boutique.'),
              ],
            ]),
          ),
        ]),
        Positioned(
          left: 14,
          right: 14,
          bottom: MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom - 6 : 12,
          child: Glass(
            radius: BorderRadius.circular(30),
            opacity: 0.8,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 7, 7, 7),
              child: Row(children: [
                Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('À payer maintenant', style: AppText.caption.copyWith(fontSize: 11)),
                  Text(q == null ? '…' : formatMoney(q['dueNow'] as num), style: AppText.price.copyWith(fontSize: 17)),
                ]),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy || q == null ? null : _confirm,
                    child: _busy ? const CupertinoActivityIndicator(color: Colors.white) : const Text('Confirmer'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Commande envoyée : une commande par boutique, chacune à payer
class CheckoutDoneScreen extends StatelessWidget {
  final List<Map> orders;
  const CheckoutDoneScreen({super.key, required this.orders});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 40, 16, 24), children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
            child: const Icon(CupertinoIcons.checkmark_alt, color: AppColors.primary, size: 36),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Commande enregistrée', textAlign: TextAlign.center, style: AppText.title1),
        const SizedBox(height: 6),
        Text(
          orders.length > 1 ? 'Une commande par boutique. Payez chacune par Mobile Money pour lancer sa livraison.' : 'Payez par Mobile Money pour lancer la livraison.',
          textAlign: TextAlign.center,
          style: AppText.bodyMuted,
        ),
        const SizedBox(height: 22),
        Group(dividerIndent: 60, children: [
          for (final o in orders)
            Cell(
              leading: const SettingsIcon(CupertinoIcons.bag_fill, color: AppColors.accent),
              title: '${o['number']} · ${o['shopName']}',
              subtitle: 'À payer : ${formatMoney(o['dueNow'] as num)}',
              onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => OrderScreen(id: o['id'] as String))),
            ),
        ]),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: () => orders.length == 1
              ? Navigator.pushReplacement(context, CupertinoPageRoute(builder: (_) => OrderScreen(id: orders.first['id'] as String)))
              : Navigator.pushReplacement(context, CupertinoPageRoute(builder: (_) => const OrdersScreen())),
          child: Text(orders.length == 1 ? 'Payer maintenant' : 'Voir mes commandes'),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Plus tard')),
      ]),
    ),
  );
}

// ============================================================================
// Mes commandes
// ============================================================================

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<dynamic>? _orders;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.instance.myOrders();
      if (mounted) setState(() { _orders = r; _failed = false; });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _orders ?? [];
    return Scaffold(
      body: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()), slivers: [
        const LargeTitleBar('Mes commandes'),
        CupertinoSliverRefreshControl(onRefresh: _load),
        if (_failed && _orders == null)
          SliverToBoxAdapter(child: EmptyState(icon: CupertinoIcons.wifi_slash, title: 'Pas de connexion', text: 'Vérifiez votre connexion Internet puis réessayez.', action: 'Réessayer', onAction: _load))
        else if (_orders == null)
          const SliverToBoxAdapter(child: Loader(padding: 40))
        else if (list.isEmpty)
          const SliverToBoxAdapter(child: EmptyState(icon: CupertinoIcons.bag, title: 'Aucune commande', text: 'Vos commandes et leur livraison apparaîtront ici.'))
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverToBoxAdapter(
              child: Group(dividerIndent: 76, children: [
                for (final o in list.cast<Map>())
                  Cell(
                    leading: ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 48, height: 48, child: NetImage(((o['items'] as List).firstOrNull as Map?)?['photo'] as String?, width: 48))),
                    title: '${o['shopName']}',
                    subtitle: '${o['number']} · ${_date(o['createdAt'] as String?)}\n${orderStatusLabel(o)}',
                    value: formatMoney(o['goodsTotal'] as num),
                    onTap: () async {
                      await Navigator.push(context, CupertinoPageRoute(builder: (_) => OrderScreen(id: o['id'] as String)));
                      _load();
                    },
                  ),
              ]),
            ),
          ),
      ]),
    );
  }
}

// ============================================================================
// Une commande : paiement, suivi de la livraison
// ============================================================================

class OrderScreen extends StatefulWidget {
  final String id;
  const OrderScreen({super.key, required this.id});
  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  Map<String, dynamic>? _o;
  bool _failed = false;
  bool _busy = false;
  Timer? _timer;
  final _ref = TextEditingController();
  final _payer = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    // Suivi en direct (paiement en vérification, livreur en route)
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (['PAYMENT_DECLARED', 'PAID', 'IN_DELIVERY'].contains(_o?['status'])) _load();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ref.dispose();
    _payer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final o = await Api.instance.order(widget.id);
      if (mounted) setState(() { _o = o; _failed = false; });
    } catch (_) {
      if (mounted && _o == null) setState(() => _failed = true);
    }
  }

  Future<void> _declare() async {
    if (_ref.text.trim().length < 4) return showError(context, 'Indiquez la référence reçue par SMS');
    final payer = _payer.text.replaceAll(RegExp(r'\D'), '');
    setState(() => _busy = true);
    try {
      final o = await Api.instance.declarePayment(widget.id, _ref.text.trim(), payerPhone: payer.length == 10 ? payer : null);
      if (mounted) {
        setState(() => _o = o);
        showInfo(context, 'Paiement envoyé pour vérification');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (c) => CupertinoActionSheet(
        message: const Text('La commande sera annulée et les articles remis en stock.'),
        actions: [CupertinoActionSheetAction(isDestructiveAction: true, onPressed: () => Navigator.pop(c, true), child: const Text('Annuler la commande'))],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(c, false), child: const Text('Garder')),
      ),
    );
    if (ok != true) return;
    try {
      final o = await Api.instance.cancelOrder(widget.id);
      if (mounted) setState(() => _o = o);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// Étapes : commandée → payée → livreur → livrée
  Widget _steps(String status) {
    const steps = ['Commandée', 'Payée', 'En route', 'Livrée'];
    final at = switch (status) { 'AWAITING_PAYMENT' || 'PAYMENT_DECLARED' => 0, 'PAID' => 1, 'IN_DELIVERY' => 2, 'DELIVERED' => 3, _ => -1 };
    return Row(children: [
      for (var i = 0; i < steps.length; i++) ...[
        Expanded(
          child: Column(children: [
            Container(height: 4, decoration: BoxDecoration(color: i <= at ? AppColors.primary : AppColors.fill, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 6),
            Text(steps[i], style: AppText.caption.copyWith(fontSize: 11, color: i <= at ? AppColors.ink : AppColors.muted, fontWeight: i == at ? FontWeight.w600 : FontWeight.w400)),
          ]),
        ),
        if (i < steps.length - 1) const SizedBox(width: 6),
      ],
    ]);
  }

  List<Widget> _paymentBlock(Map o) {
    final pay = (o['payment'] as Map?) ?? {};
    final alias = pay['alias'] as String?;
    return [
      if (pay['rejectedNote'] != null) ...[
        const SizedBox(height: 16),
        StatusBanner(icon: CupertinoIcons.exclamationmark_bubble_fill, color: AppColors.warning, title: 'Paiement non reçu', text: '${pay['rejectedNote']}. Vérifiez puis renvoyez la référence.'),
      ],
      const SectionTitle('Payer par Mobile Money'),
      Group(children: [
        Cell(title: 'Montant', trailing: Text(formatMoney(o['dueNow'] as num), style: AppText.price.copyWith(fontSize: 17))),
        Cell(title: 'Bénéficiaire', value: pay['payee'] as String? ?? ''),
        if (alias != null)
          Cell(
            title: 'Alias PI-SPI',
            value: alias,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: alias));
                showInfo(context, 'Alias copié');
              },
              child: const Icon(CupertinoIcons.doc_on_doc, size: 18, color: AppColors.primary),
            ),
          ),
      ]),
      const SectionFooter('Envoyez le montant depuis votre application Mobile Money (PI-SPI), puis indiquez ci-dessous la référence reçue par SMS.'),
      const SectionTitle('Votre paiement'),
      Group(children: [
        Padding(padding: const EdgeInsets.only(left: 14), child: TextField(controller: _ref, style: AppText.body, decoration: const InputDecoration(hintText: 'Référence de la transaction', filled: false))),
        Padding(
          padding: const EdgeInsets.only(left: 14),
          child: TextField(controller: _payer, keyboardType: TextInputType.phone, style: AppText.body, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)], decoration: const InputDecoration(hintText: 'Numéro qui a payé (facultatif)', filled: false)),
        ),
      ]),
      const SizedBox(height: 16),
      FilledButton(onPressed: _busy ? null : _declare, child: _busy ? const CupertinoActivityIndicator(color: Colors.white) : const Text('J’ai payé')),
      if (o['status'] == 'AWAITING_PAYMENT') ...[
        const SizedBox(height: 6),
        TextButton(onPressed: _cancel, child: const Text('Annuler la commande', style: TextStyle(color: AppColors.danger))),
      ],
    ];
  }

  List<Widget> _deliveryBlock(Map o) {
    final d = (o['delivery'] as Map?) ?? {};
    final driver = d['driver'] as Map?;
    final fee = d['price'] as num?;
    return [
      const SectionTitle('Livraison LETO'),
      Group(dividerIndent: 56, children: [
        Cell(leading: const SettingsIcon(PhosphorIconsFill.moped), title: (o['deliveryLabel'] as String?) ?? 'En livraison', subtitle: driver == null ? 'Un livreur va accepter la course' : null),
        if (driver != null)
          Cell(
            leading: const SettingsIcon(CupertinoIcons.person_fill, color: Color(0xFF2F6F7E)),
            title: driver['name'] as String,
            subtitle: [driver['vehicleType'] == 'MOTO' ? 'Moto' : driver['vehicleType'], driver['plate']].whereType<String>().join(' · '),
            trailing: driver['phone'] == null
                ? null
                : CupertinoButton(padding: EdgeInsets.zero, minimumSize: const Size(36, 36), onPressed: () => launchUrl(Uri.parse('tel:${driver['phone']}')), child: const Icon(CupertinoIcons.phone_fill, color: AppColors.primary, size: 20)),
          ),
        if (d['trackingUrl'] != null)
          Cell(leading: const SettingsIcon(CupertinoIcons.map_fill, color: AppColors.accent), title: 'Suivre sur la carte', onTap: () => launchUrl(Uri.parse(d['trackingUrl'] as String), mode: LaunchMode.externalApplication)),
      ]),
      if (d['confirmationCode'] != null) ...[
        const SectionTitle('Code de remise'),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text('${d['confirmationCode']}', style: AppText.display.copyWith(letterSpacing: 10, fontFeatures: const [FontFeature.tabularFigures()])),
            const SizedBox(height: 4),
            Text('À donner au livreur à la remise du colis', style: AppText.caption),
          ]),
        ),
      ],
      const SectionTitle('À payer au livreur'),
      Group(children: [
        if ((o['dueOnDelivery'] as num) > 0) Cell(title: 'Reste de la marchandise', value: formatMoney(o['dueOnDelivery'] as num)),
        Cell(title: 'Livraison', value: fee == null ? 'Selon la course' : formatMoney(fee)),
        if (fee != null) Cell(title: 'Total en espèces', trailing: Text(formatMoney((o['dueOnDelivery'] as num) + fee), style: AppText.price)),
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final o = _o;
    if (o == null) {
      return Scaffold(
        body: CustomScrollView(slivers: [
          const LargeTitleBar('Commande'),
          SliverFillRemaining(child: Center(child: _failed ? EmptyState(icon: CupertinoIcons.wifi_slash, title: 'Commande indisponible', text: 'Vérifiez votre connexion Internet puis réessayez.', action: 'Réessayer', onAction: _load) : const Loader())),
        ]),
      );
    }
    final status = o['status'] as String;
    final pay = (o['payment'] as Map?) ?? {};
    final addr = (o['address'] as Map?) ?? {};
    final items = ((o['items'] as List?) ?? []).cast<Map>();
    return Scaffold(
      body: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()), slivers: [
        LargeTitleBar(o['number'] as String),
        CupertinoSliverRefreshControl(onRefresh: _load),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          sliver: SliverList.list(children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(CupertinoIcons.circle_fill, size: 9, color: orderStatusColor(status)),
                  const SizedBox(width: 7),
                  Expanded(child: Text(orderStatusLabel(o), style: AppText.title)),
                ]),
                const SizedBox(height: 2),
                Text('${o['shopName']} · ${_date(o['createdAt'] as String?)}', style: AppText.caption),
                if (!['CANCELLED', 'FAILED'].contains(status)) ...[const SizedBox(height: 14), _steps(status)],
              ]),
            ),
            if (status == 'AWAITING_PAYMENT') ..._paymentBlock(o),
            if (status == 'PAYMENT_DECLARED') ...[
              const SizedBox(height: 16),
              StatusBanner(icon: CupertinoIcons.clock_fill, color: AppColors.primary, title: 'Paiement en vérification', text: '${pay['payee']} vérifie la réception (réf. ${pay['reference']}). La livraison partira dès la confirmation.'),
            ],
            if (status == 'PAID') ...[
              const SizedBox(height: 16),
              StatusBanner(
                icon: CupertinoIcons.checkmark_seal_fill,
                color: AppColors.success,
                title: 'Paiement confirmé',
                text: (o['delivery'] as Map?)?['error'] != null ? 'La demande de livreur va être relancée.' : 'Un livreur LETO est demandé pour récupérer votre colis.',
              ),
            ],
            if (status == 'IN_DELIVERY' || status == 'DELIVERED') ..._deliveryBlock(o),
            if (status == 'DELIVERED') ...[
              const SizedBox(height: 16),
              const StatusBanner(icon: CupertinoIcons.checkmark_seal_fill, color: AppColors.success, title: 'Commande livrée', text: 'Merci pour votre achat sur Adjamé-Smart.'),
            ],
            if (status == 'CANCELLED') ...[
              const SizedBox(height: 16),
              StatusBanner(icon: CupertinoIcons.xmark_circle_fill, color: AppColors.muted, title: 'Commande annulée', text: o['cancelReason'] as String?),
            ],
            if (status == 'FAILED') ...[
              const SizedBox(height: 16),
              const StatusBanner(icon: CupertinoIcons.info_circle_fill, color: AppColors.warning, title: 'Livraison impossible', text: 'Le livreur n’a pas pu vous remettre le colis. La boutique va vous contacter.'),
            ],
            SectionTitle('Articles (${items.fold<int>(0, (t, i) => t + (i['qty'] as int))})'),
            Group(dividerIndent: 70, children: [
              for (final i in items)
                Cell(
                  leading: ClipRRect(borderRadius: BorderRadius.circular(9), child: SizedBox(width: 44, height: 44, child: NetImage(i['photo'] as String?, width: 44))),
                  title: i['name'] as String,
                  subtitle: [if (i['variantLabel'] != null) i['variantLabel'], '${i['qty']} × ${formatMoney(i['price'] as num)}'].join(' · '),
                  value: formatMoney(i['subtotal'] as num),
                ),
            ]),
            const SectionTitle('Montants'),
            Group(children: [
              Cell(title: 'Marchandise', value: formatMoney(o['goodsTotal'] as num)),
              Cell(title: 'Payé à la commande', value: formatMoney(o['dueNow'] as num)),
              if ((o['dueOnDelivery'] as num) > 0) Cell(title: 'À la livraison', value: formatMoney(o['dueOnDelivery'] as num)),
            ]),
            const SectionTitle('Livré à'),
            Group(children: [
              Cell(title: '${o['recipientName']}', subtitle: [formatPhone('+225${(o['recipientPhone'] as String).replaceFirst('+225', '')}'), addr['address'], addr['landmark']].where((x) => (x ?? '').toString().isNotEmpty).join(' · ')),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ============================================================================
// Boutique : commandes reçues
// ============================================================================

class ShopOrdersScreen extends StatefulWidget {
  final Map shop;
  const ShopOrdersScreen({super.key, required this.shop});
  @override
  State<ShopOrdersScreen> createState() => _ShopOrdersScreenState();
}

class _ShopOrdersScreenState extends State<ShopOrdersScreen> {
  List<dynamic>? _orders;
  String _tab = 'todo';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await Api.instance.shopOrders(widget.shop['id'] as String);
      if (mounted) setState(() => _orders = r);
    } catch (e) {
      if (mounted && _orders == null) setState(() => _orders = []);
    }
  }

  Future<void> _act(Map o, String action, {String? askTitle}) async {
    String? note;
    if (askTitle != null) {
      note = await askNote(context, askTitle);
      if (note == null) return;
    }
    try {
      await Api.instance.shopOrderAction(o['id'] as String, action, note);
      HapticFeedback.mediumImpact();
      if (mounted) showInfo(context, action == 'confirm-payment' ? 'Paiement confirmé : livreur LETO demandé' : 'Commande mise à jour');
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  bool _inTab(Map o) => switch (_tab) {
    'todo' => ['AWAITING_PAYMENT', 'PAYMENT_DECLARED', 'PAID'].contains(o['status']),
    'delivery' => o['status'] == 'IN_DELIVERY',
    _ => ['DELIVERED', 'CANCELLED', 'FAILED'].contains(o['status']),
  };

  Widget _card(Map o) {
    final pay = (o['payment'] as Map?) ?? {};
    final d = (o['delivery'] as Map?) ?? {};
    final status = o['status'] as String;
    final items = ((o['items'] as List?) ?? []).cast<Map>();
    final addr = (o['address'] as Map?) ?? {};
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${o['number']}', style: AppText.title)),
          Pill(orderStatusLabel(o), background: orderStatusColor(status).withValues(alpha: 0.12), foreground: orderStatusColor(status)),
        ]),
        Text('${_date(o['createdAt'] as String?)} · ${o['recipientName']}', style: AppText.caption),
        const SizedBox(height: 10),
        for (final i in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('${i['qty']} × ${i['name']}${i['variantLabel'] != null ? ' (${i['variantLabel']})' : ''}', style: AppText.subhead),
          ),
        const SizedBox(height: 6),
        Text('Acompte ${formatMoney(o['dueNow'] as num)}${(o['dueOnDelivery'] as num) > 0 ? ' · ${formatMoney(o['dueOnDelivery'] as num)} encaissés par le livreur' : ' · payé en entier'}', style: AppText.caption.copyWith(color: AppColors.ink)),
        Text([addr['address'], addr['landmark']].where((x) => (x ?? '').toString().isNotEmpty).join(' · '), style: AppText.caption),
        if (status == 'PAYMENT_DECLARED') ...[
          const SizedBox(height: 10),
          Text('Paiement déclaré : réf. ${pay['reference']}${pay['payerPhone'] != null ? ' · ${formatPhone(pay['payerPhone'] as String)}' : ''}', style: AppText.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
          if (pay['mode'] == 'DIRECT') ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => _act(o, 'reject-payment', askTitle: 'Paiement non reçu ?'), child: const Text('Pas reçu'))),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: FilledButton(onPressed: () => _act(o, 'confirm-payment'), child: const Text('Paiement reçu'))),
            ]),
          ] else
            Text('Vérifié par Adjamé-Smart, la livraison partira ensuite.', style: AppText.caption),
        ],
        if (status == 'AWAITING_PAYMENT') ...[const SizedBox(height: 8), Text('En attente du paiement du client.', style: AppText.caption)],
        if (status == 'PAID') ...[
          const SizedBox(height: 8),
          Text(d['error'] != null ? 'Livreur non demandé : ${d['error']}' : 'Livreur LETO demandé : préparez le colis.', style: AppText.caption.copyWith(color: AppColors.ink)),
          if (d['error'] != null) ...[const SizedBox(height: 8), FilledButton(onPressed: () => _act(o, 'retry-delivery'), child: const Text('Relancer la livraison'))],
        ],
        if (status == 'IN_DELIVERY') ...[
          const SizedBox(height: 8),
          Text([(o['deliveryLabel'] as String?) ?? 'En livraison', if (d['driver'] != null) 'Livreur : ${(d['driver'] as Map)['name']}'].join(' · '), style: AppText.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
        ],
        if (['AWAITING_PAYMENT', 'PAYMENT_DECLARED', 'PAID'].contains(status))
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => _act(o, 'cancel', askTitle: 'Annuler la commande ?'), child: const Text('Annuler', style: TextStyle(color: AppColors.muted))),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = (_orders ?? []).cast<Map>();
    final list = all.where(_inTab).toList();
    final todo = all.where((o) => o['status'] == 'PAYMENT_DECLARED' && (o['payment'] as Map?)?['mode'] == 'DIRECT').length;
    return Scaffold(
      body: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()), slivers: [
        const LargeTitleBar('Commandes'),
        CupertinoSliverRefreshControl(onRefresh: _load),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<String>(
                groupValue: _tab,
                children: {'todo': Text(todo > 0 ? 'À traiter ($todo)' : 'À traiter'), 'delivery': const Text('En livraison'), 'done': const Text('Terminées')},
                onValueChanged: (v) => setState(() => _tab = v ?? 'todo'),
              ),
            ),
          ),
        ),
        if (_orders == null)
          const SliverToBoxAdapter(child: Loader(padding: 40))
        else if (list.isEmpty)
          SliverToBoxAdapter(child: EmptyState(icon: CupertinoIcons.tray, title: 'Rien ici', text: _tab == 'todo' ? 'Les nouvelles commandes de ${widget.shop['name']} apparaîtront ici.' : null))
        else
          SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), sliver: SliverList.builder(itemCount: list.length, itemBuilder: (_, i) => _card(list[i]))),
      ]),
    );
  }
}
