import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../core/app_colors.dart';
import '../services/photo_watermark_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE FORM WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

// ── ETIQUETA DE CAMPO ─────────────────────────────────────────────────────────
class FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const FieldLabel(this.text, {super.key, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: text,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary),
          children: required
              ? const [
                  TextSpan(
                      text: ' *',
                      style: TextStyle(color: AppColors.danger))
                ]
              : [],
        ),
      ),
    );
  }
}

// ── TITULO DE SECCION ─────────────────────────────────────────────────────────
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.primaryDark)),
    );
  }
}

// ── CAMPO SOLO LECTURA ────────────────────────────────────────────────────────
class ReadOnlyField extends StatelessWidget {
  final String value;
  final Color? color;
  const ReadOnlyField(this.value, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(value,
          style: TextStyle(
              fontSize: 13,
              color: color != null ? Colors.white : AppColors.textSecondary,
              fontWeight:
                  color != null ? FontWeight.bold : FontWeight.normal)),
    );
  }
}

// ── SELECTOR DE FECHA ─────────────────────────────────────────────────────────
class DatePickerField extends StatelessWidget {
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  const DatePickerField(
      {super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Expanded(
                child: Text(
                    DateFormat('dd/MM/yyyy').format(value),
                    style: const TextStyle(fontSize: 14))),
            const Icon(Icons.calendar_today,
                size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ── SELECTOR DE HORA ──────────────────────────────────────────────────────────
class TimePickerField extends StatelessWidget {
  final String value; // "HH:mm"
  final ValueChanged<String> onChanged;
  const TimePickerField(
      {super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final parts = value.split(':');
    final tod = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 8,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0);

    return GestureDetector(
      onTap: () async {
        final picked =
            await showTimePicker(context: context, initialTime: tod);
        if (picked != null) {
          onChanged(
              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Expanded(
                child:
                    Text(value, style: const TextStyle(fontSize: 14))),
            const Icon(Icons.access_time,
                size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ── SELECTOR CHIPS HORIZONTAL ─────────────────────────────────────────────────
class ChipSelector extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  const ChipSelector(
      {super.key,
      required this.options,
      required this.selected,
      required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.map((o) {
        final isSelected = selected == o;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(o),
            child: Container(
              margin:
                  EdgeInsets.only(right: o == options.last ? 0 : 6),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.chipSelected
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: isSelected
                        ? AppColors.chipSelected
                        : AppColors.border),
              ),
              child: Center(
                child: Text(o,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 12)),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── CHIP SELECCIONABLE INDIVIDUAL ─────────────────────────────────────────────
class SelectableChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const SelectableChip(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.chipSelected : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected
                  ? AppColors.chipSelected
                  : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
                color:
                    selected ? Colors.white : AppColors.textPrimary,
                fontSize: 12)),
      ),
    );
  }
}

// ── LISTA DE OPCIONES APILADAS ────────────────────────────────────────────────
class StackedOptionList extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  const StackedOptionList(
      {super.key,
      required this.options,
      required this.selected,
      required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: options.map((opt) {
        final isSelected = selected == opt;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: GestureDetector(
            onTap: () => onSelected(opt),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  vertical: 13, horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.chipSelected
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: isSelected
                        ? AppColors.chipSelected
                        : AppColors.border),
              ),
              child: Text(opt,
                  style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : AppColors.textPrimary,
                      fontSize: 13)),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── CAMPO FOTO ────────────────────────────────────────────────────────────────
class PhotoField extends StatefulWidget {
  final String label;
  final String? imagePath;
  final ValueChanged<String> onImageSelected;

  /// Si es true, al tomar/seleccionar una foto se le estampa una marca de agua
  /// con coordenadas GPS, fecha/hora y datos contextuales.
  final bool addGpsWatermark;
  final String? comunidad;
  final String? distrito;
  final String? nombreSocio;

  const PhotoField({
    super.key,
    required this.label,
    this.imagePath,
    required this.onImageSelected,
    this.addGpsWatermark = false,
    this.comunidad,
    this.distrito,
    this.nombreSocio,
  });

  @override
  State<PhotoField> createState() => _PhotoFieldState();
}

class _PhotoFieldState extends State<PhotoField> {
  final _picker = ImagePicker();
  bool _procesando = false;

  Future<void> _entregar(String path) async {
    if (!widget.addGpsWatermark || kIsWeb) {
      widget.onImageSelected(path);
      return;
    }
    setState(() => _procesando = true);
    try {
      final procesada = await PhotoWatermarkService.aplicarMarcaAgua(
        originalPath: path,
        comunidad: widget.comunidad,
        distrito: widget.distrito,
        nombreSocio: widget.nombreSocio,
      );
      widget.onImageSelected(procesada);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _pickImage() async {
    if (kIsWeb) {
      final file = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 70);
      if (file == null) return;
      setState(() => _procesando = true);
      try {
        final bytes = await file.readAsBytes();
        final ext   = file.name.contains('.') ? file.name.split('.').last : 'jpg';
        final ref   = FirebaseStorage.instance
            .ref('fats/web/${DateTime.now().millisecondsSinceEpoch}.$ext');

        // Intentar subir a Firebase Storage (30 seg timeout)
        String? url;
        try {
          await Future.any([
            ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg')),
            Future.delayed(const Duration(seconds: 30))
                .then((_) => throw Exception('Timeout')),
          ]);
          url = await ref.getDownloadURL();
        } catch (_) {
          // Storage no disponible → base64 como fallback (visible cross-platform)
          final b64 = base64Encode(bytes);
          url = 'data:image/$ext;base64,$b64';
        }
        if (mounted) widget.onImageSelected(url);
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ Web foto error: $e');
      } finally {
        if (mounted) setState(() => _procesando = false);
      }
      return;
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar foto'),
              subtitle: widget.addGpsWatermark
                  ? const Text(
                      'Se añadirá fecha/hora y coordenadas GPS',
                      style: TextStyle(fontSize: 11),
                    )
                  : null,
              onTap: () async {
                Navigator.pop(context);
                final file = await _picker.pickImage(
                    source: ImageSource.camera, imageQuality: 85);
                if (file != null) await _entregar(file.path);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeria'),
              onTap: () async {
                Navigator.pop(context);
                final file = await _picker.pickImage(
                    source: ImageSource.gallery, imageQuality: 85);
                if (file != null) await _entregar(file.path);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage =
        widget.imagePath != null && widget.imagePath!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(widget.label, required: true),
        GestureDetector(
          onTap: _procesando ? null : _pickImage,
          child: Container(
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: widget.addGpsWatermark
                      ? AppColors.primary.withValues(alpha: 0.4)
                      : AppColors.border),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: widget.imagePath!.startsWith('data:image')
                        ? Image.memory(
                            base64.decode(widget.imagePath!.split(',').last),
                            fit: BoxFit.cover)
                        : (kIsWeb || widget.imagePath!.startsWith('http'))
                            ? Image.network(widget.imagePath!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.broken_image, size: 40))
                            : Image.file(File(widget.imagePath!),
                                fit: BoxFit.cover),
                  )
                else
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt,
                          size: 36, color: Colors.grey.shade400),
                      const SizedBox(height: 4),
                      Text('Tomar foto',
                          style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12)),
                      if (widget.addGpsWatermark) ...[
                        const SizedBox(height: 4),
                        const Text(
                          '📍 Con GPS + fecha/hora',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                if (_procesando)
                  Container(
                    color: Colors.black.withValues(alpha: 0.55),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.4),
                          const SizedBox(height: 8),
                          Text(
                            kIsWeb ? 'Subiendo foto...' : 'Estampando GPS...',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (hasImage && widget.addGpsWatermark && !_procesando)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on,
                              color: Colors.white, size: 10),
                          SizedBox(width: 2),
                          Text('GPS',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 9)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── GPS FIELD ─────────────────────────────────────────────────────────────────
class GpsField extends StatelessWidget {
  final String? ubicacion;
  final VoidCallback onGetGps;
  const GpsField({super.key, this.ubicacion, required this.onGetGps});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
        color: Colors.grey.shade200,
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map, size: 44, color: Colors.grey.shade400),
                const SizedBox(height: 4),
                Text('Coordenadas GPS',
                    style: TextStyle(color: Colors.grey.shade500)),
                if (ubicacion != null && ubicacion!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(ubicacion!,
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  )
                else
                  Text('Sin ubicacion',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: ElevatedButton.icon(
              onPressed: onGetGps,
              icon: const Icon(Icons.my_location, size: 14),
              label: const Text('Obtener GPS',
                  style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── BADGE DE ESTADO ───────────────────────────────────────────────────────────
class EstadoBadge extends StatelessWidget {
  final String estado;
  const EstadoBadge(this.estado, {super.key});

  Color get _color {
    switch (estado.toUpperCase()) {
      case 'REGISTRADO':
        return AppColors.estadoRegistrado;
      case 'ENVIADO':
        return AppColors.estadoEnviado;
      case 'APROBADO':
        return AppColors.estadoAprobado;
      case 'OBSERVADO':
        return AppColors.estadoObservado;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(estado,
          style: TextStyle(
              color: _color,
              fontSize: 11,
              fontWeight: FontWeight.bold)),
    );
  }
}

// ── INDICADOR DE PAGINA ───────────────────────────────────────────────────────
class PageIndicator extends StatelessWidget {
  final int current; // 1-based
  final int total;
  const PageIndicator(
      {super.key, required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i + 1 == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active
                ? AppColors.chipSelected
                : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
