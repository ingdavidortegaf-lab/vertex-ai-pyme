import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../domain/documentos.dart';
import '../domain/formato.dart';
import 'archivo.dart';

/// Datos de un documento imprimible (comprobante de venta o cotización).
class DocImprimible {
  final String titulo;
  final String numero;
  final DateTime fecha;
  final PerfilNegocio negocio;
  final String? cliente;
  final List<LineaDoc> lineas;
  final double total;
  final List<String> notas;

  /// «Cliente», o «Proveedor» en un pedido.
  final String etiquetaCliente;

  /// Encabezado de la columna de precio («Precio» o «Costo aprox.»).
  final String etiquetaPrecio;
  const DocImprimible({
    required this.titulo,
    required this.numero,
    required this.fecha,
    required this.negocio,
    required this.lineas,
    required this.total,
    this.cliente,
    this.notas = const [],
    this.etiquetaCliente = 'Cliente',
    this.etiquetaPrecio = 'Precio',
  });

  String get archivo =>
      '${titulo.toLowerCase().replaceAll(' ', '_')}_$numero.pdf';
}

/// Logo del negocio para los PDF (null si no hay o no se puede leer).
Future<pw.MemoryImage?> cargarLogo(String ruta) async {
  if (ruta.isEmpty) return null;
  final guardado = bytesDeLogo(ruta);
  if (guardado != null) return pw.MemoryImage(guardado);
  if (kIsWeb) return null;
  try {
    final f = File(ruta);
    if (!await f.exists()) return null;
    return pw.MemoryImage(await f.readAsBytes());
  } catch (_) {
    return null;
  }
}

