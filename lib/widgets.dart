import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
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
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(msg)),
          ],
        ),
      ),
    );
}

void showError(BuildContext context, Object e) {
  HapticFeedback.lightImpact();
  _toast(
    context,
    // Messages prévus pour l'utilisateur ; tout imprévu reste discret
    e is String || e is ApiException
        ? e.toString()
        : 'On s’en occupe : réessayez dans un instant.',
    CupertinoIcons.info_circle_fill,
  );
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
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(padding),
    child: const Center(child: CupertinoActivityIndicator(radius: 11)),
  );
}

/// Grand titre iOS qui se réduit au défilement (fond flouté une fois la page défilée)
class LargeTitleBar extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget? leading;
  final Color? background;
  const LargeTitleBar(
    this.title, {
    super.key,
    this.trailing,
    this.leading,
    this.background,
  });
  @override
  Widget build(BuildContext context) => CupertinoSliverNavigationBar(
    largeTitle: Text(title),
    trailing: trailing,
    leading: leading,
    previousPageTitle: 'Retour',
    transitionBetweenRoutes: false,
    backgroundColor: (background ?? AppColors.background).withValues(
      alpha: 0.86,
    ),
    border: const Border(
      bottom: BorderSide(color: AppColors.separator, width: 0),
    ),
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
    child: Text(
      text,
      style: AppText.body.copyWith(
        color: onTap == null ? AppColors.faint : AppColors.primary,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
      ),
    ),
  );
}

/// Réduit légèrement l'élément pendant l'appui
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
  });
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: widget.onTap == null
        ? null
        : (_) => setState(() => _down = true),
    onTapUp: widget.onTap == null ? null : (_) => setState(() => _down = false),
    onTapCancel: () => setState(() => _down = false),
    onTap: widget.onTap == null
        ? null
        : () {
            HapticFeedback.selectionClick();
            widget.onTap!();
          },
    child: AnimatedScale(
      scale: _down ? widget.scale : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: widget.child,
    ),
  );
}

/// Image réseau : miniature à la bonne taille, gardée sur le téléphone (disque + mémoire), fondu discret.
/// [width] = largeur affichée en points ; [preview] = miniature déjà chargée affichée en attendant.
class NetImage extends StatelessWidget {
  final String? path;
  final BoxFit fit;
  final IconData placeholder;
  final double width;
  final double? previewWidth;
  const NetImage(
    this.path, {
    super.key,
    this.fit = BoxFit.cover,
    this.placeholder = CupertinoIcons.photo,
    this.width = 200,
    this.previewWidth,
  });
  @override
  Widget build(BuildContext context) {
    final empty = Container(
      color: AppColors.surfaceAlt,
      alignment: Alignment.center,
      child: Icon(placeholder, color: AppColors.faint, size: 28),
    );
    if (path == null || path!.isEmpty) return empty;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 3;
    final px = (width * dpr).round();
    Widget preview(BuildContext c) => previewWidth == null
        ? Container(color: AppColors.surfaceAlt)
        : CachedNetworkImage(
            imageUrl: thumbUrl(path!, (previewWidth! * dpr).round()),
            fit: fit,
            fadeInDuration: Duration.zero,
            placeholder: (_, _) => Container(color: AppColors.surfaceAlt),
            errorWidget: (_, _, _) => empty,
          );
    return CachedNetworkImage(
      imageUrl: thumbUrl(path!, px),
      fit: fit,
      memCacheWidth: px,
      fadeInDuration: const Duration(milliseconds: 160),
      fadeOutDuration: Duration.zero,
      placeholder: (c, _) => preview(c),
      errorWidget: (_, _, _) => empty,
    );
  }
}

/// Bloc gris en attendant le contenu (pulsation lente, sans dégradé)
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const Skeleton({
    super.key,
    this.width,
    required this.height,
    this.radius = 10,
  });
  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 1.0, end: 0.55).animate(_c),
    child: Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    ),
  );
}

/// Grille de cartes produit fantômes (premier chargement)
class ProductGridSkeleton extends StatelessWidget {
  final int count;
  const ProductGridSkeleton({super.key, this.count = 4});
  @override
  Widget build(BuildContext context) => SliverGrid.builder(
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisSpacing: 18,
      crossAxisSpacing: 10,
      childAspectRatio: 0.66,
    ),
    itemCount: count,
    itemBuilder: (_, _) => const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 4 / 5,
          child: Skeleton(height: double.infinity, radius: 14),
        ),
        SizedBox(height: 10),
        Skeleton(height: 13, width: 120),
        SizedBox(height: 6),
        Skeleton(height: 13, width: 70),
      ],
    ),
  );
}

