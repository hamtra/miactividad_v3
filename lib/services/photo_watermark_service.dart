import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image/image.dart' as img;
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PHOTO WATERMARK SERVICE
//
// Toma una imagen capturada (path local), obtiene las coordenadas GPS y le
// estampa una banda inferior negra semi-transparente con:
//   • LAT, LNG (6 decimales)
//   • Fecha y hora (dd/MM/yyyy HH:mm)
//   • Comunidad / distrito (opcional)
//   • Nombre del socio (opcional)
//
// Devuelve la ruta a la imagen procesada (o la original si falla algo).
// En modo Web no se aplica (image_picker en web ya devuelve un blob URL,
// no podemos leer/escribir archivos locales tan fácilmente).
// ─────────────────────────────────────────────────────────────────────────────
class PhotoWatermarkService {
  /// Aplica marca de agua a la foto en [originalPath].
  /// Devuelve la ruta de la nueva imagen procesada.
  static Future<String> aplicarMarcaAgua({
    required String originalPath,
    String? comunidad,
    String? distrito,
    String? nombreSocio,
    bool incluirGps = true,
  }) async {
    if (kIsWeb) return originalPath; // En web no aplicamos watermark
    try {
      final file = File(originalPath);
      if (!await file.exists()) return originalPath;

      // 1. Obtener coordenadas (best-effort)
      double? lat;
      double? lng;
      if (incluirGps) {
        final pos = await _obtenerPosicionSegura();
        lat = pos?.latitude;
        lng = pos?.longitude;
      }

      // 2. Decodificar imagen
      final bytes = await file.readAsBytes();
      img.Image? imagen = img.decodeImage(bytes);
      if (imagen == null) return originalPath;

      // 3. Pre-escalado: si la imagen es muy grande, reducir para que el
      //    texto se vea proporcional y el archivo no pese tanto.
      const int maxDim = 1600;
      if (imagen.width > maxDim || imagen.height > maxDim) {
        if (imagen.width >= imagen.height) {
          imagen = img.copyResize(imagen, width: maxDim);
        } else {
          imagen = img.copyResize(imagen, height: maxDim);
        }
      }

      // 4. Componer texto
      final lineas = <String>[];
      final ahora = DateTime.now();
      lineas.add(DateFormat('dd/MM/yyyy HH:mm').format(ahora));
      if (lat != null && lng != null) {
        lineas.add(
            'LAT: ${lat.toStringAsFixed(6)}   LNG: ${lng.toStringAsFixed(6)}');
      }
      final ubic = [
        if ((comunidad ?? '').isNotEmpty) comunidad!,
        if ((distrito ?? '').isNotEmpty) distrito!,
      ].join(' · ');
      if (ubic.isNotEmpty) lineas.add(ubic);
      if ((nombreSocio ?? '').isNotEmpty) {
        lineas.add('Socio: $nombreSocio');
      }

      // 5. Dibujar banda y texto
      _estamparMarcaAgua(imagen, lineas);

      // 6. Guardar como JPEG en directorio de la app
      final dir = await getApplicationDocumentsDirectory();
      final outDir = Directory(p.join(dir.path, 'fat_fotos'));
      if (!await outDir.exists()) await outDir.create(recursive: true);
      final outPath = p.join(outDir.path,
          'foto_${DateTime.now().microsecondsSinceEpoch}.jpg');
      final outBytes =
          Uint8List.fromList(img.encodeJpg(imagen, quality: 82));
      await File(outPath).writeAsBytes(outBytes);
      return outPath;
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ Watermark falló: $e — devolviendo original');
      return originalPath;
    }
  }

  // ── Posición GPS con manejo de permisos ────────────────────────────────────
  static Future<Position?> _obtenerPosicionSegura() async {
    try {
      final servicio = await Geolocator.isLocationServiceEnabled();
      if (!servicio) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8));
    } catch (_) {
      return null;
    }
  }

  // ── Dibujar banda inferior + texto ─────────────────────────────────────────
  static void _estamparMarcaAgua(img.Image base, List<String> lineas) {
    if (lineas.isEmpty) return;
    final fuente = _elegirFuente(base.width);
    final altoLinea = fuente.lineHeight;
    final int padding = (base.width * 0.02).round().clamp(8, 40).toInt();
    final altoBanda = altoLinea * lineas.length + padding * 2;
    final yInicio = base.height - altoBanda;

    // Banda negra semi-transparente
    img.fillRect(
      base,
      x1: 0,
      y1: yInicio,
      x2: base.width - 1,
      y2: base.height - 1,
      color: img.ColorRgba8(0, 0, 0, 170),
    );

    // Borde superior verde para destacar (estilo CTSE)
    img.drawLine(
      base,
      x1: 0,
      y1: yInicio,
      x2: base.width - 1,
      y2: yInicio,
      color: img.ColorRgba8(46, 148, 72, 255),
      thickness: 2,
    );

    // Texto blanco
    int y = yInicio + padding;
    for (final linea in lineas) {
      img.drawString(
        base,
        linea,
        font: fuente,
        x: padding,
        y: y,
        color: img.ColorRgba8(255, 255, 255, 255),
      );
      y += altoLinea;
    }
  }

  /// Elige una fuente bitmap según el ancho de la imagen para que el
  /// texto se lea bien en pantallas grandes y pequeñas.
  static img.BitmapFont _elegirFuente(int ancho) {
    if (ancho >= 1400) return img.arial48;
    if (ancho >= 900) return img.arial24;
    if (ancho >= 500) return img.arial14;
    return img.arial14;
  }
}
