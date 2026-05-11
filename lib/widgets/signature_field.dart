import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../core/app_colors.dart';
import 'form_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SIGNATURE PAD FIELD
//
// Permite que el socio dibuje su firma con el dedo o un lápiz óptico
// directamente en pantalla. Al confirmar, exporta el trazo a PNG y guarda
// el archivo en el directorio de la app, devolviendo la ruta vía
// [onSignatureSaved]. En web devuelve un data:image/png;base64 para mostrar
// inline (no se sube a Storage en esta iteración).
// ─────────────────────────────────────────────────────────────────────────────
class SignatureField extends StatefulWidget {
  final String label;
  final String? imagePath;
  final ValueChanged<String> onSignatureSaved;

  const SignatureField({
    super.key,
    required this.label,
    this.imagePath,
    required this.onSignatureSaved,
  });

  @override
  State<SignatureField> createState() => _SignatureFieldState();
}

class _SignatureFieldState extends State<SignatureField> {
  final GlobalKey<SfSignaturePadState> _signKey = GlobalKey();
  bool _firmando = false;
  bool _guardando = false;
  bool _vacio = true;

  Future<void> _guardar() async {
    if (_vacio) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('La firma está vacía'),
      ));
      return;
    }
    setState(() => _guardando = true);
    try {
      final pad = _signKey.currentState!;
      final ui.Image image = await pad.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();

      String savedPath;
      if (kIsWeb) {
        // En web no podemos escribir archivos, devolvemos data-URL inline
        savedPath = 'data:image/png;base64,${base64Encode(bytes)}';
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final outDir = Directory(p.join(dir.path, 'firmas'));
        if (!await outDir.exists()) await outDir.create(recursive: true);
        savedPath = p.join(
          outDir.path,
          'firma_${DateTime.now().microsecondsSinceEpoch}.png',
        );
        await File(savedPath).writeAsBytes(bytes);
      }
      widget.onSignatureSaved(savedPath);
      if (mounted) {
        setState(() {
          _firmando = false;
          _guardando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar firma: $e')),
        );
      }
    }
  }

  void _limpiar() {
    _signKey.currentState?.clear();
    setState(() => _vacio = true);
  }

  void _iniciar() {
    setState(() {
      _firmando = true;
      _vacio = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasImage =
        widget.imagePath != null && widget.imagePath!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(widget.label, required: true),
        if (_firmando)
          _buildPad()
        else if (hasImage)
          _buildPreview()
        else
          _buildPlaceholder(),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Estado: ya hay firma guardada (mostrar miniatura + reemplazar) ─────────
  Widget _buildPreview() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 160,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.success, width: 1.4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _renderImage(widget.imagePath!),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.check_circle,
                color: AppColors.success, size: 16),
            const SizedBox(width: 4),
            const Text('Firma capturada',
                style: TextStyle(
                    color: AppColors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton.icon(
              onPressed: _iniciar,
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: const Text('Volver a firmar',
                  style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ],
    );
  }

  // ── Estado: aún no hay firma → botón grande "Capturar firma" ───────────────
  Widget _buildPlaceholder() {
    return GestureDetector(
      onTap: _iniciar,
      child: Container(
        width: double.infinity,
        height: 130,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AppColors.accentBlue.withOpacity(0.5), width: 1.4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.draw_outlined,
                color: AppColors.accentBlue, size: 36),
            const SizedBox(height: 6),
            const Text('Toca para firmar',
                style: TextStyle(
                    color: AppColors.accentBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            const SizedBox(height: 2),
            Text(
              'El socio dibuja con el dedo o lápiz óptico',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // ── Estado: pad activo dibujando ───────────────────────────────────────────
  Widget _buildPad() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary, width: 1.6),
      ),
      child: Column(
        children: [
          // Pad de dibujo
          SizedBox(
            height: 200,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
              child: SfSignaturePad(
                key: _signKey,
                backgroundColor: const Color(0xFFFAFAFA),
                strokeColor: Colors.black,
                minimumStrokeWidth: 1.5,
                maximumStrokeWidth: 3.0,
                onDrawStart: () {
                  if (_vacio) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _vacio = false);
                    });
                  }
                  return false;
                },
              ),
            ),
          ),
          // Barra inferior con acciones
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(10)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _vacio
                        ? 'Firma del socio dentro del recuadro'
                        : 'Trazo capturado',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade700),
                  ),
                ),
                TextButton.icon(
                  onPressed: _vacio ? null : _limpiar,
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Limpiar',
                      style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 4),
                ElevatedButton.icon(
                  onPressed: _guardando ? null : _guardar,
                  icon: _guardando
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check, size: 14),
                  label: const Text('Confirmar',
                      style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _renderImage(String pathOrDataUrl) {
    if (pathOrDataUrl.startsWith('data:image')) {
      final base64Part = pathOrDataUrl.split(',').last;
      final bytes = base64Decode(base64Part);
      return Image.memory(bytes, fit: BoxFit.contain);
    }
    if (kIsWeb) {
      return Image.network(pathOrDataUrl,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.broken_image, size: 40));
    }
    final f = File(pathOrDataUrl);
    if (!f.existsSync()) {
      return const Center(
        child: Icon(Icons.image_not_supported,
            color: AppColors.textSecondary, size: 36),
      );
    }
    return Image.file(f, fit: BoxFit.contain);
  }
}
