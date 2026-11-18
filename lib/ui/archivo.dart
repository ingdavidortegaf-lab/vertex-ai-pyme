import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../data/local_db.dart';

/// Archivo de documentos en el mismo equipo.
///
/// Cada documento que la app emite (comprobante, cotización, cuenta de
/// cobro, pedido, informe) recibe un número único en la base del celular y
/// su PDF se guarda en la carpeta «VERTEX_documentos»:
/// - En el PC (Windows): Documentos\VERTEX_documentos (el contador la ve).
/// - En el celular: la carpeta privada de la app (se comparte con el botón PDF).

/// Un PDF listo para imprimir, compartir o archivar.
class PdfListo {
  /// Nombre del archivo, p. ej. «CC-A3F1-000004.pdf».
  final String nombre;

  /// Genera el PDF para un tamaño de papel.
  final Future<Uint8List> Function(PdfPageFormat formato) generar;

  /// Papel por defecto al imprimir (tirilla de 80 mm o carta).
  final PdfPageFormat papelImpresion;

  /// Papel del PDF para compartir y archivar.
  final PdfPageFormat papelArchivo;
  const PdfListo({
    required this.nombre,
    required this.generar,
    this.papelImpresion = PdfPageFormat.letter,
    this.papelArchivo = PdfPageFormat.letter,
  });

  Future<void> imprimir() => Printing.layoutPdf(
      name: nombre, format: papelImpresion, onLayout: (f) => generar(f));

  Future<void> compartir() async =>
      Printing.sharePdf(bytes: await generar(papelArchivo), filename: nombre);
}

Future<Directory> carpetaDocumentos() async {
  final base = await getApplicationDocumentsDirectory();
  final d = Directory(p.join(base.path, 'VERTEX_documentos'));
  if (!await d.exists()) await d.create(recursive: true);
  return d;
}

/// Nombre de archivo seguro a partir del número del documento.
String nombreArchivo(String numero) =>
    '${numero.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.pdf';

/// Genera el PDF, lo guarda en la carpeta de documentos y anota la ruta en
/// el archivo de la base. Si algo falla (por ejemplo, sin espacio), el
/// documento sigue emitido y se puede volver a generar: devuelve null.
Future<String?> archivarDocumento(
    Map<String, Object?> documento, PdfListo pdf) async {
  try {
    final dir = await carpetaDocumentos();
    final ruta = p.join(dir.path, nombreArchivo(documento['numero'] as String));
    await File(ruta)
        .writeAsBytes(await pdf.generar(pdf.papelArchivo), flush: true);
    await LocalDb.instance.archivarPdf(documento['id'] as String, ruta);
    return ruta;
  } catch (_) {
    return null;
  }
}

/// Lee un PDF archivado (null si ya no está en este equipo).
Future<Uint8List?> leerArchivado(String? ruta) async {
  if (ruta == null || ruta.isEmpty) return null;
  try {
    final f = File(ruta);
    return await f.exists() ? await f.readAsBytes() : null;
  } catch (_) {
    return null;
  }
}
