import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';
import 'package:vertex_ai_pyme/domain/documentos.dart';
import 'package:vertex_ai_pyme/ui/pdf_factura.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_CO'));

  final doc = DocImprimible(
    titulo: 'Comprobante de venta',
    numero: '7F3A21C9',
    fecha: DateTime(2026, 11, 18, 10, 30),
    negocio: const PerfilNegocio(nombre: 'Tienda Doña Marta', nit: '1118000000'),
    cliente: 'Ana Pérez',
    lineas: const [
      LineaDoc('Arroz 500 g', 2, 2500),
      LineaDoc('Queso campesino', 0.75, 24000, 'kg'),
    ],
    total: 23000,
    notas: const ['Forma de pago: contado', '¡Gracias por su compra!'],
  );

  test('genera el PDF en tirilla de 80 mm y en carta (sin logo)', () async {
    final rollo = await pdfDocumento(doc, PdfPageFormat.roll80);
    final carta = await pdfDocumento(doc, PdfPageFormat.letter);
    expect(String.fromCharCodes(rollo.take(5)), '%PDF-');
    expect(String.fromCharCodes(carta.take(5)), '%PDF-');
    expect(carta.length, greaterThan(1000));
    expect(doc.archivo, 'comprobante_de_venta_7F3A21C9.pdf');
  });

  test('líneas por peso muestran la unidad', () {
    const l = LineaDoc('Queso campesino', 0.75, 24000, 'kg');
    expect(l.cantidadTexto, '0,75 kg');
    expect(l.total, 18000);
    expect(l.precioTexto, contains('/kg'));
  });
}
