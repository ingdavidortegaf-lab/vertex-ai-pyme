import 'package:flutter_test/flutter_test.dart';
import 'package:vertex_ai_pyme/domain/exportar.dart';
import 'package:vertex_ai_pyme/domain/pagos.dart';
import 'package:vertex_ai_pyme/domain/resumen.dart';
import 'package:vertex_ai_pyme/domain/roles.dart';
import 'soporte.dart';

/// Exportar a Excel, kárdex, ventas por vendedor, ganancia por producto y
/// devolver productos de una venta.
void main() {
  group('CSV para Excel', () {
    test('BOM, punto y coma, coma decimal y celdas peligrosas', () {
      final s = aCsv(['Nombre', 'Valor'], [
        ['Cable; 12', 4200.5],
        ['=HYPERLINK("x")', 3],
        ['Ana "la del 5"', -1000],
      ]);
      expect(s.startsWith('﻿'), isTrue);
      final l = s.substring(1).trim().split('\n');
      expect(l[0], 'Nombre;Valor');
      expect(l[1], '"Cable; 12";4200,5');
      // Una fórmula se escribe como texto para que Excel no la ejecute.
      expect(l[2], startsWith("\"'=HYPERLINK"));
      expect(l[3], '"Ana ""la del 5""";-1000');
    });

    test('libro de movimientos: tipo, cliente, medios y anulación', () {
      final s = csvMovimientos([
        {
          'fecha': '2026-11-25T15:00:00.000Z', 'tipo': 'ingreso', 'credito': 0, 'concepto': 'Venta',
          'cliente_nombre': 'Ana', 'monto': 12000, 'descuento': 0, 'perfil': 'Luis', 'signo': 1,
          'pagos': codificarPagos([const Pago('nequi', 12000)]),
        },
        {
          'fecha': '2026-11-25T16:00:00.000Z', 'tipo': 'ingreso', 'credito': 1, 'concepto': 'Anulación: Venta',
          'monto': -8000, 'signo': -1,
        },
      ]);
      final l = s.substring(1).trim().split('\n');
      expect(l, hasLength(3));
      expect(l[1], contains(';Venta;Venta;Ana;;12000;0;Nequi;Luis;'));
      expect(l[2], contains(';Venta fiada;'));
      expect(l[2], endsWith(';Sí'));
    });

    test('inventario sin costos para quien no los ve', () {
      const p = ProductoStock(id: 'a', nombre: 'Arroz', precio: 2500, costo: 1800, stock: 60, iva: 0);
      expect(csvProductos([p], conCostos: true), contains('Costo'));
      expect(csvProductos([p], conCostos: false), isNot(contains('Costo')));
      expect(csvProductos([p], conCostos: false), isNot(contains('1800')));
    });
  });

  test('kárdex: saldo acumulado y motivos', () {
    final k = armarKardex([
      {'fecha': '2026-11-01T10:00:00Z', 'cantidad': 10, 'motivo': 'entrada'},
      {'fecha': '2026-11-02T10:00:00Z', 'cantidad': -3, 'motivo': 'venta', 'concepto': '3 × Arroz', 'perfil': 'Ana'},
      {'fecha': '2026-11-03T10:00:00Z', 'cantidad': 3, 'motivo': 'anulacion'},
      {'fecha': '2026-11-04T10:00:00Z', 'cantidad': -2, 'motivo': 'ajuste'},
    ]);
    expect(k.map((x) => x.saldo), [10, 7, 10, 8]);
    expect(k[1].detalle, '3 × Arroz');
    expect(k[1].registro, 'Ana');
    expect(k[2].motivoTexto, 'Devolución por anulación');
  });

  test('ventas por vendedor: suma, cuenta y anulaciones', () {
    final l = ventasPorVendedor([
      {'tipo': 'ingreso', 'monto': 10000, 'perfil': 'Luis', 'signo': 1},
      {'tipo': 'ingreso', 'monto': 5000, 'perfil': 'Luis', 'signo': 1},
      {'tipo': 'ingreso', 'monto': -5000, 'perfil': 'Luis', 'signo': -1},
      {'tipo': 'ingreso', 'monto': 30000, 'perfil': '', 'signo': 1},
      {'tipo': 'egreso', 'monto': 99999, 'perfil': 'Luis', 'signo': 1},
    ]);
    expect(l.map((v) => v.nombre), ['Cuenta principal', 'Luis']);
    expect(l[1].total, 10000);
    expect(l[1].ventas, 1);
  });

  group('en la base local', () {
    late LocalDb db;
    late String cemento, arroz;
    setUp(() async {
      db = await baseDePrueba();
      cemento = await db.saveProducto('Cemento', precio: 34000, costo: 29500, stockInicial: 40);
      arroz = await db.saveProducto('Arroz', precio: 2500, costo: 1800, stockInicial: 60);
    });

    Future<double> stock(String id) async => (await db.productos()).firstWhere((p) => p.id == id).stock;

    test('kárdex y ganancia por producto', () async {
      await db.saveVentaProductos([
        ItemVenta(productoId: cemento, nombre: 'Cemento', cantidad: 3, precio: 34000, costo: 29500),
      ]);
      await db.moverStock(cemento, 10);
      final k = await db.kardex(cemento);
      expect(k.map((x) => x.motivo), ['entrada', 'venta', 'entrada']);
      expect(k.last.saldo, 47);
      final hoy = DateTime.now();
      final u = await db.utilidadPorProducto(hoy.subtract(const Duration(days: 1)), hoy.add(const Duration(days: 1)));
      expect(u.single.nombre, 'Cemento');
      expect(u.single.ingresos, 102000);
      expect(u.single.utilidad, 3 * 4500);
    });

    test('devolver un producto: la venta se anula y queda una nueva con el resto', () async {
      final v = await db.saveVentaProductos([
        ItemVenta(productoId: cemento, nombre: 'Cemento', cantidad: 3, precio: 34000, costo: 29500),
        ItemVenta(productoId: arroz, nombre: 'Arroz', cantidad: 2, precio: 2500, costo: 1800),
      ], pagos: [const Pago('nequi', 107000)]);
      final r = await db.devolverProductos(v, {cemento: 1});
      expect(r.devolver, 34000);
      expect(r.nuevaVenta, isNotNull);
      expect(await stock(cemento), 38);
      expect(await stock(arroz), 58);
      final nueva = (await db.db.query('ventas', where: 'id = ?', whereArgs: [r.nuevaVenta])).single;
      expect(nueva['monto'], 73000);
      expect(nueva['pagos'], contains('nequi'));
      expect(await db.estaAnulado(v), isTrue);
      // En los informes la venta neta queda en 73.000.
      final hoy = DateTime.now();
      final res = await db.resumenPeriodo(hoy.subtract(const Duration(days: 1)), hoy.add(const Duration(days: 1)));
      expect(res.ventas, 73000);
    });

    test('devolver de una venta fiada baja la deuda; devolver todo solo anula', () async {
      final ana = await db.saveCliente('Ana', '3001234567');
      final v = await db.saveVentaProductos([
        ItemVenta(productoId: arroz, nombre: 'Arroz', cantidad: 4, precio: 2500, costo: 1800),
      ], fiado: true, clienteId: ana);
      final r = await db.devolverProductos(v, {arroz: 1});
      expect(r.devolver, 2500);
      final saldo = (await db.clientesConSaldo()).single.saldo;
      expect(saldo, 7500);

      final v2 = await db.saveVentaProductos([
        ItemVenta(productoId: cemento, nombre: 'Cemento', cantidad: 2, precio: 34000, costo: 29500),
      ]);
      final r2 = await db.devolverProductos(v2, {cemento: 5}); // más de lo vendido: se limita
      expect(r2.nuevaVenta, isNull);
      expect(r2.devolver, 68000);
      expect(await stock(cemento), 40);
    });

    test('sin permiso de anular no se devuelve sin autorización', () async {
      final v = await db.saveVentaProductos([
        ItemVenta(productoId: arroz, nombre: 'Arroz', cantidad: 2, precio: 2500),
      ]);
      db.equipo.value = const ContextoEquipo(rol: Rol.despachador);
      await expectLater(db.devolverProductos(v, {arroz: 1}), throwsStateError);
      db.equipo.value = const ContextoEquipo();
      await expectLater(db.devolverProductos(v, const {}), throwsArgumentError);
      expect(await db.estaAnulado(v), isFalse);
    });
  });
}
