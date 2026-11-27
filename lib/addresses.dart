import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'api.dart';
import 'theme.dart';
import 'widgets.dart';

/// Nouvelle adresse de livraison : nom, quartier, repère + position actuelle du téléphone.
/// Renvoie l'id de l'adresse créée (ou null si annulé / impossible).
Future<String?> addAddressSheet(BuildContext context) async {
  final label = TextEditingController(text: 'Maison');
  final address = TextEditingController();
  final landmark = TextEditingController();
  Widget field(TextEditingController c, String hint) => TextField(controller: c, style: AppText.body, decoration: InputDecoration(hintText: hint, filled: false));
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (c) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Row(children: [
              BarButton('Annuler', onTap: () => Navigator.pop(c, false)),
              const Expanded(child: Text('Nouvelle adresse', textAlign: TextAlign.center, style: AppText.title)),
              BarButton('Ajouter', bold: true, onTap: () => Navigator.pop(c, true)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Group(children: [field(label, 'Nom (Maison, Bureau…)'), field(address, 'Commune, quartier'), field(landmark, 'Repère (facultatif)')]),
              const SectionFooter('Votre position actuelle est enregistrée avec l’adresse, pour guider le livreur. Ajoutez-la depuis le lieu de livraison.'),
            ]),
          ),
        ]),
      ),
    ),
  );
  if (ok != true || !context.mounted) return null;
  try {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    final p = await Geolocator.getCurrentPosition();
    final before = ((Api.instance.user?['addresses'] as List?) ?? []).map((a) => a['id']).toSet();
    await Api.instance.addAddress({'label': label.text.trim(), 'address': address.text.trim(), 'landmark': landmark.text.trim(), 'lat': p.latitude, 'lng': p.longitude});
    final after = ((Api.instance.user?['addresses'] as List?) ?? []).cast<Map>();
    return after.where((a) => !before.contains(a['id'])).firstOrNull?['id'] as String?;
  } catch (e) {
    if (context.mounted) showError(context, e is ApiException ? e : 'Position indisponible : activez la localisation');
    return null;
  }
}
