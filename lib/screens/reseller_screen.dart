import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets.dart';
import 'photo_field.dart';

/// Demande du statut revendeur : prix de gros des grossistes une fois validé
class ResellerScreen extends StatefulWidget {
  const ResellerScreen({super.key});
  @override
  State<ResellerScreen> createState() => _ResellerScreenState();
}

class _ResellerScreenState extends State<ResellerScreen> {
  final _business = TextEditingController();
  final _commune = TextEditingController();
  String? _idPhoto;
  String? _shopPhoto;
  bool _busy = false;

  Future<void> _send() async {
    if (_business.text.trim().isEmpty) return showError(context, 'Indiquez le nom de votre commerce');
    if (_idPhoto == null || _shopPhoto == null) return showError(context, 'Ajoutez la photo de votre pièce et celle de votre commerce');
    setState(() => _busy = true);
    try {
      await Api.instance.requestReseller({'businessName': _business.text.trim(), 'commune': _commune.text.trim(), 'idPhotoUrl': _idPhoto, 'shopPhotoUrl': _shopPhoto});
      if (!mounted) return;
      showInfo(context, 'Demande envoyée : Adjamé-Smart la vérifie au plus vite');
      setState(() {});
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = Api.instance.user!;
    final status = u['resellerStatus'] as String? ?? 'NONE';
    final note = (u['reseller'] as Map?)?['note'] as String?;
    return Scaffold(
      appBar: AppBar(title: const Text('Statut revendeur')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (status == 'APPROVED')
          const StatusBanner(icon: PhosphorIconsFill.sealCheck, color: AppColors.success, title: 'Vous êtes revendeur', text: 'Les prix de gros des grossistes vous sont affichés.')
        else if (status == 'PENDING')
          const StatusBanner(icon: PhosphorIconsBold.hourglassMedium, color: AppColors.warning, title: 'Demande en cours de vérification', text: 'Vous serez prévenu dès qu’elle est traitée.')
        else ...[
          if (status == 'REJECTED') ...[StatusBanner(icon: PhosphorIconsFill.info, color: AppColors.warning, title: 'Demande refusée', text: note ?? 'Corrigez votre demande et renvoyez-la.'), const SizedBox(height: 12)],
          const Text('Vous achetez pour revendre ? Une fois validé, vous voyez les prix de gros et les quantités minimales des grossistes d’Adjamé.', style: TextStyle(color: AppColors.muted)),
          const SectionTitle('Votre commerce'),
          TextField(controller: _business, decoration: const InputDecoration(hintText: 'Nom du commerce')),
          const SizedBox(height: 10),
          TextField(controller: _commune, decoration: const InputDecoration(hintText: 'Commune (ex. Yopougon)')),
          const SectionTitle('Photos'),
          Row(children: [
            Expanded(child: PhotoField(label: 'Pièce d’identité', url: _idPhoto, identity: true, onUploaded: (u) => setState(() => _idPhoto = u))),
            const SizedBox(width: 12),
            Expanded(child: PhotoField(label: 'Votre commerce', url: _shopPhoto, onUploaded: (u) => setState(() => _shopPhoto = u))),
          ]),
          const SizedBox(height: 24),
          FilledButton(onPressed: _busy ? null : _send, child: Text(_busy ? '…' : 'Envoyer la demande')),
        ],
      ]),
    );
  }
}
