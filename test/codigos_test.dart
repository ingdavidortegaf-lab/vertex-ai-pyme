import 'package:flutter_test/flutter_test.dart';
import 'package:vertex_ai_pyme/domain/codigos.dart';
import 'package:vertex_ai_pyme/domain/conflictos.dart';
import 'package:vertex_ai_pyme/domain/resumen.dart';
import 'soporte.dart';

/// Arma una etiqueta EAN-13 de gramera válida: 20 + PLU + gramos + control.
String etiqueta(String plu, int gramos) {
  final cuerpo = '20$plu${gramos.toString().padLeft(5, '0')}';
  var suma = 0;
  for (var i = 0; i < 12; i++) {
    final d = int.parse(cuerpo[11 - i]);
    suma += i.isEven ? d * 3 : d;
  }
  return '$cuerpo${(10 - suma % 10) % 10}';
}

void main() {
  const productos = [
    ProductoStock(id: 'a', nombre: 'Arroz 500 g', codigo: '7702001041244'),
    ProductoStock(id: 'q', nombre: 'Queso campesino', codigo: '00123', unidad: 'kg'),
    ProductoStock(id: 'c', nombre: 'Carne molida', codigo: '456', unidad: 'lb'),
  ];

  test('dígito de control EAN', () {
    expect(controlEanValido('7702001041244'), isTrue);
    expect(controlEanValido('7702001041245'), isFalse);
    expect(controlEanValido(etiqueta('00123', 750)), isTrue);
  });

  test('código exacto de producto empacado', () {
    final r = buscarPorCodigo(productos, ' 7702001041244 ');
    expect(r!.producto.id, 'a');
    expect(r.cantidad, isNull);
  });

  test('etiqueta de gramera: producto y peso', () {
    final r = buscarPorCodigo(productos, etiqueta('00123', 750));
    expect(r!.producto.id, 'q');
    expect(r.cantidad, 0.75);
    final lb = buscarPorCodigo(productos, etiqueta('00456', 907));
    expect(lb!.producto.id, 'c');
    expect(lb.cantidad, closeTo(2.0, 0.001));
    expect(buscarPorCodigo(productos, etiqueta('99999', 500)), isNull);
    expect(leerEtiquetaBalanza('2000123007500'), isNull); // control errado
  });

  test('cantidad con unidad', () {
    expect(cantidadConUnidad(3, 'und'), '3');
    expect(cantidadConUnidad(0.75, 'kg'), '0,75 kg');
    expect(cantidadConUnidad(1.5, 'lb'), '1,5 lb');
  });

  test('producto de versión anterior (sin código ni unidad) se lee y se une', () {
    final viejo = ProductoCampos.fromRemote({
      'id': 'x',
      'nombre': 'Sal',
      'precio': 1000,
      'costo': 800,
      'minimo': 2,
      'deleted': false,
      for (final c in ['nombre', 'precio', 'costo', 'minimo', 'deleted'])
        '${c}_ts': '2026-11-16T10:00:00.000Z',
    });
    expect(viejo.codigo, '');
    expect(viejo.unidad, 'und');
    final nuevo = ProductoCampos('x', {...viejo.valores, 'codigo': '123'},
        {...viejo.ts, 'codigo': DateTime.utc(2026, 11, 17)});
    expect(viejo.merge(nuevo).codigo, '123');
  });

  test('guardar producto por peso con código y venderlo por kilos', () async {
    final db = await baseDePrueba();
    final id = await db.saveProducto('Queso campesino',
        precio: 24000, costo: 18000, codigo: '00123', unidad: 'kg', stockInicial: 5);
    final p = (await db.productos()).single;
    expect(p.unidad, 'kg');
    expect(p.codigo, '00123');
    await db.saveVentaProductos([
      ItemVenta(productoId: id, nombre: p.nombre, cantidad: 0.75, precio: 24000, costo: 18000)
    ]);
    expect((await db.productos()).single.stock, closeTo(4.25, 0.0001));
    expect((await db.movimientos()).single['monto'], 18000);
    expect(() => db.saveProducto('X', precio: 1, unidad: 'caja'), throwsArgumentError);
  });
}
