import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets.dart';

const _days = ['', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

/// Page publique d'une boutique (produits et commande : phases suivantes)
class ShopPage extends StatefulWidget {
  final String slug;
  const ShopPage({super.key, required this.slug});
  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  Map<String, dynamic>? _s;
  @override
  void initState() {
    super.initState();
    Api.instance.shop(widget.slug).then((s) => mounted ? setState(() => _s = s) : null).catchError((Object e) {
      if (mounted) showError(context, e);
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final hours = s?['hours'] as Map?;
    return Scaffold(
      appBar: AppBar(title: Text(s?['name'] ?? '')),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              if (s['storefrontUrl'] != null)
                ClipRRect(borderRadius: BorderRadius.circular(16), child: AspectRatio(aspectRatio: 16 / 9, child: Image.network(photoUrl(s['storefrontUrl']), fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: Colors.white)))),
              const SizedBox(height: 14),
              Text(s['name'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              Text([s['type'] == 'GROSSISTE' ? 'Grossiste' : 'Boutique', s['market']].whereType<String>().join(' · '), style: const TextStyle(color: AppColors.muted)),
              if ((s['description'] ?? '').toString().isNotEmpty) ...[const SizedBox(height: 10), Text(s['description'])],
              const SectionTitle('Informations'),
              Group(children: [
                ListTile(leading: const Icon(PhosphorIconsBold.mapPin), title: Text(s['location'] ?? '—'), subtitle: Text(s['market'] ?? '')),
                if (hours != null)
                  ListTile(leading: const Icon(PhosphorIconsBold.clock), title: Text('${hours['open']} – ${hours['close']}'), subtitle: Text((hours['days'] as List).map((d) => _days[d as int]).join(', '))),
                if (s['phone'] != null)
                  ListTile(
                    leading: const Icon(PhosphorIconsBold.phone),
                    title: Text(formatPhone(s['phone'])),
                    trailing: const Icon(PhosphorIconsFill.phoneCall, color: AppColors.primary),
                    onTap: () => launchUrl(Uri.parse('tel:${s['phone']}')),
                  ),
              ]),
              const SizedBox(height: 16),
              const StatusBanner(icon: PhosphorIconsFill.package, color: AppColors.primary, title: 'Produits bientôt disponibles', text: 'Vous pourrez commander dans cette boutique et être livré par LETO.'),
            ]),
    );
  }
}
