import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'theme.dart';

// ============================================================================
// Messages
// ============================================================================

/// Message d'erreur : sobre (fond encre), jamais de détail technique
void showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
}

void showInfo(BuildContext context, String msg) {
  HapticFeedback.lightImpact();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.primary));
}

// ============================================================================
// Mise en forme
// ============================================================================

/// Numéro lisible : +225 07 01 02 03 04
String formatPhone(String? p) {
  if (p == null || p.isEmpty) return '';
  final m = RegExp(r'^\+225(\d{10})$').firstMatch(p);
  if (m == null) return p;
  final d = m.group(1)!;
  return '+225 ${d.substring(0, 2)} ${d.substring(2, 4)} ${d.substring(4, 6)} ${d.substring(6, 8)} ${d.substring(8)}';
}

/// Montant en francs CFA : 1 500 F
String formatMoney(num? v) {
  final n = (v ?? 0).round().toString();
  final b = StringBuffer();
  for (var i = 0; i < n.length; i++) {
    if (i > 0 && (n.length - i) % 3 == 0) b.write(' ');
    b.write(n[i]);
  }
  return '$b F';
}

// ============================================================================
// Composants
// ============================================================================

/// Réduit légèrement l'élément pendant l'appui (retour tactile discret)
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.97});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
    onTapUp: widget.onTap == null ? null : (_) => setState(() => _down = false),
    onTapCancel: () => setState(() => _down = false),
    onTap: widget.onTap == null
        ? null
        : () {
            HapticFeedback.selectionClick();
            widget.onTap!();
          },
    child: AnimatedScale(scale: _down ? widget.scale : 1, duration: const Duration(milliseconds: 120), curve: Curves.easeOut, child: widget.child),
  );
}

/// Image réseau avec fond neutre pendant le chargement et en cas d'erreur
class NetImage extends StatelessWidget {
  final String? path;
  final BoxFit fit;
  final IconData placeholder;
  const NetImage(this.path, {super.key, this.fit = BoxFit.cover, this.placeholder = Icons.image_outlined});
  @override
  Widget build(BuildContext context) {
    final empty = Container(color: AppColors.surfaceAlt, alignment: Alignment.center, child: Icon(placeholder, color: AppColors.faint, size: 28));
    if (path == null || path!.isEmpty) return empty;
    return Image.network(
      photoUrl(path!),
      fit: fit,
      frameBuilder: (_, child, frame, sync) => sync ? child : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 250), child: frame == null ? empty : child),
      errorBuilder: (_, _, _) => empty,
    );
  }
}

/// En-tête de section éditorial : titre + action (« Tout voir »)
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsets padding;
  const SectionHeader(this.title, {super.key, this.action, this.onAction, this.padding = const EdgeInsets.fromLTRB(20, 28, 20, 12)});
  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(child: Text(title, style: AppText.section)),
      if (action != null) GestureDetector(onTap: onAction, child: Text(action!, style: AppText.label.copyWith(color: AppColors.primary))),
    ]),
  );
}

/// Petit titre de groupe (capitales espacées)
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(4, 24, 4, 10), child: Text(text.toUpperCase(), style: AppText.overline));
}

/// Groupe blanc arrondi, séparateurs fins (réglages, informations)
class Group extends StatelessWidget {
  final List<Widget> children;
  const Group({super.key, required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.line)),
    clipBehavior: Clip.antiAlias,
    child: Material(
      color: Colors.transparent,
      child: Column(children: [
        for (var i = 0; i < children.length; i++) ...[children[i], if (i < children.length - 1) const Divider(indent: 16, endIndent: 16)],
      ]),
    ),
  );
}

/// Bandeau d'état (information, attente, refus, validé)
class StatusBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? text;
  const StatusBanner({super.key, required this.icon, required this.color, required this.title, this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Color.alphaBlend(color.withValues(alpha: 0.08), AppColors.surface), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.18))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 19),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppText.title.copyWith(fontSize: 15.5)),
          if (text != null) ...[const SizedBox(height: 3), Text(text!, style: AppText.bodyMuted.copyWith(fontSize: 14))],
        ]),
      ),
    ]),
  );
}

/// Pastille (Gros, Rupture, statut)
class Pill extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;
  const Pill(this.text, {super.key, this.background = AppColors.ink, this.foreground = Colors.white});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: TextStyle(fontFamily: 'Inter', color: foreground, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
  );
}

/// Barre d'action fixe en bas d'écran, fond flouté
class BottomActionBar extends StatelessWidget {
  final Widget child;
  const BottomActionBar({super.key, required this.child});
  @override
  Widget build(BuildContext context) => ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        decoration: BoxDecoration(color: AppColors.background.withValues(alpha: 0.86), border: const Border(top: BorderSide(color: AppColors.line))),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
        child: child,
      ),
    ),
  );
}

/// État vide élégant (illustration en cercle, titre, texte, action)
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? text;
  final String? action;
  final VoidCallback? onAction;
  const EmptyState({super.key, required this.icon, required this.title, this.text, this.action, this.onAction});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
    child: Column(children: [
      Container(width: 84, height: 84, decoration: const BoxDecoration(color: AppColors.surfaceAlt, shape: BoxShape.circle), child: Icon(icon, size: 34, color: AppColors.ink)),
      const SizedBox(height: 18),
      Text(title, textAlign: TextAlign.center, style: AppText.headline.copyWith(fontSize: 22)),
      if (text != null) ...[const SizedBox(height: 8), Text(text!, textAlign: TextAlign.center, style: AppText.bodyMuted)],
      if (action != null) ...[const SizedBox(height: 22), SizedBox(width: 240, child: FilledButton(onPressed: onAction, child: Text(action!)))],
    ]),
  );
}

/// Bouton rond (retour, favoris) posé sur une photo
class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const RoundIconButton(this.icon, {super.key, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.94), shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 3))]),
      child: Icon(icon, size: 20, color: color ?? AppColors.ink),
    ),
  );
}
