import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'theme.dart';

// ============================================================================
// Messages : bandeau sombre discret, jamais de rouge ni de détail technique
// ============================================================================

void _toast(BuildContext context, String msg, IconData icon) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(msg)),
      ]),
    ));
}

void showError(BuildContext context, Object e) {
  HapticFeedback.lightImpact();
  _toast(context, e.toString().replaceFirst('Exception: ', ''), CupertinoIcons.info_circle_fill);
}

void showInfo(BuildContext context, String msg) {
  HapticFeedback.lightImpact();
  _toast(context, msg, CupertinoIcons.checkmark_alt);
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

/// Montant en francs CFA : 12 500 F
String formatMoney(num? v) {
  final n = (v ?? 0).round().toString();
  final b = StringBuffer();
  for (var i = 0; i < n.length; i++) {
    if (i > 0 && (n.length - i) % 3 == 0) b.write(' ');
    b.write(n[i]);
  }
  return '$b F';
}

// ============================================================================
// Composants
// ============================================================================

/// Indicateur de chargement iOS
class Loader extends StatelessWidget {
  final double padding;
  const Loader({super.key, this.padding = 24});
  @override
  Widget build(BuildContext context) => Padding(padding: EdgeInsets.all(padding), child: const Center(child: CupertinoActivityIndicator(radius: 11)));
}

/// Grand titre iOS qui se réduit au défilement (fond flouté une fois la page défilée)
class LargeTitleBar extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget? leading;
  final Color? background;
  const LargeTitleBar(this.title, {super.key, this.trailing, this.leading, this.background});
  @override
  Widget build(BuildContext context) => CupertinoSliverNavigationBar(
    largeTitle: Text(title),
    trailing: trailing,
    leading: leading,
    previousPageTitle: 'Retour',
    transitionBetweenRoutes: false,
    backgroundColor: (background ?? AppColors.background).withValues(alpha: 0.86),
    border: const Border(bottom: BorderSide(color: AppColors.separator, width: 0)),
  );
}

/// Bouton texte de barre de navigation (Filtres, Vider, Annuler…)
class BarButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool bold;
  const BarButton(this.text, {super.key, this.onTap, this.bold = false});
  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    minimumSize: const Size(44, 44),
    onPressed: onTap,
    child: Text(text, style: AppText.body.copyWith(color: onTap == null ? AppColors.faint : AppColors.primary, fontWeight: bold ? FontWeight.w600 : FontWeight.w400)),
  );
}

/// Réduit légèrement l'élément pendant l'appui
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
    child: AnimatedScale(scale: _down ? widget.scale : 1, duration: const Duration(milliseconds: 140), curve: Curves.easeOut, child: widget.child),
  );
}

/// Image réseau avec fond neutre pendant le chargement et en cas d'erreur
class NetImage extends StatelessWidget {
  final String? path;
  final BoxFit fit;
  final IconData placeholder;
  const NetImage(this.path, {super.key, this.fit = BoxFit.cover, this.placeholder = CupertinoIcons.photo});
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

/// En-tête de section : titre gras + « Tout voir »
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsets padding;
  const SectionHeader(this.title, {super.key, this.action, this.onAction, this.padding = const EdgeInsets.fromLTRB(20, 30, 12, 10)});
  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(children: [
      Expanded(child: Text(title, style: AppText.headline)),
      if (action != null)
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(44, 32),
          onPressed: onAction,
          child: Text(action!, style: AppText.body.copyWith(color: AppColors.primary)),
        ),
    ]),
  );
}

/// Titre de groupe façon Réglages (petites capitales grises)
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(16, 26, 16, 7), child: Text(text.toUpperCase(), style: AppText.caption));
}

/// Note sous un groupe
class SectionFooter extends StatelessWidget {
  final String text;
  const SectionFooter(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(16, 7, 16, 0), child: Text(text, style: AppText.caption));
}

/// Groupe arrondi (liste « inset grouped » d'iOS), séparateurs fins
class Group extends StatelessWidget {
  final List<Widget> children;
  final double dividerIndent;
  final Color color;
  const Group({super.key, required this.children, this.dividerIndent = 16, this.color = AppColors.surface});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
    clipBehavior: Clip.antiAlias,
    child: Material(
      color: Colors.transparent,
      child: Column(children: [
        for (var i = 0; i < children.length; i++) ...[children[i], if (i < children.length - 1) Divider(indent: dividerIndent)],
      ]),
    ),
  );
}

/// Pastille d'icône colorée façon Réglages
class SettingsIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const SettingsIcon(this.icon, {super.key, this.color = AppColors.primary, this.size = 30});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size * 0.23)),
    child: Icon(icon, color: Colors.white, size: size * 0.6),
  );
}

