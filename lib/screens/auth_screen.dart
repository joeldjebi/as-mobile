import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../api.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets.dart';

/// Connexion ou création de compte (téléphone + mot de passe)
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _register = false;
  bool _busy = false;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  Future<void> _submit() async {
    final phone = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (_register && _name.text.trim().isEmpty) return showError(context, 'Indiquez votre nom');
    if (phone.length != 10) return showError(context, 'Numéro à 10 chiffres (ex. 07 01 02 03 04)');
    if (_password.text.length < 6) return showError(context, 'Mot de passe : 6 caractères minimum');
    setState(() => _busy = true);
    try {
      if (_register) {
        await Api.instance.register(_name.text.trim(), phone, _password.text);
      } else {
        await Api.instance.login(phone, _password.text);
      }
      if (mounted) goHome(context);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(24, 48, 24, 24), children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
            child: const Icon(PhosphorIconsFill.shoppingBag, color: Colors.white, size: 38),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Adjamé-Smart', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Les boutiques d’Adjamé, livrées chez vous par LETO', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 32),
        SegmentedButton<bool>(
          segments: const [ButtonSegment(value: false, label: Text('Se connecter')), ButtonSegment(value: true, label: Text('Créer un compte'))],
          selected: {_register},
          onSelectionChanged: (s) => setState(() => _register = s.first),
        ),
        const SizedBox(height: 20),
        if (_register) ...[
          TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'Nom complet', prefixIcon: Icon(PhosphorIconsBold.user))),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: '07 01 02 03 04', prefixText: '+225  ', prefixIcon: Icon(PhosphorIconsBold.phone)),
        ),
        const SizedBox(height: 12),
        TextField(controller: _password, obscureText: true, decoration: const InputDecoration(hintText: 'Mot de passe', prefixIcon: Icon(PhosphorIconsBold.lock))),
        const SizedBox(height: 24),
        FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? '…' : _register ? 'Créer mon compte' : 'Se connecter')),
        const SizedBox(height: 16),
        const Text('Vendeur ? Créez un compte puis ouvrez votre boutique depuis « Compte ».', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 13)),
      ]),
    ),
  );
}
