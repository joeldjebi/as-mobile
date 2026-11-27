import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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

/// Connexion ou création de compte (téléphone + mot de passe)
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

  Widget _phoneField() => Container(
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
    child: Row(children: [
      const Padding(padding: EdgeInsets.only(left: 16), child: Text('🇨🇮  +225', style: AppText.label)),
      Container(width: 1, height: 26, margin: const EdgeInsets.symmetric(horizontal: 12), color: AppColors.line),
      Expanded(
        child: TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          style: AppText.body.copyWith(letterSpacing: 0.6),
          decoration: const InputDecoration(hintText: '07 01 02 03 04', border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false),
        ),
      ),
    ]),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(icon: const Icon(PhosphorIconsRegular.x), onPressed: () => Navigator.of(context).pop(false)),
    ),
    body: SafeArea(
      top: false,
      child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 32), children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.centerLeft,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(18)),
            child: const Icon(PhosphorIconsFill.shoppingBagOpen, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 24),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(_register ? 'Créez votre compte' : 'Bon retour parmi nous', key: ValueKey(_register), style: AppText.display),
        ),
        const SizedBox(height: 8),
        Text(widget.reason ?? 'Les boutiques d’Adjamé, livrées chez vous par LETO.', style: AppText.bodyMuted),
        const SizedBox(height: 28),
        SegmentedButton<bool>(
          segments: const [ButtonSegment(value: false, label: Text('Connexion')), ButtonSegment(value: true, label: Text('Inscription'))],
          selected: {_register},
          onSelectionChanged: (s) => setState(() => _register = s.first),
        ),
        const SizedBox(height: 20),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _register
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'Nom et prénom')),
                )
              : const SizedBox(width: double.infinity),
        ),
        _phoneField(),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: _hide,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: 'Mot de passe',
            suffixIcon: IconButton(icon: Icon(_hide ? PhosphorIconsRegular.eye : PhosphorIconsRegular.eyeSlash, color: AppColors.muted), onPressed: () => setState(() => _hide = !_hide)),
          ),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)) : Text(_register ? 'Créer mon compte' : 'Se connecter'),
        ),
        const SizedBox(height: 20),
        Text(
          _register ? 'En créant un compte, vous pourrez commander, suivre vos livraisons et ouvrir votre boutique.' : 'Pas encore de compte ? Choisissez « Inscription », c’est rapide.',
          textAlign: TextAlign.center,
          style: AppText.caption,
        ),
      ]),
    ),
  );
}