/// Genera el PDF. Si el papel es angosto (impresora térmica de 58 u 80 mm)
/// usa el formato de tirilla; si no, formato carta/A4.
Future<Uint8List> pdfDocumento(DocImprimible d, PdfPageFormat formato) async {
  final logo = await cargarLogo(d.negocio.logo);
  final rollo = formato.width < 120 * PdfPageFormat.mm;
  final fmt = DateFormat('d/MM/y h:mm a', 'es_CO');
  final n = d.negocio;
  final datos = [
    if (n.nit.trim().isNotEmpty) 'NIT/C.C. ${n.nit.trim()}',
    if (n.direccion.trim().isNotEmpty) n.direccion.trim(),
    if (n.telefono.trim().isNotEmpty) 'Tel. ${n.telefono.trim()}',
  ];
  final doc = pw.Document(title: '${d.titulo} ${d.numero}', author: n.nombreVisible);
  final base = rollo ? 8.0 : 10.0;
  final estilo = pw.TextStyle(fontSize: base);
  final negrita = pw.TextStyle(fontSize: base, fontWeight: pw.FontWeight.bold);

  pw.Widget encabezado() => pw.Column(
        crossAxisAlignment:
            rollo ? pw.CrossAxisAlignment.center : pw.CrossAxisAlignment.start,
        children: [
          if (logo != null)
            pw.Container(
                height: rollo ? 40 : 56,
                margin: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Image(logo, fit: pw.BoxFit.contain)),
          pw.Text(n.nombreVisible,
              style: pw.TextStyle(fontSize: base + 4, fontWeight: pw.FontWeight.bold),
              textAlign: rollo ? pw.TextAlign.center : pw.TextAlign.left),
          for (final x in datos)
            pw.Text(x, style: estilo, textAlign: rollo ? pw.TextAlign.center : pw.TextAlign.left),
        ],
      );

  pw.Widget tabla() {
    if (rollo) {
      return pw.Column(children: [
        for (final l in d.lineas)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(l.nombre, style: negrita),
              pw.Row(children: [
                pw.Expanded(child: pw.Text('${l.cantidadTexto} x ${l.precioTexto}', style: estilo)),
                pw.Text(cop(l.total), style: estilo),
              ]),
            ]),
          ),
      ]);
    }
    return pw.TableHelper.fromTextArray(
      headers: ['Descripción', 'Cantidad', d.etiquetaPrecio, 'Total'],
      data: [
        for (final l in d.lineas) [l.nombre, l.cantidadTexto, l.precioTexto, cop(l.total)]
      ],
      headerStyle: negrita,
      cellStyle: estilo,
      headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFDDF3E5)),
      cellAlignments: {
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      border: const pw.TableBorder(
          horizontalInside: pw.BorderSide(color: PdfColor.fromInt(0xFFD3DDD6), width: .5)),
    );
  }

  doc.addPage(pw.Page(
    pageFormat: rollo
        ? formato.copyWith(
            marginLeft: 4 * PdfPageFormat.mm,
            marginRight: 4 * PdfPageFormat.mm,
            marginTop: 4 * PdfPageFormat.mm,
            marginBottom: 6 * PdfPageFormat.mm)
        : formato.applyMargin(
            left: 18 * PdfPageFormat.mm,
            right: 18 * PdfPageFormat.mm,
            top: 16 * PdfPageFormat.mm,
            bottom: 16 * PdfPageFormat.mm),
    build: (_) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        rollo
            ? encabezado()
            : pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Expanded(child: encabezado()),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text(d.titulo.toUpperCase(),
                      style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('N.º ${d.numero}', style: negrita),
                  pw.Text(fmt.format(d.fecha), style: estilo),
                ]),
              ]),
        pw.SizedBox(height: 8),
        if (rollo) ...[
          pw.Divider(thickness: .5),
          pw.Text('${d.titulo} N.º ${d.numero}', style: negrita, textAlign: pw.TextAlign.center),
          pw.Text(fmt.format(d.fecha), style: estilo, textAlign: pw.TextAlign.center),
        ],
        if (d.cliente != null && d.cliente!.trim().isNotEmpty)
          pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text('${d.etiquetaCliente}: ${d.cliente}', style: estilo)),
        pw.SizedBox(height: 6),
        pw.Divider(thickness: .5),
        tabla(),
        pw.Divider(thickness: .5),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Text('TOTAL  ${cop(d.total)}',
              style: pw.TextStyle(fontSize: base + 4, fontWeight: pw.FontWeight.bold)),
        ]),
        pw.SizedBox(height: 8),
        for (final x in d.notas)
          pw.Text(x, style: estilo, textAlign: rollo ? pw.TextAlign.center : pw.TextAlign.left),
        pw.SizedBox(height: 6),
        pw.Text('Documento generado con VERTEX AI Pyme. No es factura electrónica DIAN.',
            style: pw.TextStyle(fontSize: base - 1, color: PdfColors.grey700),
            textAlign: rollo ? pw.TextAlign.center : pw.TextAlign.left),
      ],
    ),
  ));
  return doc.save();
}

/// Abre el diálogo de impresión del sistema (impresora, Wi-Fi, Bluetooth o
/// «Guardar como PDF»).
Future<void> imprimirDocumento(DocImprimible d) => Printing.layoutPdf(
      name: d.archivo,
      format: PdfPageFormat.roll80,
      onLayout: (f) => pdfDocumento(d, f),
    );

/// Comparte el PDF (WhatsApp, correo, Drive…).
Future<void> compartirPdf(DocImprimible d, {bool carta = true}) async => Printing.sharePdf(
      bytes: await pdfDocumento(d, carta ? PdfPageFormat.letter : PdfPageFormat.roll80),
      filename: d.archivo,
    );

/// El documento listo para imprimir (tirilla de 80 mm por defecto),
/// compartir o archivar (carta).
PdfListo pdfListo(DocImprimible d, {bool tirilla = true}) => PdfListo(
      nombre: nombreArchivo(d.numero),
      generar: (f) => pdfDocumento(d, f),
      papelImpresion: tirilla ? PdfPageFormat.roll80 : PdfPageFormat.letter,
    );
