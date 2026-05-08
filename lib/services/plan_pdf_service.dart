import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/plan_trabajo.dart';
import '../core/catalog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PLAN PDF SERVICE
//
// Genera un PDF general del Plan de Trabajo aprobado.
// Usa el paquete `pdf` + `printing` para previsualizar / compartir / imprimir.
//
// Plantilla general — se personalizará con la plantilla oficial cuando
// el usuario la proporcione.
// ─────────────────────────────────────────────────────────────────────────────
class PlanPdfService {
  static const _naranja = PdfColor.fromInt(0xFFE65100);
  static const _grisClaro = PdfColor.fromInt(0xFFF5F5F5);
  static const _grisBorde = PdfColor.fromInt(0xFFDDDDDD);

  // ── Muestra el PDF en pantalla (share/print/download) ─────────────────────
  static Future<void> mostrarPdf(
      BuildContext context, PlanTrabajo plan) async {
    final doc = await _buildPdf(plan);
    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: 'PlanTrabajo_${plan.mes}_${plan.nombreTecnico.replaceAll(' ', '_')}.pdf',
    );
  }

  // ── Construye el documento PDF ─────────────────────────────────────────────
  static Future<pw.Document> _buildPdf(PlanTrabajo plan) async {
    final doc = pw.Document();

    // Ordenar tareas por fecha
    final tareas = List<Tarea>.from(plan.tareas)
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (_) => _buildHeader(plan),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          _buildInfoGeneral(plan),
          pw.SizedBox(height: 14),
          _buildTablaTareas(tareas),
          pw.SizedBox(height: 14),
          _buildResumen(tareas),
          pw.SizedBox(height: 20),
          _buildFirmas(plan),
        ],
      ),
    );

    return doc;
  }

  // ── Encabezado ─────────────────────────────────────────────────────────────
  static pw.Widget _buildHeader(PlanTrabajo plan) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _naranja, width: 2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'PLAN DE TRABAJO MENSUAL',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: _naranja,
                ),
              ),
              pw.Text(
                '${CatalogData.nombreActividad} — ${plan.mes}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
          pw.Text(
            'Estado: ${plan.estado}',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green700,
            ),
          ),
        ],
      ),
    );
  }

  // ── Pie de página ──────────────────────────────────────────────────────────
  static pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _grisBorde)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            'Pág. ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  // ── Información general del plan ───────────────────────────────────────────
  static pw.Widget _buildInfoGeneral(PlanTrabajo plan) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _grisClaro,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: _grisBorde),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _fila('Técnico / Especialista:', plan.nombreTecnico),
          _fila('Coordinador:', plan.nombreCoordinador),
          _fila('Actividad:', plan.nombreActividad),
          _fila('Mes:', plan.mes),
          _fila('Fecha elaboración:',
              DateFormat('dd/MM/yyyy').format(plan.fechaCreacion)),
          _fila('N.° Tareas:', '${plan.tareas.length}'),
          if (plan.observaciones != null && plan.observaciones!.isNotEmpty)
            _fila('Observaciones previas:', plan.observaciones!),
        ],
      ),
    );
  }

  static pw.Widget _fila(String label, String valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 150,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(valor, style: const pw.TextStyle(fontSize: 9)),
          ),
        ],
      ),
    );
  }

  // ── Tabla de tareas ────────────────────────────────────────────────────────
  static pw.Widget _buildTablaTareas(List<Tarea> tareas) {
    const headers = ['Fecha', 'Horario', 'Tarea', 'Distrito', 'Comunidad', 'Socios'];
    const widths  = [0.10,    0.10,      0.25,    0.15,       0.20,        0.20];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'TAREAS PROGRAMADAS',
          style: pw.TextStyle(
              fontSize: 11, fontWeight: pw.FontWeight.bold, color: _naranja),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: _grisBorde, width: 0.5),
          columnWidths: {
            for (int i = 0; i < widths.length; i++)
              i: pw.FlexColumnWidth(widths[i] * 10),
          },
          children: [
            // Encabezado
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _naranja),
              children: headers
                  .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          h,
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ))
                  .toList(),
            ),
            // Filas
            ...tareas.asMap().entries.map((entry) {
              final i    = entry.key;
              final t    = entry.value;
              final bg   = i.isEven ? PdfColors.white : _grisClaro;
              final label = CatalogData.labelFromIdPta(t.idPta);
              final sociosText = t.sociosList.isEmpty
                  ? '—'
                  : t.sociosList.map((s) => s['nombre'] ?? '').join('\n');
              return pw.TableRow(
                decoration: pw.BoxDecoration(color: bg),
                children: [
                  _celda(DateFormat('dd/MM').format(t.fecha)),
                  _celda('${t.horaInicio}\n${t.horaFinal}'),
                  _celda(label, small: true),
                  _celda(t.distrito, small: true),
                  _celda(t.comunidad, small: true),
                  _celda(sociosText, small: true),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  static pw.Widget _celda(String text, {bool small = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: small ? 7 : 8),
      ),
    );
  }

  // ── Resumen por distrito ───────────────────────────────────────────────────
  static pw.Widget _buildResumen(List<Tarea> tareas) {
    final porDistrito = <String, int>{};
    for (final t in tareas) {
      porDistrito[t.distrito] = (porDistrito[t.distrito] ?? 0) + 1;
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'RESUMEN POR DISTRITO',
          style: pw.TextStyle(
              fontSize: 11, fontWeight: pw.FontWeight.bold, color: _naranja),
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          children: porDistrito.entries
              .map((e) => pw.Expanded(
                    child: pw.Container(
                      margin: const pw.EdgeInsets.only(right: 6),
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: _grisClaro,
                        border: pw.Border.all(color: _grisBorde),
                        borderRadius: const pw.BorderRadius.all(
                            pw.Radius.circular(4)),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            '${e.value}',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: _naranja,
                            ),
                          ),
                          pw.Text(e.key,
                              style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  // ── Firmas ─────────────────────────────────────────────────────────────────
  static pw.Widget _buildFirmas(PlanTrabajo plan) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: [
        _bloquesFirma('TÉCNICO / ESPECIALISTA', plan.nombreTecnico),
        _bloquesFirma('COORDINADOR', plan.nombreCoordinador),
      ],
    );
  }

  static pw.Widget _bloquesFirma(String titulo, String nombre) {
    return pw.Column(
      children: [
        pw.Container(width: 150, height: 50),
        pw.Container(width: 150, height: 1,
            decoration: const pw.BoxDecoration(color: PdfColors.black)),
        pw.SizedBox(height: 4),
        pw.Text(nombre, style: const pw.TextStyle(fontSize: 8)),
        pw.Text(titulo,
            style: pw.TextStyle(
                fontSize: 7, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }
}
