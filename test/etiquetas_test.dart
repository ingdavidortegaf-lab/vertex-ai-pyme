import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vertex_ai_pyme/domain/resumen.dart';
import 'package:vertex_ai_pyme/pdf/pdf_etiquetas.dart';

/// Etiquetas de precio y lista de precios en PDF.
void main() {
  setUpAll(() => initializeDateFormatting('es_CO'));

  test('el código de barras se elige según el código del producto', () {
    expect(tipoBarras('7702004003508'), TipoBarras.ean13);
    expect(tipoBarras('7702004003509'), TipoBarras.code128); // control EAN inválido: va en 128
    expect(tipoBarras('T-14'), TipoBarras.code128);
    expect(tipoBarras(''), TipoBarras.ninguno);
    expect(tipoBarras('ñandú'), TipoBarras.ninguno);
  });

  const productos = [
    ProductoStock(id: 'a', nombre: 'Cemento gris 50 kg', precio: 34000, costo: 29500, codigo: '7702004003508',
        precioMayor: 32500, cantidadMayor: 10),
    ProductoStock(id: 'b', nombre: 'Cable 12', precio: 4200, costo: 3000, unidad: 'm', codigo: 'CAB-12'),
    ProductoStock(id: 'c', nombre: 'Arroz 500 g', precio: 2500, costo: 1800),
  ];

  test('etiquetas: un PDF con una hoja por cada 24 etiquetas', () async {
    final una = await pdfEtiquetas(productos, negocio: 'Ferremercado');
    expect(latin1.decode(una.sublist(0, 5)), '%PDF-');
    final muchas = await pdfEtiquetas(productos, copias: 10, negocio: 'Ferremercado');
    // 30 etiquetas → 2 hojas.
    expect(RegExp(r'/Type\s*/Page[^s]').allMatches(latin1.decode(muchas)).length, 2);
  });

  test('lista de precios: PDF sin costos', () async {
    final b = await pdfListaPrecios(productos, negocio: 'Ferremercado', fecha: DateTime(2026, 11, 25));
    expect(latin1.decode(b.sublist(0, 5)), '%PDF-');
    expect(b.length, greaterThan(1000));
  });
}
