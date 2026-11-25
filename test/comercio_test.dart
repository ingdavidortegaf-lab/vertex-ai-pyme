import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vertex_ai_pyme/domain/codigos.dart';
import 'package:vertex_ai_pyme/domain/conflictos.dart';
import 'package:vertex_ai_pyme/domain/importar.dart';
import 'package:vertex_ai_pyme/domain/resumen.dart';
import 'soporte.dart';

/// Supermercado y ferretería: unidades por medida y empaque, precio por
/// mayor, vencimientos e importar productos desde Excel.
void main() {
  group('unidades', () {
    test('metro, litro y galón se venden en fracciones; caja y paquete no', () {
      for (final u in ['kg', 'lb', 'm', 'l', 'gal']) {
        expect(esFraccionable(u), isTrue, reason: u);
      }
      for (final u in ['und', 'caja', 'paq', 'serv']) {
        expect(esFraccionable(u), isFalse, reason: u);
      }
      expect(esPorPeso('m'), isFalse); // la gramera es solo kilo y libra
    });

    test('textos de precio y cantidad', () {
      expect(precioConUnidad(4200, 'm'), r'$4.200/m');
      expect(precioConUnidad(2500, 'und'), r'$2.500 c/u');
      expect(precioConUnidad(30000, 'serv'), r'$30.000');
      expect(cantidadConUnidad(12.5, 'm'), '12,5 m');
      expect(cantidadConUnidad(2, 'caja'), '2 cajas');
      expect(cantidadConUnidad(1, 'paq'), '1 paquete');
      expect(cantidadConUnidad(3, 'und'), '3');
    });
  });

  group('precio por mayor', () {
    const cemento = ProductoStock(
        id: 'c', nombre: 'Cemento', precio: 34000, precioMayor: 32500, cantidadMayor: 10, stock: 50);
    test('aplica desde la cantidad indicada', () {
      expect(cemento.precioPara(9), 34000);
      expect(cemento.precioPara(10), 32500);
      expect(cemento.precioPara(25), 32500);
    });
    test('sin cantidad o sin precio no aplica', () {
      const p = ProductoStock(id: 'x', nombre: 'X', precio: 1000, precioMayor: 800);
      expect(p.tienePrecioMayor, isFalse);
      expect(p.precioPara(1000), 1000);
    });
  });

  group('vencimiento', () {
    final hoy = DateTime(2026, 11, 25);
    test('días que faltan y por vencer a 30 días', () {
      const leche = ProductoStock(id: 'l', nombre: 'Leche', stock: 5, vence: '2026-12-01');
      expect(leche.diasParaVencer(hoy), 6);
      expect(leche.porVencer(hoy), isTrue);
      const lejos = ProductoStock(id: 'a', nombre: 'Arroz', stock: 5, vence: '2027-06-01');
      expect(lejos.porVencer(hoy), isFalse);
      const vencido = ProductoStock(id: 'y', nombre: 'Yogur', stock: 2, vence: '2026-11-20');
      expect(vencido.diasParaVencer(hoy), -5);
      expect(vencido.porVencer(hoy), isTrue);
      // Sin existencias no hay nada que vigilar.
      const agotado = ProductoStock(id: 'z', nombre: 'Z', vence: '2026-11-26');
      expect(agotado.porVencer(hoy), isFalse);
    });
    test('solo se acepta AAAA-MM-DD real', () {
      expect(fechaVenceValida('2026-12-15'), '2026-12-15');
      expect(fechaVenceValida('15/12/2026'), '');
      expect(fechaVenceValida('2026-02-30'), '');
      expect(fechaVenceValida(null), '');
    });
  });

  group('importar desde Excel', () {
    test('con títulos en cualquier orden y unidades escritas como sea', () {
      final r = leerProductosPegados('Código\tNombre\tPrecio de venta\tCosto\tCantidad\tUnidad\tIVA\n'
          '7701\tCable 12\t\$4.200\t3000\t500\tmetros\t19%\n'
          '7702\tPintura blanca\t98.000\t72.000\t12\tGalón\t19\n'
          '\tArroz 500 g\t2500\t1800\t60\t\t0\n');
      expect(r.errores, isEmpty);
      expect(r.filas, hasLength(3));
      final cable = r.filas.first;
      expect(cable.nombre, 'Cable 12');
      expect(cable.codigo, '7701');
      expect(cable.precio, 4200);
      expect(cable.costo, 3000);
      expect(cable.stock, 500);
      expect(cable.unidad, 'm');
      expect(cable.iva, 19);
      expect(r.filas[1].unidad, 'gal');
      expect(r.filas[1].precio, 98000);
      expect(r.filas[2].unidad, 'und');
      expect(r.filas[2].iva, 0);
    });

    test('sin títulos usa el orden Nombre, Precio, Costo, Stock, Código; acepta punto y coma', () {
      final r = leerProductosPegados('Tornillo 1/4;350;200;1000;T14\nTuerca;150;90;800;');
      expect(r.errores, isEmpty);
      expect(r.filas.map((f) => f.nombre), ['Tornillo 1/4', 'Tuerca']);
      expect(r.filas.first.codigo, 'T14');
      expect(r.filas.first.stock, 1000);
    });

    test('las filas malas se reportan con su número y no frenan las demás', () {
      final r = leerProductosPegados('Nombre\tPrecio\tUnidad\n'
          'Bueno\t1000\tund\n'
          'Sin precio\t\tund\n'
          'Unidad rara\t500\tbulto\n'
          'X\t100\tund\n');
      expect(r.filas.map((f) => f.nombre), ['Bueno']);
      expect(r.errores, hasLength(3));
      expect(r.errores[0], contains('Fila 3'));
      expect(r.errores[1], contains('bulto'));
      expect(r.errores[2], contains('Fila 5'));
    });

    test('precio por mayor solo si está completo y es más barato', () {
      final r = leerProductosPegados('Nombre\tPrecio\tPrecio por mayor\tDesde\n'
          'Cemento\t34000\t32500\t10\n'
          'Arena\t5000\t6000\t10\n');
      expect(r.filas[0].precioMayor, 32500);
      expect(r.filas[0].cantidadMayor, 10);
      expect(r.filas[1].precioMayor, 0);
    });
  });

  group('en la base local', () {
    late LocalDb db;
    setUp(() async => db = await baseDePrueba());

    test('guarda precio por mayor, vencimiento y unidad nueva, y los sube a la nube', () async {
      final id = await db.saveProducto('Cable 12',
          precio: 4200, unidad: 'm', precioMayor: 3800, cantidadMayor: 50, vence: '');
      final p = (await db.productos()).single;
      expect(p.unidad, 'm');
      expect(p.precioMayor, 3800);
      expect(p.cantidadMayor, 50);
      final cola = await db.db.query('cola_sync', where: 'registro_id = ?', whereArgs: [id]);
      expect(cola.last['payload'], contains('"precio_mayor":3800'));
      expect(() => db.saveProducto('Mal', precio: 1, vence: '31/12/2026'), throwsArgumentError);
      expect(() => db.saveProducto('Mal', precio: 1, unidad: 'bulto'), throwsArgumentError);
    });

    test('la venta con productos cobra el precio por mayor que le llega', () async {
      final id = await db.saveProducto('Cemento',
          precio: 34000, costo: 29500, stockInicial: 40, precioMayor: 32500, cantidadMayor: 10);
      final p = (await db.productos()).single;
      await db.saveVentaProductos([
        ItemVenta(productoId: id, nombre: 'Cemento', cantidad: 12, precio: p.precioPara(12), costo: p.costo),
      ]);
      final v = (await db.db.query('ventas')).single;
      expect(v['monto'], 12 * 32500);
      expect((await db.productos()).single.stock, 28);
    });

    test('importar: nuevos con stock; existentes se actualizan sin tocar el stock', () async {
      await db.saveProducto('Cable 12', precio: 4000, stockInicial: 100, codigo: '7701');
      final r = leerProductosPegados('Nombre\tPrecio\tStock\tCódigo\n'
          'Cable 12 (nuevo nombre)\t4200\t999\t7701\n'
          'Pintura\t98000\t12\t7702\n');
      final n = await db.importarProductos(r.filas);
      expect(n.nuevos, 1);
      expect(n.actualizados, 1);
      final l = await db.productos();
      final cable = l.firstWhere((x) => x.codigo == '7701');
      expect(cable.precio, 4200);
      expect(cable.nombre, 'Cable 12 (nuevo nombre)');
      expect(cable.stock, 100);
      expect(l.firstWhere((x) => x.codigo == '7702').stock, 12);
    });

    test('migración v11 → v12 conserva los productos', () async {
      sqfliteFfiInit();
      final v11 = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
          options: OpenDatabaseOptions(singleInstance: false));
      await v11.execute('CREATE TABLE productos(id TEXT PRIMARY KEY, nombre TEXT NOT NULL)');
      await v11.insert('productos', {'id': 'p1', 'nombre': 'Arroz'});
      await LocalDb.migrar(v11, 11, 12);
      final r = (await v11.query('productos')).single;
      expect(r['precio_mayor'], 0);
      expect(r['cantidad_mayor'], 0);
      expect(r['vence'], '');
      expect(r['vence_ts'], '1970-01-01T00:00:00.000Z');
      await v11.close();
    });
  });

  test('al unir, gana el cambio más reciente del precio por mayor', () {
    final viejo = ProductoCampos.fromRemote({
      'id': 'p', 'nombre': 'Cemento', 'precio': 34000, 'precio_mayor': 32000,
      'precio_mayor_ts': '2026-11-01T00:00:00.000Z', 'nombre_ts': '2026-11-01T00:00:00.000Z',
    });
    final nuevo = ProductoCampos.fromRemote({
      'id': 'p', 'nombre': 'Cemento', 'precio': 34000, 'precio_mayor': 32500,
      'precio_mayor_ts': '2026-11-20T00:00:00.000Z', 'nombre_ts': '2026-11-01T00:00:00.000Z',
    });
    expect(viejo.merge(nuevo).precioMayor, 32500);
    expect(nuevo.merge(viejo).precioMayor, 32500);
  });
}