/// Ligne de liste iOS : surbrillance à l'appui, chevron si la ligne s'ouvre
class Cell extends StatefulWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;
  final bool center;
  const Cell({super.key, this.leading, required this.title, this.subtitle, this.value, this.trailing, this.onTap, this.titleColor, this.center = false});
  @override
  State<Cell> createState() => _CellState();
}

class _CellState extends State<Cell> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final w = widget;
    final title = Text(w.title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: w.center ? TextAlign.center : TextAlign.start, style: AppText.body.copyWith(color: w.titleColor));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: w.onTap == null ? null : (_) => setState(() => _down = true),
      onTapUp: w.onTap == null ? null : (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: w.onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: _down ? 0 : 200),
        color: _down ? AppColors.line : Colors.transparent,
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          if (w.leading != null) ...[w.leading!, const SizedBox(width: 14)],
          Expanded(
            child: w.subtitle == null || w.subtitle!.isEmpty
                ? title
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 2), Text(w.subtitle!, style: AppText.caption)]),
          ),
          if (w.value != null) ...[const SizedBox(width: 8), Text(w.value!, style: AppText.body.copyWith(color: AppColors.muted))],
          if (w.trailing != null) ...[const SizedBox(width: 8), w.trailing!]
          else if (w.onTap != null && !w.center) ...[const SizedBox(width: 8), const Icon(CupertinoIcons.chevron_forward, size: 17, color: AppColors.faint)],
        ]),
      ),
    );
  }
}

/// Encadré d'information
class StatusBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? text;
  final Color background;
  const StatusBanner({super.key, required this.icon, required this.color, required this.title, this.text, this.background = AppColors.surface});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 24),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppText.label),
          if (text != null) ...[const SizedBox(height: 2), Text(text!, style: AppText.caption.copyWith(fontSize: 14))],
        ]),
      ),
    ]),
  );
}

/// Pastille (Épuisé, Gros, statut)
class Pill extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;
  const Pill(this.text, {super.key, this.background = AppColors.ink, this.foreground = Colors.white});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: AppText.caption.copyWith(color: foreground, fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0)),
  );
}

/// Barre d'action fixe en bas d'écran, fond flouté
class BottomActionBar extends StatelessWidget {
  final Widget child;
  final Color background;
  const BottomActionBar({super.key, required this.child, this.background = AppColors.surface});
  @override
  Widget build(BuildContext context) => ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        decoration: BoxDecoration(color: background.withValues(alpha: 0.82), border: const Border(top: BorderSide(color: AppColors.separator, width: 0.5))),
        padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
        child: child,
      ),
    ),
  );
}

/// État vide (contenu indisponible)
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? text;
  final String? action;
  final VoidCallback? onAction;
  const EmptyState({super.key, required this.icon, required this.title, this.text, this.action, this.onAction});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 52, color: AppColors.faint),
      const SizedBox(height: 16),
      Text(title, textAlign: TextAlign.center, style: AppText.headline),
      if (text != null) ...[const SizedBox(height: 6), Text(text!, textAlign: TextAlign.center, style: AppText.bodyMuted)],
      if (action != null) ...[
        const SizedBox(height: 18),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 26), shape: const StadiumBorder()),
          onPressed: onAction,
          child: Text(action!),
        ),
      ],
    ]),
  );
}

/// Bouton rond flouté posé sur une photo (retour, signaler)
class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const RoundIconButton(this.icon, {super.key, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    scale: 0.9,
    child: ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: 38,
          height: 38,
          color: Colors.white.withValues(alpha: 0.78),
          child: Icon(icon, size: 19, color: color ?? AppColors.ink),
        ),
      ),
    ),
  );
}

/// Pas-à-pas façon iOS (− | +)
class QtyStepper extends StatelessWidget {
  final int qty;
  final ValueChanged<int> onChanged;
  final int min;
  final bool compact;
  const QtyStepper({super.key, required this.qty, required this.onChanged, this.min = 1, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final h = compact ? 32.0 : 50.0;
    Widget btn(IconData icon, VoidCallback? onTap) => CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size(compact ? 34 : 44, h),
      onPressed: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap();
            },
      child: Icon(icon, size: compact ? 15 : 18, color: onTap == null ? AppColors.faint : AppColors.ink),
    );
    return Container(
      height: h,
      decoration: BoxDecoration(color: AppColors.fill, borderRadius: BorderRadius.circular(compact ? 9 : 14)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        btn(min == 0 && qty == 1 ? CupertinoIcons.trash : CupertinoIcons.minus, qty > min ? () => onChanged(qty - 1) : null),
        SizedBox(width: compact ? 22 : 28, child: Text('$qty', textAlign: TextAlign.center, style: (compact ? AppText.label : AppText.title).copyWith(fontFeatures: const [FontFeature.tabularFigures()]))),
        btn(CupertinoIcons.plus, () => onChanged(qty + 1)),
      ]),
    );
  }
}