/// Motif inspiré des pagnes wax (formes géométriques à plat, couleurs de la marque) : identité visuelle
class WaxPattern extends StatelessWidget {
  final Color background;
  final Color ink;
  final Color accent;
  final int seed;
  final Widget? child;
  const WaxPattern({
    super.key,
    this.background = AppColors.primary,
    this.ink = const Color(0x2EFFFFFF),
    this.accent = AppColors.accent,
    this.seed = 0,
    this.child,
  });
  // Motif peint une fois puis réutilisé au défilement et aux animations
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _WaxPainter(background, ink, accent, seed),
      child: child,
    ),
  );
}

class _WaxPainter extends CustomPainter {
  final Color bg, ink, accent;
  final int seed;
  _WaxPainter(this.bg, this.ink, this.accent, this.seed);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final dot = Paint()..color = ink;
    final hot = Paint()..color = accent;
    const step = 46.0;
    var row = 0;
    for (var y = -step / 2; y < size.height + step; y += step * 0.86, row++) {
      var col = 0;
      for (
        var x = (row.isOdd ? step / 2 : 0.0) - step / 2;
        x < size.width + step;
        x += step, col++
      ) {
        final c = Offset(x, y);
        final k = (row * 7 + col * 3 + seed) % 5;
        if (k == 0) {
          // Cercles concentriques (motif « œil »)
          canvas.drawCircle(c, 14, line);
          canvas.drawCircle(c, 6, (row + col + seed) % 4 == 0 ? hot : dot);
        } else if (k == 1 || k == 3) {
          // Losange
          final path = Path()
            ..moveTo(c.dx, c.dy - 12)
            ..lineTo(c.dx + 12, c.dy)
            ..lineTo(c.dx, c.dy + 12)
            ..lineTo(c.dx - 12, c.dy)
            ..close();
          canvas.drawPath(path, line);
        } else {
          canvas.drawCircle(c, 3, dot);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_WaxPainter o) =>
      o.bg != bg || o.ink != ink || o.accent != accent || o.seed != seed;
}

/// Puce de filtre (Trier, Prix, Marché…) : pleine quand le filtre est actif
class FilterPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool dropdown;
  final IconData? icon;
  const FilterPill(
    this.label, {
    super.key,
    required this.onTap,
    this.active = false,
    this.dropdown = true,
    this.icon,
  });
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: active ? AppColors.ink : AppColors.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: active ? AppColors.ink : AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: active ? Colors.white : AppColors.ink),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: AppText.subhead.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: active ? Colors.white : AppColors.ink,
            ),
          ),
          if (dropdown) ...[
            const SizedBox(width: 4),
            Icon(
              CupertinoIcons.chevron_down,
              size: 12,
              color: active ? Colors.white : AppColors.muted,
            ),
          ],
        ],
      ),
    ),
  );
}

/// En-tête collant (filtres qui restent visibles pendant le défilement)
class StickyHeader extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;
  final Color background;
  StickyHeader({
    required this.height,
    required this.child,
    this.background = AppColors.surface,
  });
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        height: height,
        color: background.withValues(alpha: 0.9),
        foregroundDecoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: overlapsContent || shrinkOffset > 0
                  ? AppColors.separator
                  : Colors.transparent,
              width: 0.5,
            ),
          ),
        ),
        child: child,
      ),
    ),
  );
  @override
  bool shouldRebuild(StickyHeader o) => true;
}

/// En-tête de section : titre gras + « Tout voir »
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsets padding;
  const SectionHeader(
    this.title, {
    super.key,
    this.action,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(18, 26, 10, 8),
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(
      children: [
        Expanded(child: Text(title, style: AppText.headline)),
        if (action != null)
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(44, 32),
            onPressed: onAction,
            child: Text(
              action!,
              style: AppText.subhead.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    ),
  );
}

/// Titre de groupe façon Réglages (petites capitales grises)
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
    child: Text(
      text.toUpperCase(),
      style: AppText.caption.copyWith(fontSize: 11.5, letterSpacing: 0.2),
    ),
  );
}

/// Note sous un groupe
class SectionFooter extends StatelessWidget {
  final String text;
  const SectionFooter(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
    child: Text(text, style: AppText.caption),
  );
}

/// Groupe arrondi (liste « inset grouped » d'iOS), séparateurs fins
class Group extends StatelessWidget {
  final List<Widget> children;
  final double dividerIndent;
  final Color color;
  const Group({
    super.key,
    required this.children,
    this.dividerIndent = 16,
    this.color = AppColors.surface,
  });
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
    ),
    clipBehavior: Clip.antiAlias,
    child: Material(
      color: Colors.transparent,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) Divider(indent: dividerIndent),
          ],
        ],
      ),
    ),
  );
}

/// Pastille d'icône colorée façon Réglages
class SettingsIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const SettingsIcon(
    this.icon, {
    super.key,
    this.color = AppColors.primary,
    this.size = 27,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(size * 0.23),
    ),
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
  const Cell({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.titleColor,
    this.center = false,
  });
  @override
  State<Cell> createState() => _CellState();
}

