import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/fat.dart';
import '../core/catalog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FAT PDF SERVICE
//
// Genera el PDF completo de una Ficha de Asistencia Técnica (FAT).
// Incluye: cabecera institucional, identificación, ubicación (+ GPS),
// responsable, lista de participantes, desarrollo / resultados / acuerdos,
// próxima visita, firma digital del productor y panel fotográfico.
// ─────────────────────────────────────────────────────────────────────────────
class FatPdfService {
  static const _verde      = PdfColor.fromInt(0xFF1B5E20);
  static const _verdeClaro = PdfColor.fromInt(0xFF2E7D32);
  static const _grisClaro  = PdfColor.fromInt(0xFFF5F5F5);
  static const _grisBorde  = PdfColor.fromInt(0xFFDDDDDD);

  // ── Punto de entrada público ──────────────────────────────────────────────
  static Future<void> mostrarPdf(
    BuildContext context,
    Fat fat, {
    List<SocioParticipante> socios = const [],
  }) async {
    final doc = await _buildPdf(fat, socios: socios);
    final nombre =
        'FAT_${fat.nroFat.replaceAll('/', '_')}_'
        '${DateFormat('yyyyMMdd').format(fat.fechaAsistencia)}.pdf';
    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: nombre,
    );
  }

  // ── Construcción del documento ────────────────────────────────────────────
  static Future<pw.Document> _buildPdf(
    Fat fat, {
    List<SocioParticipante> socios = const [],
  }) async {
    final doc = pw.Document();

    final firmaBytes = await _loadImage(fat.firmaSocio);
    final foto1      = await _loadImage(fat.fotografia1);
    final foto2      = await _loadImage(fat.fotografia2);
    final foto3      = await _loadImage(fat.fotografia3);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        header: (_) => _buildHeader(fat),
        footer: (ctx) => _buildFooter(ctx),
        build: (_) => [
          _buildIdentificacion(fat),
          pw.SizedBox(height: 8),
          _buildUbicacion(fat),
          pw.SizedBox(height: 8),
          _buildResponsable(fat),
          pw.SizedBox(height: 8),
          if (socios.isNotEmpty) ...[
            _buildParticipantes(socios),
            pw.SizedBox(height: 8),
          ],
          _buildDesarrollo(fat),
          pw.SizedBox(height: 8),
          _buildProximaVisita(fat),
          pw.SizedBox(height: 14),
          _buildFirmas(fat, firmaBytes),
          pw.SizedBox(height: 14),
          if (foto1 != null || foto2 != null || foto3 != null)
            _buildPanelFotos(fat, foto1, foto2, foto3),
        ],
      ),
    );
    return doc;
  }

  // ── Encabezado ─────────────────────────────────────────────────────────────
  static pw.Widget _buildHeader(Fat fat) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        decoration: const pw.BoxDecoration(
            border: pw.Border(
                bottom: pw.BorderSide(color: _verde, width: 2))),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('FICHA DE ASISTENCIA TÉCNICA — FAT',
                    style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: _verde)),
                pw.Text('${CatalogData.nombreActividad}  ·  ${fat.mes}',
                    style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(fat.nroFat,
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: _verdeClaro)),
                pw.Text('Estado: ${fat.estado}',
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: fat.estado == 'APROBADO'
                            ? PdfColors.green700
                            : fat.estado == 'OBSERVADO'
                                ? PdfColors.orange800
                                : PdfColors.grey700)),
              ],
            ),
          ],
        ),
      );

  // ── Pie de página ──────────────────────────────────────────────────────────
  static pw.Widget _buildFooter(pw.Context ctx) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 5),
        decoration: const pw.BoxDecoration(
            border:
                pw.Border(top: pw.BorderSide(color: _grisBorde))),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
                'Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                style:
                    const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
            pw.Text('Pág. ${ctx.pageNumber} / ${ctx.pagesCount}',
                style:
                    const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          ],
        ),
      );

  // ── 1. Identificación ─────────────────────────────────────────────────────
  static pw.Widget _buildIdentificacion(Fat fat) => _seccion(
        '1. Identificación de la intervención',
        [
          pw.Row(children: [
            pw.Expanded(
                child: _kv('Fecha asistencia:',
                    DateFormat('dd/MM/yyyy').format(fat.fechaAsistencia))),
            pw.Expanded(child: _kv('Modalidad:', fat.modalidad)),
          ]),
          pw.Row(children: [
            pw.Expanded(
                child: _kv('Etapa del cultivo:', fat.etapaCrianza)),
            pw.Expanded(child: _kv('N.° Ficha:', fat.nroFat)),
          ]),
          _kv('Tarea / Actividad:', CatalogData.labelFromIdPta(fat.idPta)),
          _kv('Tema:', CatalogData.labelFromIdTema(fat.idTema)),
        ],
      );

  // ── 2. Ubicación ──────────────────────────────────────────────────────────
  static pw.Widget _buildUbicacion(Fat fat) => _seccion(
        '2. Ubicación',
        [
          pw.Row(children: [
            pw.Expanded(child: _kv('Provincia:', fat.provincia)),
            pw.Expanded(child: _kv('Distrito:', fat.distrito)),
          ]),
          pw.Row(children: [
            pw.Expanded(child: _kv('Comunidad / Sector:', fat.comunidad)),
            pw.Expanded(
                child: _kv('Horario:',
                    '${fat.horaInicio} – ${fat.horaFinal}')),
          ]),
          pw.Row(children: [
            pw.Expanded(child: _kv('Clima:', fat.clima)),
            pw.Expanded(child: _kv('Incidencia:', fat.incidencia)),
          ]),
          if ((fat.ubicacion ?? '').isNotEmpty)
            _kv('Coordenadas GPS:', fat.ubicacion!),
        ],
      );

  // ── 3. Responsable ────────────────────────────────────────────────────────
  static pw.Widget _buildResponsable(Fat fat) => _seccion(
        '3. Responsable',
        [
          pw.Row(children: [
            pw.Expanded(
                child: _kv('Técnico / Extensionista:', fat.nombreTecnico)),
            pw.Expanded(child: _kv('Cargo:', fat.cargo)),
          ]),
          pw.Row(children: [
            pw.Expanded(
                child: _kv('Organización:', fat.organizacionProductores)),
            pw.Expanded(
                child: _kv(
                    'N.° participantes:', '${fat.nroSociosParticipantes}')),
          ]),
        ],
      );

  // ── Participantes ─────────────────────────────────────────────────────────
  static pw.Widget _buildParticipantes(List<SocioParticipante> socios) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: const pw.BoxDecoration(
            color: _verde,
            borderRadius: pw.BorderRadius.only(
              topLeft: pw.Radius.circular(4),
              topRight: pw.Radius.circular(4),
            ),
          ),
          child: pw.Text('ANEXO 2. Lista de participantes',
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white)),
        ),
        pw.Table(
          border: pw.TableBorder.all(color: _grisBorde, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(0.8),
            1: const pw.FlexColumnWidth(2.0),
            2: const pw.FlexColumnWidth(7.2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _verdeClaro),
              children: ['N.°', 'DNI', 'Nombre completo']
                  .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(h,
                            style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white),
                            textAlign: pw.TextAlign.center),
                      ))
                  .toList(),
            ),
            ...socios.asMap().entries.map((e) {
              final bg = e.key.isEven ? PdfColors.white : _grisClaro;
              return pw.TableRow(
                decoration: pw.BoxDecoration(color: bg),
                children: [
                  _celda('${e.key + 1}', center: true),
                  _celda(e.value.dni),
                  _celda(e.value.nombreCompleto),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  // ── 5. Desarrollo ─────────────────────────────────────────────────────────
  static pw.Widget _buildDesarrollo(Fat fat) => _seccion(
        '5. Desarrollo, resultados y acuerdos',
        [
          if (fat.actividadesRealizadas.isNotEmpty)
            _bloqueLargo('Actividades realizadas:', fat.actividadesRealizadas),
          if (fat.resultados.isNotEmpty)
            _bloqueLargo('Resultados / aprendizajes:', fat.resultados),
          if (fat.acuerdosCompromisos.isNotEmpty)
            _bloqueLargo('Acuerdos y compromisos:', fat.acuerdosCompromisos),
          if (fat.recomendaciones.isNotEmpty)
            _bloqueLargo('Recomendaciones técnicas:', fat.recomendaciones),
          if (fat.observaciones.isNotEmpty)
            _bloqueLargo('Observaciones:', fat.observaciones),
        ],
      );

  // ── 6. Próxima visita ─────────────────────────────────────────────────────
  static pw.Widget _buildProximaVisita(Fat fat) => _seccion(
        '6. Próxima visita',
        [
          pw.Row(children: [
            pw.Expanded(
                child: _kv('Fecha próxima visita:',
                    DateFormat('dd/MM/yyyy').format(fat.proximaVisita))),
            if (fat.proximaVisitaTema.isNotEmpty)
              pw.Expanded(
                  child: _kv('Tema próxima visita:',
                      CatalogData.labelFromIdTema(fat.proximaVisitaTema))),
          ]),
        ],
      );

  // ── Firmas ─────────────────────────────────────────────────────────────────
  static pw.Widget _buildFirmas(Fat fat, Uint8List? firmaBytes) =>
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          // Técnico (línea vacía)
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(height: 50),
                pw.Divider(color: PdfColors.black),
                pw.SizedBox(height: 3),
                pw.Text(fat.nombreTecnico,
                    style: const pw.TextStyle(fontSize: 8),
                    textAlign: pw.TextAlign.center),
                pw.Text('TÉCNICO / EXTENSIONISTA',
                    style: pw.TextStyle(
                        fontSize: 7, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center),
              ],
            ),
          ),
          pw.SizedBox(width: 40),
          // Productor (firma digital si existe)
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (firmaBytes != null)
                  pw.Container(
                    height: 50,
                    child: pw.Image(pw.MemoryImage(firmaBytes),
                        fit: pw.BoxFit.contain),
                  )
                else
                  pw.Container(height: 50),
                pw.Divider(color: PdfColors.black),
                pw.SizedBox(height: 3),
                pw.Text('PRODUCTOR / REPRESENTANTE',
                    style: pw.TextStyle(
                        fontSize: 7, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center),
                pw.Text('(firma del beneficiario)',
                    style: const pw.TextStyle(
                        fontSize: 7, color: PdfColors.grey600),
                    textAlign: pw.TextAlign.center),
              ],
            ),
          ),
        ],
      );

  // ── Panel fotográfico ──────────────────────────────────────────────────────
  static pw.Widget _buildPanelFotos(
    Fat fat,
    Uint8List? foto1,
    Uint8List? foto2,
    Uint8List? foto3,
  ) {
    final items = [
      if (foto1 != null) _PdfFoto(foto1, 'Inicio', fat.foto1Descripcion),
      if (foto2 != null) _PdfFoto(foto2, 'Desarrollo', fat.foto2Descripcion),
      if (foto3 != null) _PdfFoto(foto3, 'Cierre', fat.foto3Descripcion),
    ];
    if (items.isEmpty) return pw.SizedBox.shrink();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: const pw.BoxDecoration(
            color: _verde,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text('ANEXO 1. Panel fotográfico',
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white)),
        ),
        pw.SizedBox(height: 6),
        if ((fat.ubicacion ?? '').isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.RichText(
              text: pw.TextSpan(
                text: 'GPS: ',
                style:
                    pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                children: [
                  pw.TextSpan(
                    text:
                        '${fat.ubicacion}   ${fat.comunidad} · ${fat.distrito}',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey800),
                  ),
                ],
              ),
            ),
          ),
        pw.Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items
              .map((f) => pw.Container(
                    width: 168,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: _grisBorde, width: 0.5),
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.ClipRRect(
                          horizontalRadius: 4,
                          verticalRadius: 4,
                          child: pw.Image(pw.MemoryImage(f.bytes),
                              width: 168, height: 120, fit: pw.BoxFit.cover),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(f.titulo,
                                  style: pw.TextStyle(
                                      fontSize: 8,
                                      fontWeight: pw.FontWeight.bold)),
                              if (f.descripcion.isNotEmpty)
                                pw.Text(f.descripcion,
                                    style: const pw.TextStyle(
                                        fontSize: 7,
                                        color: PdfColors.grey700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  // ── Helpers de layout ──────────────────────────────────────────────────────
  static pw.Widget _seccion(String titulo, List<pw.Widget> hijos) =>
      pw.Container(
        width: double.infinity,
        decoration: pw.BoxDecoration(
          color: _grisClaro,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          border: pw.Border.all(color: _grisBorde, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: const pw.BoxDecoration(
                color: _verde,
                borderRadius: pw.BorderRadius.only(
                  topLeft: pw.Radius.circular(4),
                  topRight: pw.Radius.circular(4),
                ),
              ),
              child: pw.Text(titulo,
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: hijos),
            ),
          ],
        ),
      );

  static pw.Widget _kv(String label, String valor) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 115,
              child: pw.Text(label,
                  style: pw.TextStyle(
                      fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Expanded(
              child: pw.Text(valor.isEmpty ? '—' : valor,
                  style: const pw.TextStyle(fontSize: 8)),
            ),
          ],
        ),
      );

  static pw.Widget _bloqueLargo(String label, String valor) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 8, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(5),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                border: pw.Border.all(color: _grisBorde, width: 0.5),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
              child: pw.Text(valor,
                  style: const pw.TextStyle(fontSize: 8)),
            ),
          ],
        ),
      );

  static pw.Widget _celda(String text, {bool center = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(3),
        child: pw.Text(
          text,
          style: const pw.TextStyle(fontSize: 8),
          textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
        ),
      );

  // ── Cargar imagen como bytes (móvil: archivo, firma: base64) ──────────────
  static Future<Uint8List?> _loadImage(String? path) async {
    if (path == null || path.isEmpty) return null;
    if (kIsWeb) return null;

    // Firma en base64
    if (path.startsWith('data:image')) {
      try {
        return base64.decode(path.split(',').last);
      } catch (_) {
        return null;
      }
    }
    // Archivo local
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }
}

// ── Data class auxiliar ───────────────────────────────────────────────────────
class _PdfFoto {
  final Uint8List bytes;
  final String titulo;
  final String descripcion;
  const _PdfFoto(this.bytes, this.titulo, this.descripcion);
}
