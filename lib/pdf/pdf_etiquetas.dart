import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../domain/codigos.dart';
import '../domain/formato.dart';
import '../domain/resumen.dart';

/// Etiquetas de precio para góndola o para pegar en el producto, y la lista
/// de precios para enviar a los clientes. Sin costos: solo lo que el cliente
/// puede ver.

/// Qué código de barras se imprime: EAN-13 si el código lo es (los de
/// supermercado), Code 128 para cualquier otro código interno, o ninguno.
enum TipoBarras { ean13, code128, ninguno }

TipoBarras tipoBarras(String codigo) {
  final c = normalizarCodigo(codigo);
  if (c.isEmpty) return TipoBarras.ninguno;
  if (RegExp(r'^\d{13}$').hasMatch(c) && controlEanValido(c)) return TipoBarras.ean13;
  // Code 128 imprime letras, números y signos comunes.
  if (RegExp(r'^[\x20-\x7E]{1,30}$').hasMatch(c)) return TipoBarras.code128;
  return TipoBarras.ninguno;
}

pw.Widget? _barras(String codigo, {double alto = 28}) => switch (tipoBarras(codigo)) {
      TipoBarras.ean13 => pw.BarcodeWidget(
          barcode: pw.Barcode.ean13(), data: normalizarCodigo(codigo), height: alto, textStyle: const pw.TextStyle(fontSize: 7)),
      TipoBarras.code128 => pw.BarcodeWidget(
          barcode: pw.Barcode.code128(), data: normalizarCodigo(codigo), height: alto, textStyle: const pw.TextStyle(fontSize: 7)),
      TipoBarras.ninguno => null,
    };

/// Hoja carta con 3 × 8 etiquetas (como las hojas adhesivas comunes). Cada
/// producto se repite [copias] veces.
Future<Uint8List> pdfEtiquetas(List<ProductoStock> productos,
    {int copias = 1, String negocio = '', PdfPageFormat formato = PdfPageFormat.letter}) async {
  final doc = pw.Document(title: 'Etiquetas de precio', author: negocio);
  final todas = [for (final p in productos) for (var i = 0; i < copias.clamp(1, 50); i++) p];
  const porHoja = 24;
  for (var inicio = 0; inicio < todas.length; inicio += porHoja) {
    final hoja = todas.skip(inicio).take(porHoja).toList();
    doc.addPage(pw.Page(
      pageFormat: formato,
      margin: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 36),
      build: (_) => pw.GridView(
        crossAxisCount: 3,
        childAspectRatio: 0.53,
        crossAxisSpacing: 8,
        mainAxisSpacing: 6,
        children: [for (final p in hoja) _etiqueta(p, negocio)],
      ),
    ));
  }
  if (todas.isEmpty) doc.addPage(pw.Page(build: (_) => pw.Text('Sin productos')));
  return doc.save();
}

pw.Widget _etiqueta(ProductoStock p, String negocio) {
  final barras = _barras(p.codigo, alto: 22);
  return pw.Container(
    padding: const pw.EdgeInsets.all(6),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey500, width: 0.6),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(p.nombre, maxLines: 2, style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
      pw.Spacer(),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Text(cop(p.precio), style: const pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold)),
        if (p.unidad != 'und' && p.unidad != 'serv')
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 3, bottom: 2),
            child: pw.Text('/${p.unidad}', style: const pw.TextStyle(fontSize: 9)),
          ),
      ]),
      if (p.tienePrecioMayor)
        pw.Text('Desde ${cantidadConUnidad(p.cantidadMayor, p.unidad)}: ${cop(p.precioMayor)}',
            style: const pw.TextStyle(fontSize: 7)),
      if (barras != null) ...[pw.SizedBox(height: 3), barras],
      if (negocio.isNotEmpty)
        pw.Text(negocio, maxLines: 1, style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
    ]),
  );
}

/// Lista de precios para enviar a los clientes (sin costos ni stock).
Future<Uint8List> pdfListaPrecios(List<ProductoStock> productos,
    {String negocio = '', String contacto = '', DateTime? fecha, PdfPageFormat formato = PdfPageFormat.letter}) async {
  final doc = pw.Document(title: 'Lista de precios', author: negocio);
  final hoy = DateFormat("d 'de' MMMM 'de' y", 'es_CO').format(fecha ?? DateTime.now());
  final hayMayor = productos.any((p) => p.tienePrecioMayor);
  doc.addPage(pw.MultiPage(
    pageFormat: formato,
    margin: const pw.EdgeInsets.all(32),
    header: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(negocio.isEmpty ? 'Lista de precios' : negocio,
          style: const pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.Text('Lista de precios · $hoy${contacto.isEmpty ? '' : ' · $contacto'}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
      pw.SizedBox(height: 10),
    ]),
    footer: (c) => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('Página ${c.pageNumber} de ${c.pagesCount} · Precios sujetos a cambio sin previo aviso',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
    ),
    build: (_) => [
      pw.TableHelper.fromTextArray(
        headers: ['Código', 'Producto', 'Unidad', 'Precio', if (hayMayor) 'Por mayor'],
        data: [
          for (final p in productos)
            [
              p.codigo,
              p.nombre,
              nombresUnidad[p.unidad] ?? p.unidad,
              cop(p.precio),
              if (hayMayor)
                p.tienePrecioMayor ? '${cop(p.precioMayor)} desde ${cantidadConUnidad(p.cantidadMayor, p.unidad)}' : '',
            ],
        ],
        headerStyle: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF17362C)),
        cellStyle: const pw.TextStyle(fontSize: 9),
        oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF4F7F3)),
        cellAlignments: {3: pw.Alignment.centerRight, 4: pw.Alignment.centerRight},
        columnWidths: {
          0: const pw.FlexColumnWidth(2),
          1: const pw.FlexColumnWidth(5),
          2: const pw.FlexColumnWidth(1.6),
          3: const pw.FlexColumnWidth(1.8),
          if (hayMayor) 4: const pw.FlexColumnWidth(2.8),
        },
      ),
    ],
  ));
  return doc.save();
}
