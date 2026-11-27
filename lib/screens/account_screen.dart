import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../addresses.dart';
import '../api.dart';
import '../mode.dart';
import '../theme.dart';
import '../widgets.dart';
import 'auth_screen.dart';
import 'orders_screen.dart';
import 'reseller_screen.dart';
import 'shop_form_screen.dart';

const _shopStatus = {
  'DRAFT': 'Brouillon',
  'PENDING': 'En vérification',
  'APPROVED': 'En ligne',
  'REJECTED': 'À corriger',
  'SUSPENDED': 'Suspendue',
};
const _resellerStatus = {
  'NONE': 'Non demandé',
  'PENDING': 'En vérification',
  'APPROVED': 'Actif',
  'REJECTED': 'Refusé',
};

/// Compte façon Réglages : visiteur (connexion) ou client (profil, boutique, revendeur, adresses)
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final api = Api.instance;
  List<dynamic> _shops = [];
  bool _wasLogged = false;

  @override
  void initState() {
    super.initState();
    _wasLogged = api.loggedIn;
    api.addListener(_onSession);
    if (api.loggedIn) _load();
  }

  @override
  void dispose() {
    api.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    if (!mounted) return;
    if (api.loggedIn && !_wasLogged) _loadShops();
    if (!api.loggedIn) _shops = [];
    _wasLogged = api.loggedIn;
    setState(() {});
  }

  Future<void> _load() async {
    if (!api.loggedIn) return;
    try {
      await api.refreshMe();
      await _loadShops();
    } catch (_) {}
  }

  Future<void> _loadShops() async {
    try {
      final shops = await api.myShops();
      if (mounted) setState(() => _shops = shops);
    } catch (_) {}
  }

  Future<void> _openShop([Map<String, dynamic>? s]) async {
    if (!await requireAuth(
      context,
      reason: 'Connectez-vous pour ouvrir votre boutique',
    ))
      return;
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ShopFormScreen(shop: s)),
    );
    _load();
  }

  Future<void> _reseller() async {
    if (!await requireAuth(
      context,
      reason: 'Connectez-vous pour demander le statut revendeur',
    ))
      return;
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ResellerScreen()),
    );
    _load();
  }

  Future<void> _logout() async {
    final ok = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (c) => CupertinoActionSheet(
        message: const Text('Votre panier reste sur ce téléphone.'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Se déconnecter'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Annuler'),
        ),
      ),
    );
    if (ok == true) {
      await AppMode.instance.setSeller(false);
      await api.logout();
    }
  }

  Future<void> _addAddress() async {
    await addAddressSheet(context);
    if (mounted) setState(() {});
  }

  List<Widget> _sellSections() => [
    const SectionTitle('Vendre sur Adjamé-Smart'),
    Group(
      dividerIndent: 60,
      children: [
        if (_shops.isNotEmpty)
          Cell(
            leading: const SettingsIcon(CupertinoIcons.building_2_fill),
            title: 'Passer en mode boutique',
            subtitle: _shops.length > 1
                ? '${_shops.length} boutiques · commandes, produits, réglages'
                : '${_shops.first['name']} · ${_shopStatus[_shops.first['status']] ?? ''}',
            titleColor: AppColors.primary,
            onTap: () => AppMode.instance.setSeller(true),
          ),
        Cell(
          leading: const SettingsIcon(
            CupertinoIcons.plus,
            color: Color(0xFF2F6F7E),
          ),
          title: _shops.isEmpty
              ? 'Ouvrir ma boutique'
              : 'Ouvrir une autre boutique',
          onTap: () => _openShop(),
        ),
        Cell(
          leading: const SettingsIcon(
            CupertinoIcons.tag_fill,
            color: AppColors.accent,
          ),
          title: 'Statut revendeur',
          value: api.loggedIn
              ? _resellerStatus[api.user?['resellerStatus']]
              : null,
          onTap: _reseller,
        ),
      ],
    ),
    const SectionFooter(
      'Boutique en ligne gratuite, prix de gros pour les revendeurs.',
    ),
  ];

  List<Widget> _aboutSection() => [
    const SectionTitle('Adjamé-Smart'),
    Group(
      dividerIndent: 60,
      children: const [
        Cell(
          leading: SettingsIcon(PhosphorIconsFill.moped),
          title: 'Livraison par VITE',
          subtitle: 'Frais payés en espèces au livreur',
        ),
        Cell(
          leading: SettingsIcon(
            CupertinoIcons.creditcard,
            color: AppColors.accent,
          ),
          title: 'Paiement Mobile Money',
          subtitle: 'Colis remis une fois le paiement confirmé',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final u = api.user ?? {};
    final name = (u['name'] as String?) ?? '';
    final addresses = ((u['addresses'] as List?) ?? []).cast<Map>();
    final logged = api.loggedIn;
    return Scaffold(
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          const LargeTitleBar('Compte'),
          if (logged) CupertinoSliverRefreshControl(onRefresh: _load),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, tabBarHeight(context) + 20),
            sliver: SliverList.list(
              children: [
                // Profil (style identifiant Apple)
                Group(
                  children: [
                    logged
                        ? Cell(
                            leading: Container(
                              width: 58,
                              height: 58,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                name.isEmpty
                                    ? '?'
                                    : name.characters.first.toUpperCase(),
                                style: AppText.title1.copyWith(
                                  color: Colors.white,
                                  fontSize: 24,
                                ),
                              ),
                            ),
                            title: name,
                            subtitle: [
                              formatPhone(u['phone'] as String?),
                              if (u['resellerStatus'] == 'APPROVED')
                                'Revendeur',
                            ].join(' · '),
                          )
                        : Cell(
                            leading: const Icon(
                              CupertinoIcons.person_crop_circle_fill,
                              size: 58,
                              color: AppColors.faint,
                            ),
                            title: 'Se connecter ou créer un compte',
                            titleColor: AppColors.primary,
                            subtitle: 'Commandez et suivez vos livraisons',
                            onTap: () => requireAuth(context),
                          ),
                  ],
                ),
                if (logged) ...[
                  const SectionTitle('Achats'),
                  Group(
                    dividerIndent: 56,
                    children: [
                      Cell(
                        leading: const SettingsIcon(CupertinoIcons.bag_fill),
                        title: 'Mes commandes',
                        subtitle: 'Paiement et suivi de livraison',
                        onTap: () => Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (_) => const OrdersScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                ..._sellSections(),
                if (logged) ...[
                  const SectionTitle('Adresses de livraison'),
                  Group(
                    dividerIndent: 52,
                    children: [
                      for (final a in addresses)
                        Cell(
                          leading: const Icon(
                            CupertinoIcons.location_fill,
                            color: AppColors.primary,
                            size: 22,
                          ),
                          title: a['label'] as String,
                          subtitle: [a['address'], a['landmark']]
                              .where((x) => (x ?? '').toString().isNotEmpty)
                              .join(' · '),
                          trailing: CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(36, 36),
                            onPressed: () async {
                              try {
                                await api.removeAddress(a['id'] as String);
                                if (mounted) setState(() {});
                              } catch (e) {
                                if (context.mounted) showError(context, e);
                              }
                            },
                            child: const Icon(
                              CupertinoIcons.trash,
                              size: 19,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      Cell(
                        leading: const Icon(
                          CupertinoIcons.plus_circle_fill,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        title: 'Ajouter une adresse',
                        titleColor: AppColors.primary,
                        onTap: _addAddress,
                        trailing: const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ],
                ..._aboutSection(),
                if (logged) ...[
                  const SizedBox(height: 32),
                  Group(
                    children: [
                      Cell(
                        title: 'Se déconnecter',
                        titleColor: AppColors.danger,
                        center: true,
                        onTap: _logout,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
