import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../domain/documentos.dart';
import 'archivo.dart';
import 'pdf_factura.dart' show cargarLogo;

/// PDF de varias páginas en tamaño carta para documentos "de oficina":
/// cuenta de cobro, informes semanal/quincenal/mensual y libro de
/// movimientos para el contador. Se arma con bloques (secciones,
/// indicadores, tablas, barras y párrafos) y lleva el logo del negocio,
/// el número del documento y el número de página.

sealed class Bloque {
  const Bloque();
}

class Seccion extends Bloque {
  final String titulo;
  const Seccion(this.titulo);
}

class Indicador {
  final String etiqueta;
  final String valor;
  final String nota;
  const Indicador(this.etiqueta, this.valor, [this.nota = '']);
}

/// Fila de tarjetas con cifras clave.
class Indicadores extends Bloque {
  final List<Indicador> items;
  const Indicadores(this.items);
}

class Tabla extends Bloque {
  final List<String> encabezados;
  final List<List<String>> filas;

  /// Columnas alineadas a la derecha (cifras).
  final Set<int> derecha;

  /// Fila de totales (opcional).
  final List<String>? pie;
  final String vacia;
  const Tabla(this.encabezados, this.filas,
      {this.derecha = const {},
      this.pie,
      this.vacia = 'Sin datos en este periodo.'});
}

/// Barras horizontales simples (p. ej. ventas por día).
class Barras extends Bloque {
  final List<(String etiqueta, double valor, String texto)> datos;
  const Barras(this.datos);
}

class Parrafo extends Bloque {
  final String texto;
  final bool destacado;
  const Parrafo(this.texto, {this.destacado = false});
}

class Reporte {
  final String titulo;
  final String numero;
  final DateTime fecha;
  final PerfilNegocio negocio;

  /// Línea bajo el título (p. ej. el periodo o el cliente).
  final List<String> subtitulo;
  final List<Bloque> bloques;
  const Reporte({
    required this.titulo,
    required this.numero,
    required this.fecha,
    required this.negocio,
    required this.bloques,
    this.subtitulo = const [],
  });

  PdfListo get pdf =>
      PdfListo(nombre: nombreArchivo(numero), generar: (_) => pdfReporte(this));
}

const _verde = PdfColor.fromInt(0xFF1C7A43);
const _verdeClaro = PdfColor.fromInt(0xFFDDF3E5);
const _linea = PdfColor.fromInt(0xFFD3DDD6);
const _gris = PdfColor.fromInt(0xFF5B6660);

