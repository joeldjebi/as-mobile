import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets.dart';

/// Demande la connexion seulement quand elle est nécessaire (commande, boutique, signalement).
/// Renvoie true si l'utilisateur est connecté au retour.
Future<bool> requireAuth(BuildContext context, {String? reason}) async {
  if (Api.instance.loggedIn) return true;
  final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => AuthScreen(reason: reason)));
  return ok == true && Api.instance.loggedIn;
}

/// Connexion ou création de compte (téléphone + mot de passe), présentée en feuille plein écran
class AuthScreen extends StatefulWidget {
  final String? reason;
  const AuthScreen({super.key, this.reason});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _register = false;
  bool _busy = false;
  bool _hide = true;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

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
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _row(String label, Widget field) => Padding(
    padding: const EdgeInsets.only(left: 16),
    child: Row(children: [
      SizedBox(width: 104, child: Text(label, style: AppText.body)),
      Expanded(child: field),
    ]),
  );

  InputDecoration _deco(String hint, {Widget? suffix}) => InputDecoration(hintText: hint, filled: false, suffixIcon: suffix, contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 0));

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Row(children: [BarButton('Annuler', onTap: () => Navigator.of(context).pop(false)), const Spacer()]),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
            Center(child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(17)),
              child: const Icon(CupertinoIcons.bag_fill, color: Colors.white, size: 36),
            )),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(_register ? 'Créez votre compte' : 'Bon retour parmi nous', key: ValueKey(_register), textAlign: TextAlign.center, style: AppText.title1),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(widget.reason ?? 'Les boutiques d’Adjamé, livrées chez vous par VITE.', textAlign: TextAlign.center, style: AppText.bodyMuted),
            ),
            const SizedBox(height: 26),
            CupertinoSlidingSegmentedControl<bool>(
              groupValue: _register,
              children: const {
                false: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Connexion')),
                true: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Inscription')),
              },
              onValueChanged: (v) => setState(() => _register = v ?? false),
            ),
            const SizedBox(height: 22),
            Group(children: [
              if (_register) _row('Nom', TextField(controller: _name, textCapitalization: TextCapitalization.words, style: AppText.body, decoration: _deco('Nom et prénom'))),
              _row(
                'Téléphone',
                Row(children: [
                  Text('+225 ', style: AppText.body.copyWith(color: AppColors.muted)),
                  Expanded(
                    child: TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                      style: AppText.body,
                      decoration: _deco('07 01 02 03 04'),
                    ),
                  ),
                ]),
              ),
              _row(
                'Mot de passe',
                TextField(
                  controller: _password,
                  obscureText: _hide,
                  onSubmitted: (_) => _submit(),
                  style: AppText.body,
                  decoration: _deco(
                    _register ? '6 caractères minimum' : 'Requis',
                    suffix: CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(44, 44),
                      onPressed: () => setState(() => _hide = !_hide),
                      child: Icon(_hide ? CupertinoIcons.eye : CupertinoIcons.eye_slash, color: AppColors.muted, size: 20),
                    ),
                  ),
                ),
              ),
            ]),
            SectionFooter(_register ? 'Avec un compte, vous pouvez commander, suivre vos livraisons et ouvrir votre boutique.' : 'Pas encore de compte ? Choisissez « Inscription », c’est rapide.'),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy ? const CupertinoActivityIndicator(color: Colors.white) : Text(_register ? 'Créer mon compte' : 'Se connecter'),
            ),
          ]),
        ),
      ]),
    ),
  );
}
