import 'package:flutter/cupertino.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets.dart';

/// Vignette photo : prise à l'appareil (pièces : appareil uniquement), envoyée puis affichée
class PhotoField extends StatefulWidget {
  final String label;
  final String? url;
  final bool identity;
  final bool enabled;
  final ValueChanged<String> onUploaded;
  const PhotoField({
    super.key,
    required this.label,
    required this.url,
    required this.onUploaded,
    this.identity = false,
    this.enabled = true,
  });
  @override
  State<PhotoField> createState() => _PhotoFieldState();
}

class _PhotoFieldState extends State<PhotoField> {
  File? _local;
  bool _busy = false;

  Future<void> _pick() async {
    final source = widget.identity
        ? ImageSource.camera
        : await showModalBottomSheet<ImageSource>(
            context: context,
            builder: (c) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(PhosphorIconsBold.camera),
                    title: const Text('Prendre une photo'),
                    onTap: () => Navigator.pop(c, ImageSource.camera),
                  ),
                  ListTile(
                    leading: const Icon(PhosphorIconsBold.image),
                    title: const Text('Choisir dans la galerie'),
                    onTap: () => Navigator.pop(c, ImageSource.gallery),
                  ),
                ],
              ),
            ),
          );
    if (source == null) return;
    final f = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 75,
    );
    if (f == null || !mounted) return;
    setState(() {
      _local = File(f.path);
      _busy = true;
    });
    try {
      widget.onUploaded(
        await Api.instance.upload(File(f.path), identity: widget.identity),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _local = null);
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pièce d'identité déjà envoyée : privée, non relue par l'app (on affiche seulement « envoyée »)
    final has = _local != null || widget.url != null;
    return InkWell(
      onTap: widget.enabled && !_busy ? _pick : null,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_local != null)
                    Image.file(_local!, fit: BoxFit.cover, cacheWidth: 480)
                  else if (widget.url != null && !widget.identity)
                    NetImage(widget.url, width: 240)
                  else
                    Icon(
                      has
                          ? PhosphorIconsFill.checkCircle
                          : PhosphorIconsFill.camera,
                      color: has ? AppColors.success : AppColors.primary,
                      size: 32,
                    ),
                  if (_busy)
                    Container(
                      color: Colors.black38,
                      child: const Center(
                        child: CupertinoActivityIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          if (widget.identity && has && _local == null)
            const Text(
              'Envoyée',
              style: TextStyle(fontSize: 11.5, color: AppColors.success),
            ),
        ],
      ),
    );
  }
}