Future<Uint8List> pdfReporte(Reporte r) async {
  final logo = await cargarLogo(r.negocio.logo);
  final n = r.negocio;
  final fmt = DateFormat('d/MM/y h:mm a', 'es_CO');
  final datos = [
    if (n.nit.trim().isNotEmpty) 'NIT/C.C. ${n.nit.trim()}',
    if (n.direccion.trim().isNotEmpty) n.direccion.trim(),
    if (n.telefono.trim().isNotEmpty) 'Tel. ${n.telefono.trim()}',
  ];
  const base = 9.5;
  const estilo = pw.TextStyle(fontSize: base);
  final negrita =
      const pw.TextStyle(fontSize: base, fontWeight: pw.FontWeight.bold);
  final doc =
      pw.Document(title: '${r.titulo} ${r.numero}', author: n.nombreVisible);

  pw.Widget encabezado() => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        margin: const pw.EdgeInsets.only(bottom: 10),
        decoration: const pw.BoxDecoration(
            border:
                pw.Border(bottom: pw.BorderSide(color: _verde, width: 1.5))),
        child:
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          if (logo != null)
            pw.Container(
                width: 56,
                height: 56,
                margin: const pw.EdgeInsets.only(right: 10),
                child: pw.Image(logo, fit: pw.BoxFit.contain)),
          pw.Expanded(
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(n.nombreVisible,
                      style: const pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  for (final x in datos) pw.Text(x, style: estilo),
                ]),
          ),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(r.titulo.toUpperCase(),
                style: const pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: _verde)),
            pw.Text('N.º ${r.numero}', style: negrita),
            pw.Text('Emitido: ${fmt.format(r.fecha)}', style: estilo),
            for (final s in r.subtitulo) pw.Text(s, style: estilo),
          ]),
        ]),
      );

  pw.Widget indicadores(Indicadores b) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Wrap(spacing: 6, runSpacing: 6, children: [
          for (final i in b.items)
            pw.Container(
              width: 124,
              padding: const pw.EdgeInsets.all(7),
              decoration: pw.BoxDecoration(
                  color: _verdeClaro,
                  borderRadius: pw.BorderRadius.circular(5)),
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(i.etiqueta,
                        style: const pw.TextStyle(fontSize: 8, color: _gris)),
                    pw.Text(i.valor,
                        style: const pw.TextStyle(
                            fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    if (i.nota.isNotEmpty)
                      pw.Text(i.nota,
                          style:
                              const pw.TextStyle(fontSize: 7.5, color: _gris)),
                  ]),
            ),
        ]),
      );

  pw.Widget tabla(Tabla t) {
    if (t.filas.isEmpty) {
      return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Text(t.vacia,
              style: const pw.TextStyle(fontSize: base, color: _gris)));
    }
    final alin = {
      for (var i = 0; i < t.encabezados.length; i++)
        i: t.derecha.contains(i)
            ? pw.Alignment.centerRight
            : pw.Alignment.centerLeft
    };
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.TableHelper.fromTextArray(
        headers: t.encabezados,
        data: [...t.filas, if (t.pie != null) t.pie!],
        headerStyle:
            const pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 8.5),
        headerDecoration: const pw.BoxDecoration(color: _verdeClaro),
        cellAlignments: alin,
        headerAlignments: alin,
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        border: const pw.TableBorder(
            horizontalInside: pw.BorderSide(color: _linea, width: .5),
            bottom: pw.BorderSide(color: _linea, width: .5)),
        rowDecoration: const pw.BoxDecoration(),
      ),
    );
  }

  pw.Widget barras(Barras b) {
    final max = b.datos.fold<double>(0, (m, x) => x.$2 > m ? x.$2 : m);
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(children: [
        for (final (etq, v, txt) in b.datos)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 1.2),
            child: pw.Row(children: [
              pw.SizedBox(
                  width: 62,
                  child: pw.Text(etq, style: const pw.TextStyle(fontSize: 8))),
              pw.Expanded(
                child: pw.LayoutBuilder(
                  builder: (ctx, c) => pw.Row(children: [
                    pw.Container(
                        width: max <= 0 ? 0 : (c!.maxWidth - 70) * (v / max),
                        height: 8,
                        color: _verde),
                    pw.SizedBox(width: 4),
                    pw.Text(txt, style: const pw.TextStyle(fontSize: 8)),
                  ]),
                ),
              ),
            ]),
          ),
      ]),
    );
  }

  pw.Widget bloque(Bloque b) => switch (b) {
        Seccion(:final titulo) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 6, bottom: 4),
            child: pw.Text(titulo,
                style: const pw.TextStyle(
                    fontSize: 11.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _verde))),
        Indicadores() => indicadores(b),
        Tabla() => tabla(b),
        Barras() => barras(b),
        Parrafo(:final texto, :final destacado) => pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 6),
            padding:
                destacado ? const pw.EdgeInsets.all(7) : pw.EdgeInsets.zero,
            decoration: destacado
                ? pw.BoxDecoration(
                    border: pw.Border.all(color: _verde, width: .8),
                    borderRadius: pw.BorderRadius.circular(5))
                : null,
            child: pw.Text(texto, style: destacado ? negrita : estilo)),
      };

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.letter.applyMargin(
        left: 16 * PdfPageFormat.mm,
        right: 16 * PdfPageFormat.mm,
        top: 14 * PdfPageFormat.mm,
        bottom: 14 * PdfPageFormat.mm),
    header: (ctx) => ctx.pageNumber == 1
        ? encabezado()
        : pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Text('${n.nombreVisible} - ${r.titulo} N.º ${r.numero}',
                style: const pw.TextStyle(fontSize: 8, color: _gris))),
    footer: (ctx) => pw.Row(children: [
      pw.Expanded(
        child: pw.Text(
            'Generado con VERTEX AI Pyme. Documento de control interno; '
            'no es factura electrónica DIAN.',
            style: const pw.TextStyle(fontSize: 7.5, color: _gris)),
      ),
      pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 7.5, color: _gris)),
    ]),
    build: (_) => [for (final b in r.bloques) bloque(b)],
  ));
  return doc.save();
}
