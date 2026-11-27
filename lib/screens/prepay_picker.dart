import 'package:flutter/cupertino.dart';

import '../theme.dart';
import '../widgets.dart';

/// Choix du paiement avant livraison : totalité ou acompte (10 à 90 %), le reste à la livraison.
/// Pour un produit, [allowInherit] propose « Comme la boutique » (valeur null).
class PrepayPicker extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;
  final bool allowInherit;
  final int? shopDefault;
  const PrepayPicker({super.key, required this.value, required this.onChanged, this.allowInherit = false, this.shopDefault});

  String get _mode => value == null ? 'SHOP' : value! >= 100 ? 'FULL' : 'PART';

  String _explain(int pct) => pct >= 100
      ? 'Le client paie tout par Mobile Money à la commande. Le colis lui est remis une fois le paiement confirmé.'
      : 'Le client paie $pct % à la commande (Mobile Money) et ${100 - pct} % au livreur à la livraison.';

  @override
  Widget build(BuildContext context) {
    final effective = value ?? shopDefault ?? 100;
    return Group(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: double.infinity,
          child: CupertinoSlidingSegmentedControl<String>(
            groupValue: _mode,
            children: {
              if (allowInherit) 'SHOP': const Text('Comme la boutique'),
              'FULL': const Text('Totalité'),
              'PART': const Text('Acompte'),
            },
            onValueChanged: (m) => onChanged(switch (m) {
              'SHOP' => null,
              'FULL' => 100,
              _ => (value != null && value! < 100) ? value : 30,
            }),
          ),
        ),
      ),
      if (_mode == 'PART')
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(children: [
            Text('${value!} %', style: AppText.title.copyWith(color: AppColors.accent, fontFeatures: const [FontFeature.tabularFigures()])),
            Expanded(
              child: CupertinoSlider(
                value: value!.toDouble(),
                min: 10,
                max: 90,
                divisions: 8,
                activeColor: AppColors.accent,
                onChanged: (v) => onChanged(v.round()),
              ),
            ),
          ]),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Text(_mode == 'SHOP' ? 'Réglage de la boutique : ${_explain(effective).replaceFirst('Le client', 'le client')}' : _explain(effective), style: AppText.caption),
      ),
    ]);
  }
}
