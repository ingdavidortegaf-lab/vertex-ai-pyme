import 'package:flutter_test/flutter_test.dart';
import 'package:vertex_ai_pyme/data/sync_service.dart';
import 'package:vertex_ai_pyme/domain/conflictos.dart';
import 'package:vertex_ai_pyme/domain/resumen.dart';
import 'soporte.dart';

void main() {
  late LocalDb db;
  setUp(() async => db = await baseDePrueba());

  ProductoStock buscar(List<ProductoStock> l, String id) =>
      l.firstWhere((p) => p.id == id);

  test('el stock inicial se registra como entrada', () async {
    final id = await db.saveProducto('Arroz 500 g',
        precio: 2500, costo: 1800, minimo: 5, stockInicial: 20);
    final p = buscar(await db.productos(), id);
    expect(p.stock, 20);
    expect(p.bajo, isFalse);
  });

  test('vender con productos descuenta stock, crea la venta y calcula ganancia',
      () async {
    final arroz = await db.saveProducto('Arroz', precio: 2500, costo: 1800, stockInicial: 10);
    final aceite = await db.saveProducto('Aceite', precio: 9000, costo: 7000, stockInicial: 3);
    await db.saveVentaProductos([
      const ItemVenta(productoId: '', nombre: 'x', cantidad: 0, precio: 1),
      ItemVenta(productoId: arroz, nombre: 'Arroz', cantidad: 4, precio: 2500, costo: 1800),
      ItemVenta(productoId: aceite, nombre: 'Aceite', cantidad: 1, precio: 9000, costo: 7000),
    ]);
    final l = await db.productos();
    expect(buscar(l, arroz).stock, 6);
    expect(buscar(l, aceite).stock, 2);
    final movs = await db.movimientos();
    expect(movs, hasLength(1));
    expect(movs.first['monto'], 19000);
    expect(movs.first['concepto'], '4 × Arroz, 1 × Aceite');
    final ahora = DateTime.now();
    final r = await db.resumenPeriodo(
        DateTime(ahora.year, ahora.month), DateTime(ahora.year, ahora.month + 1));
    expect(r.ventas, 19000);
    expect(r.gananciaProductos, 4 * 700 + 2000);
    final top = await db.topProductos(
        DateTime(ahora.year, ahora.month), DateTime(ahora.year, ahora.month + 1));
    expect(top.first.nombre, 'Arroz');
    expect(top.first.cantidad, 4);
  });

  test('venta fiada con productos exige cliente', () async {
    final p = await db.saveProducto('Sal', precio: 1000, stockInicial: 2);
    expect(
        () => db.saveVentaProductos(
            [ItemVenta(productoId: p, nombre: 'Sal', cantidad: 1, precio: 1000)],
            fiado: true),
        throwsArgumentError);
  });

  test('ajuste por conteo y producto agotado o bajo', () async {
    final p = await db.saveProducto('Huevos', precio: 600, minimo: 10, stockInicial: 12);
    await db.moverStock(p, -4, motivo: 'ajuste');
    var x = buscar(await db.productos(), p);
    expect(x.stock, 8);
    expect(x.bajo, isTrue);
    await db.moverStock(p, -8, motivo: 'ajuste');
    x = buscar(await db.productos(), p);
    expect(x.agotado, isTrue);
    expect(() => db.moverStock(p, -1), throwsArgumentError);
  });

  test('editar un producto solo cambia los campos tocados (unión por campo)',
      () async {
    final p = await db.saveProducto('Panela', precio: 3000, costo: 2000);
    final base = ProductoCampos.fromLocal(
        (await db.db.query('productos', where: 'id = ?', whereArgs: [p])).first);
    // Otro celular cambió el precio más tarde; aquí se cambió el nombre.
    final otro = ProductoCampos(p, {...base.valores, 'precio': 3500.0},
        {...base.ts, 'precio': base.ts['precio']!.add(const Duration(minutes: 5))});
    final local = ProductoCampos(p, {...base.valores, 'nombre': 'Panela redonda'},
        {...base.ts, 'nombre': base.ts['nombre']!.add(const Duration(minutes: 1))});
    final u = local.merge(otro);
    expect(u.nombre, 'Panela redonda');
    expect(u.precio, 3500);
  });

  test('la venta con productos se sube una sola vez y la ve otro celular',
      () async {
    final servidor = ServidorFalso();
    final s = SyncService.instance
      ..db = db
      ..remoto = servidor
      ..hayRed = (() async => true);
    final p = await db.saveProducto('Purina', precio: 118000, costo: 95000, stockInicial: 5);
    await db.saveVentaProductos(
        [ItemVenta(productoId: p, nombre: 'Purina', cantidad: 2, precio: 118000, costo: 95000)]);
    await s.sync();
    await s.sync();
    expect(servidor.tablas['productos'], hasLength(1));
    expect(servidor.tablas['inventario'], hasLength(2));
    expect(servidor.tablas['ventas'], hasLength(1));
    expect(await db.pendientes(), 0);

    // Otro celular: base nueva que solo descarga.
    final otro = await baseDePrueba();
    s.db = otro;
    await s.sync();
    expect(buscar(await otro.productos(), p).stock, 3);
    s.remoto = null;
  });
}
