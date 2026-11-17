import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vertex_ai_pyme/data/local_db.dart';
import 'package:vertex_ai_pyme/domain/documentos.dart';
import 'package:vertex_ai_pyme/domain/formato.dart';
import 'package:vertex_ai_pyme/domain/resumen.dart';
import 'soporte.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_CO'));
  const negocio = PerfilNegocio(
      nombre: 'Tienda Doña Marta', nit: '1118000000', direccion: 'Cra 20 # 10-15');

  test('comprobante: número, líneas, total y aviso de que no es factura electrónica', () {
    final t = textoComprobante(
      negocio: negocio,
      ventaId: '7f3a21c9-0000-4000-8000-000000000000',
      fecha: DateTime(2026, 11, 18, 15, 45),
      lineas: const [LineaDoc('Arroz 500 g', 2, 2500), LineaDoc('Aceite 1 L', 1, 9500)],
      total: 14500,
      cliente: 'Ana Pérez',
      fiado: true,
      saldoCliente: 40000,
    );
    expect(t, contains('*Tienda Doña Marta*'));
    expect(t, contains('NIT/C.C. 1118000000'));
    expect(t, contains('N.º 7F3A21C9'));
    expect(t, contains('2 × Arroz 500 g (${cop(2500)} c/u): ${cop(5000)}'));
    expect(t, contains('• Aceite 1 L: ${cop(9500)}'));
    expect(t, contains('*Total: ${cop(14500)}*'));
    expect(t, contains('fiado'));
    expect(t, contains('Saldo pendiente a la fecha: ${cop(40000)}'));
    expect(t, contains('no es factura electrónica'));
  });

  test('pedido sugerido: agotados primero y hasta el doble del mínimo', () {
    const l = [
      ProductoStock(id: 'a', nombre: 'Arroz', minimo: 10, stock: 4),
      ProductoStock(id: 'b', nombre: 'Aceite', minimo: 6, stock: 0),
      ProductoStock(id: 'c', nombre: 'Sal', minimo: 2, stock: 9),
      ProductoStock(id: 'd', nombre: 'Huevos', stock: 0),
    ];
    final s = pedidoSugerido(l);
    expect(s.map((x) => x.$1.nombre), ['Aceite', 'Huevos', 'Arroz']);
    expect(s.map((x) => x.$2), [12, 1, 16]);
    final t = textoPedido(
        negocio: negocio,
        fecha: DateTime(2026, 11, 18),
        items: [for (final (p, c) in s) (p.nombre, c)],
        proveedor: 'Distribuidora El Llano');
    expect(t, contains('Buen día, Distribuidora El Llano.'));
    expect(t, contains('• 12 × Aceite'));
  });

  test('cotización y promoción', () {
    final c = textoCotizacion(
        negocio: negocio,
        cotizacionId: 'abcd1234-x',
        fecha: DateTime(2026, 11, 18),
        lineas: const [LineaDoc('Purina 40 kg', 2, 118000)]);
    expect(c, contains('*Cotización N.º ABCD1234*'));
    expect(c, contains('*Total: ${cop(236000)}*'));
    expect(c, contains('válidos hasta el 26/11/2026'));
    final p = textoPromocion(
        negocio: negocio, productos: const [('Arroz 500 g', 2300)], nota: 'Solo hoy');
    expect(p, contains('• Arroz 500 g: ${cop(2300)}'));
    expect(p, contains('Solo hoy'));
    expect(p, contains('Cra 20 # 10-15'));
  });

  test('cotización se convierte en venta y descuenta inventario; pedido recibido suma stock y gasto', () async {
    final db = await baseDePrueba();
    final arroz = await db.saveProducto('Arroz', precio: 2500, costo: 1800, stockInicial: 10);
    final cid = await db.saveCotizacion([
      ItemVenta(productoId: arroz, nombre: 'Arroz', cantidad: 3, precio: 2500, costo: 1800)
    ]);
    final ventaId = await db.venderCotizacion(cid);
    expect((await db.productos()).single.stock, 7);
    final lineas = await db.lineasDeVenta(ventaId);
    expect(lineas.single.cantidad, 3);
    expect((await db.cotizaciones()).single['estado'], 'vendida');
    expect(() => db.venderCotizacion(cid), throwsStateError);

    await db.recibirPedido([(arroz, 20, 1800)], conceptoGasto: 'Compra a Distribuidora');
    expect((await db.productos()).single.stock, 27);
    final gastos = (await db.movimientos()).where((m) => m['tipo'] == 'egreso').toList();
    expect(gastos.single['monto'], 36000);
    expect(await db.pendientes(), greaterThan(0));
  });

  test('venta sin productos: el comprobante usa el concepto', () async {
    final db = await baseDePrueba();
    final id = await db.saveMovimiento('Venta mostrador', 12000);
    final l = await db.lineasDeVenta(id);
    expect(l.single.nombre, 'Venta mostrador');
    expect(l.single.total, 12000);
    expect(LocalDb.instance, same(db));
  });
}
