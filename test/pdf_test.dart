import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';
import 'package:vertex_ai_pyme/domain/documentos.dart';
import 'package:vertex_ai_pyme/domain/facturacion.dart';
import 'package:vertex_ai_pyme/pdf/pdf_factura.dart';

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

  DocImprimible conFactura(EstadoFE estado, {String? cufe}) => DocImprimible(
        titulo: 'Factura electrónica de venta',
        numero: 'PRU1',
        fecha: doc.fecha,
        negocio: doc.negocio,
        lineas: doc.lineas,
        total: doc.total,
        fe: FacturaEmitida(
            id: 'f1',
            ventaId: 'v1',
            numero: 'PRU1',
            estado: estado,
            cufe: cufe,
            qr: cufe == null ? null : 'https://qr.prueba/$cufe',
            creado: doc.fecha),
      );

  test('solo con la DIAN aceptando (y CUFE) es factura electrónica, con QR en el PDF', () async {
    final aceptada = conFactura(EstadoFE.aceptado, cufe: 'CUFE-DE-PRUEBA');
    expect(aceptada.esFacturaElectronica, isTrue);
    expect(conFactura(EstadoFE.pendiente).esFacturaElectronica, isFalse);
    expect(conFactura(EstadoFE.aceptado).esFacturaElectronica, isFalse, reason: 'sin CUFE no cuenta');
    expect(doc.esFacturaElectronica, isFalse);
    final conQr = await pdfDocumento(aceptada, PdfPageFormat.letter);
    final sinQr = await pdfDocumento(conFactura(EstadoFE.enviado), PdfPageFormat.letter);
    expect(String.fromCharCodes(conQr.take(5)), '%PDF-');
    expect(conQr.length, greaterThan(sinQr.length), reason: 'lleva el código QR');
    await pdfDocumento(aceptada, PdfPageFormat.roll80);
  });

  test('el texto de WhatsApp dice «no es factura electrónica» salvo si la DIAN la aceptó', () {
    String texto({({String numero, String cufe})? fe}) => textoComprobante(
        negocio: doc.negocio,
        ventaId: 'abc12345-0000',
        fecha: doc.fecha,
        lineas: doc.lineas,
        total: doc.total,
        facturaElectronica: fe);
    expect(texto(), contains('no es factura electrónica'));
    final f = texto(fe: (numero: 'PRU1', cufe: 'CUFE-DE-PRUEBA'));
    expect(f, isNot(contains('no es factura electrónica')));
    expect(f, contains('Factura electrónica de venta N.º PRU1'));
    expect(f, contains('CUFE: CUFE-DE-PRUEBA'));
  });

  test('líneas por peso muestran la unidad', () {
    const l = LineaDoc('Queso campesino', 0.75, 24000, 'kg');
    expect(l.cantidadTexto, '0,75 kg');
    expect(l.total, 18000);
    expect(l.precioTexto, contains('/kg'));
  });
}
