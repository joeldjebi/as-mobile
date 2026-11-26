import 'package:flutter/material.dart';

import 'theme.dart';

/// Message d'erreur : jamais de fond rouge, jamais de détail technique
void showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(e.toString().replaceFirst('Exception: ', '')),
    backgroundColor: AppColors.ink,
    behavior: SnackBarBehavior.floating,
  ));
}

void showInfo(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.primaryDark, behavior: SnackBarBehavior.floating));
}

/// Titre de section en petites capitales
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.muted, letterSpacing: 0.4)),
  );
}

/// Groupe blanc arrondi (façon réglages)
class Group extends StatelessWidget {
  final List<Widget> children;
  const Group({super.key, required this.children});
  @override
  Widget build(BuildContext context) => Card(
    child: Column(children: [
      for (var i = 0; i < children.length; i++) ...[
        children[i],
        if (i < children.length - 1) const Divider(height: 1, indent: 16),
      ],
    ]),
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
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 26),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.ink)),
          if (text != null) ...[const SizedBox(height: 2), Text(text!, style: const TextStyle(color: AppColors.muted))],
        ]),
      ),
    ]),
  );
}

/// Numéro au format lisible : +225 07 01 02 03 04
String formatPhone(String? p) {
  if (p == null || p.isEmpty) return '';
  final m = RegExp(r'^\+225(\d{10})$').firstMatch(p);
  if (m == null) return p;
  final d = m.group(1)!;
  return '+225 ${d.substring(0, 2)} ${d.substring(2, 4)} ${d.substring(4, 6)} ${d.substring(6, 8)} ${d.substring(8)}';
}
