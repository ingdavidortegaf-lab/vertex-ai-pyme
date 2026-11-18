import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vertex_ai_pyme/domain/pagos.dart';
import 'package:vertex_ai_pyme/domain/resumen.dart';
import 'soporte.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_CO'));

  test('pago dividido: la suma debe dar el total', () {
    const ok = [Pago('nequi', 20000), Pago('efectivo', 5000)];
    expect(problemaPagos(ok, 25000), isNull);
    expect(problemaPagos(const [Pago('nequi', 20000)], 25000), contains('Faltan'));
    expect(problemaPagos(const [Pago('nequi', 30000)], 25000), contains('Sobran'));
    expect(problemaPagos(const [Pago('bitcoin', 25000)], 25000), isNotNull);
    expect(problemaPagos(const [], 25000), isNotNull);
    expect(textoPagos(ok), r'Nequi $20.000 + Efectivo $5.000');
    expect(normalizarPagos(const [Pago('efectivo', 2000), Pago('nequi', 1000), Pago('efectivo', 3000)]),
        const [Pago('efectivo', 5000), Pago('nequi', 1000)]);
  });

  test('movimientos de versiones anteriores se leen como efectivo; el fiado no tiene pagos', () {
    expect(leerPagos(null, monto: 8000, tipo: 'ingreso'), const [Pago('efectivo', 8000)]);
    expect(leerPagos(null, monto: 8000, tipo: 'ingreso', credito: true), isEmpty);
    expect(leerPagos('[{"medio":"nequi","monto":8000}]', monto: 8000, tipo: 'abono'),
        const [Pago('nequi', 8000)]);
    expect(leerPagos([
      {'medio': 'daviplata', 'monto': 8000}
    ], monto: 8000, tipo: 'ingreso'), const [Pago('daviplata', 8000)]);
  });

  test('se guarda con la venta, viaja a la nube y alimenta el cierre de caja', () async {
    final db = await baseDePrueba();
    final ana = await db.saveCliente('Ana Pérez', '3001234567');
    await db.saveMovimiento('Mercado', 25000,
        pagos: const [Pago('nequi', 20000), Pago('efectivo', 5000)]);
    await db.saveMovimiento('Gaseosa', 3000); // sin indicar: efectivo
    await db.saveMovimiento('Fiado', 10000, credito: true, clienteId: ana);
    await db.saveMovimiento('Abono', 4000, tipo: 'abono', clienteId: ana,
        pagos: const [Pago('bancolombia', 4000)]);
    await db.saveMovimiento('Hielo', 2000, tipo: 'egreso');
    final pid = await db.saveProducto('Arroz', precio: 2500, stockInicial: 10);
    await db.saveVentaProductos(
        [ItemVenta(productoId: pid, nombre: 'Arroz', cantidad: 2, precio: 2500)],
        pagos: const [Pago('tarjeta_debito', 5000)]);

    // Un pago que no cuadra se rechaza antes de guardar.
    expect(() => db.saveMovimiento('Malo', 9000, pagos: const [Pago('nequi', 1000)]),
        throwsArgumentError);

    // Lo que viaja a la nube lleva la lista de pagos (o null si es fiado).
    final cola = await db.db.query('cola_sync', orderBy: 'n');
    final payloads = cola.map((c) => c['payload'] as String).toList();
    expect(
        payloads.any((p) => p.contains(
            '"pagos":[{"medio":"efectivo","monto":5000.0},{"medio":"nequi","monto":20000.0}]')),
        isTrue);
    expect(payloads.any((p) => p.contains('"concepto":"Fiado"') && p.contains('"pagos":null')), isTrue);

    final hoy = DateTime.now();
    final r = await db.resumenPeriodo(
        DateTime(hoy.year, hoy.month, hoy.day), DateTime(hoy.year, hoy.month, hoy.day + 1));
    expect(r.medios.entrada('nequi'), 20000);
    expect(r.medios.entrada('efectivo'), 5000 + 3000);
    expect(r.medios.entrada('bancolombia'), 4000);
    expect(r.medios.entrada('tarjeta_debito'), 5000);
    expect(r.medios.salida('efectivo'), 2000);
    expect(r.medios.efectivoEsperado(50000), 50000 + 8000 - 2000);
    expect(r.medios.totalDigital, 20000 + 4000 + 5000);

    // Lo que llega de otro celular conserva sus pagos.
    await db.aplicarVentasRemotas([
      {
        'id': '11111111-1111-4111-8111-111111111111',
        'concepto': 'Venta del otro celular',
        'monto': 12000,
        'tipo': 'ingreso',
        'credito': false,
        'fecha': hoy.toUtc().toIso8601String(),
        'pagos': [
          {'medio': 'daviplata', 'monto': 12000}
        ],
      }
    ]);
    final r2 = await db.resumenPeriodo(
        DateTime(hoy.year, hoy.month, hoy.day), DateTime(hoy.year, hoy.month, hoy.day + 1));
    expect(r2.medios.entrada('daviplata'), 12000);
  });

  test('datos para recibir pagos', () async {
    final db = await baseDePrueba();
    expect((await db.datosPago()).vacio, isTrue);
    await db.guardarDatosPago(const DatosPago(nequi: '3001234567', bancolombia: 'Ahorros 123-456789-01'));
    expect((await db.datosPago()).lineas(),
        ['Nequi: 300 123 4567', 'Bancolombia: Ahorros 123-456789-01']);
  });
}