class _CellState extends State<Cell> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final w = widget;
    final title = Text(
      w.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: w.center ? TextAlign.center : TextAlign.start,
      style: AppText.body.copyWith(color: w.titleColor),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: w.onTap == null ? null : (_) => setState(() => _down = true),
      onTapUp: w.onTap == null ? null : (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: w.onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: _down ? 0 : 200),
        color: _down ? AppColors.line : Colors.transparent,
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            if (w.leading != null) ...[w.leading!, const SizedBox(width: 12)],
            Expanded(
              child: w.subtitle == null || w.subtitle!.isEmpty
                  ? title
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title,
                        const SizedBox(height: 2),
                        Text(w.subtitle!, style: AppText.caption),
                      ],
                    ),
            ),
            if (w.value != null) ...[
              const SizedBox(width: 8),
              Text(
                w.value!,
                style: AppText.body.copyWith(color: AppColors.muted),
              ),
            ],
            if (w.trailing != null) ...[
              const SizedBox(width: 8),
              w.trailing!,
            ] else if (w.onTap != null && !w.center) ...[
              const SizedBox(width: 8),
              const Icon(
                CupertinoIcons.chevron_forward,
                size: 14,
                color: AppColors.faint,
              ),
            ],
          ],
        ),
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
  const StatusBanner({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.text,
    this.background = AppColors.surface,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.label),
              if (text != null) ...[
                const SizedBox(height: 2),
                Text(text!, style: AppText.caption.copyWith(fontSize: 14)),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

/// Pastille (Épuisé, Gros, statut)
class Pill extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;
  const Pill(
    this.text, {
    super.key,
    this.background = AppColors.ink,
    this.foreground = Colors.white,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: AppText.caption.copyWith(
        color: foreground,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    ),
  );
}

/// Barre d'action fixe en bas d'écran, fond flouté
class BottomActionBar extends StatelessWidget {
  final Widget child;
  final Color background;
  const BottomActionBar({
    super.key,
    required this.child,
    this.background = AppColors.surface,
  });
  @override
  Widget build(BuildContext context) => ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        decoration: BoxDecoration(
          color: background.withValues(alpha: 0.82),
          border: const Border(
            top: BorderSide(color: AppColors.separator, width: 0.5),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          10 + MediaQuery.of(context).padding.bottom,
        ),
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
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.text,
    this.action,
    this.onAction,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 42, color: AppColors.faint),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: AppText.headline),
        if (text != null) ...[
          const SizedBox(height: 6),
          Text(text!, textAlign: TextAlign.center, style: AppText.bodyMuted),
        ],
        if (action != null) ...[
          const SizedBox(height: 18),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 22),
              shape: const StadiumBorder(),
            ),
            onPressed: onAction,
            child: Text(action!),
          ),
        ],
      ],
    ),
  );
}

/// Bouton rond flouté posé sur une photo (retour, signaler)
class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const RoundIconButton(
    this.icon, {
    super.key,
    required this.onTap,
    this.color,
  });
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    scale: 0.9,
    child: ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: 34,
          height: 34,
          color: Colors.white.withValues(alpha: 0.72),
          child: Icon(icon, size: 16, color: color ?? AppColors.ink),
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
  const QtyStepper({
    super.key,
    required this.qty,
    required this.onChanged,
    this.min = 1,
    this.compact = false,
  });
  @override
  Widget build(BuildContext context) {
    final h = compact ? 30.0 : 46.0;
    Widget btn(IconData icon, VoidCallback? onTap) => CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size(compact ? 34 : 44, h),
      onPressed: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap();
            },
      child: Icon(
        icon,
        size: compact ? 15 : 18,
        color: onTap == null ? AppColors.faint : AppColors.ink,
      ),
    );
    return Container(
      height: h,
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(h / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(
            min == 0 && qty == 1 ? CupertinoIcons.trash : CupertinoIcons.minus,
            qty > min ? () => onChanged(qty - 1) : null,
          ),
          SizedBox(
            width: compact ? 22 : 28,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: (compact ? AppText.label : AppText.title).copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          btn(CupertinoIcons.plus, () => onChanged(qty + 1)),
        ],
      ),
    );
  }
}

/// Hauteur occupée par la barre d'onglets flottante (pour laisser le contenu défiler au-dessus)
double tabBarHeight(BuildContext context) {
  final b = MediaQuery.of(context).padding.bottom;
  return (b > 0 ? b : 12) + 62;
}

/// Surface « verre » d'iOS : flou, voile clair, liseré lumineux, ombre douce
class Glass extends StatelessWidget {
  final Widget child;
  final BorderRadius radius;
  final double opacity;
  const Glass({
    super.key,
    required this.child,
    required this.radius,
    this.opacity = 0.72,
  });
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: radius,
      boxShadow: const [
        BoxShadow(
          color: Color(0x1F000000),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: radius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
              width: 0.8,
            ),
          ),
          child: child,
        ),
      ),
    ),
  );
}
