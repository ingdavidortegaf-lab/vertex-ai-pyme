import 'package:flutter_test/flutter_test.dart';
import 'soporte.dart';

void main() {
  late LocalDb db;
  setUp(() async => db = await baseDePrueba());

  group('tablero del mes', () {
    test('suma ventas, gastos, fiados y abonos correctamente', () async {
      // Miércoles 18 de noviembre de 2026 (hora local).
      final ana = await db.saveCliente('Ana', '573001234567');
      final luis = await db.saveCliente('Luis', '');

      db.reloj = () => DateTime(2026, 10, 31, 23, 30); // mes anterior
      await db.saveMovimiento('Octubre', 99999);
      db.reloj = () => DateTime(2026, 11, 3, 9); // este mes, otra semana
      await db.saveMovimiento('Venta 3 nov', 7000, clienteId: luis);
      db.reloj = () => DateTime(2026, 11, 16, 9); // lunes de esta semana
      await db.saveMovimiento('Venta lunes', 10000);
      db.reloj = () => DateTime(2026, 11, 18, 8); // hoy
      await db.saveMovimiento('Venta contado', 20000);
      await db.saveMovimiento('Fiado Ana', 30000, credito: true, clienteId: ana);
      await db.saveMovimiento('Arriendo', 5000, tipo: 'egreso');
      await db.saveMovimiento('Abono Ana', 10000, tipo: 'abono', clienteId: ana);

      db.reloj = () => DateTime(2026, 11, 18, 12);
      final r = await db.resumenMes();
      expect(r.ingresos, 67000); // 7.000 + 10.000 + 20.000 + 30.000
      expect(r.nIngresos, 4);
      expect(r.egresos, 5000);
      expect(r.nEgresos, 1);
      expect(r.utilidad, 62000);
      expect(r.porCobrar, 20000); // 30.000 fiado - 10.000 abono
      expect(r.nDeudores, 1);
      expect(r.nClientes, 2);

      final d = await db.datosAsistente();
      expect(d.ventasHoy, 50000);
      expect(d.nVentasHoy, 2);
      expect(d.ventasSemana, 60000);
      expect(d.nVentasSemana, 3);
      expect(d.deudores.single.nombre, 'Ana');
      expect(d.topClientes.first.nombre, 'Ana');
      expect(d.topClientes.first.total, 30000);
    });

    test('un cliente borrado no cuenta en clientes ni deudas', () async {
      final ana = await db.saveCliente('Ana', '');
      await db.saveMovimiento('Fiado', 1000, credito: true, clienteId: ana);
      await db.deleteCliente(ana);
      final r = await db.resumenMes();
      expect(r.nClientes, 0);
      expect(r.porCobrar, 0);
      expect(await db.movimientos(), hasLength(1)); // la venta se conserva
    });
  });

  group('validaciones', () {
    test('monto <= 0 o tipo inválido se rechazan', () async {
      await expectLater(db.saveMovimiento('x', 0), throwsArgumentError);
      await expectLater(db.saveMovimiento('x', -5), throwsArgumentError);
      await expectLater(
          db.saveMovimiento('x', 5, tipo: 'robo'), throwsArgumentError);
      await expectLater(db.saveMovimiento('  ', 5), throwsArgumentError);
      expect(await db.pendientes(), 0);
    });
    test('fiado y abono exigen cliente', () async {
      await expectLater(
          db.saveMovimiento('x', 5, credito: true), throwsArgumentError);
      await expectLater(
          db.saveMovimiento('x', 5, tipo: 'abono'), throwsArgumentError);
    });
  });

  group('cola de sincronización', () {
    test('cada cambio queda en la cola junto con el dato', () async {
      final id = await db.saveCliente('Ana', '');
      await db.saveMovimiento('Venta', 1000, clienteId: id);
      expect(await db.pendientes(), 2);
      final cola = await db.colaLista();
      expect(cola.map((e) => e['tabla']), ['clientes', 'ventas']);
    });

    test('editar sin cambios no encola nada; editar solo un campo sí', () async {
      db.reloj = () => DateTime(2026, 11, 18, 8);
      final id = await db.saveCliente('Ana', '573001234567');
      await db.saveCliente('Ana', '573001234567', id: id);
      expect(await db.pendientes(), 1);
      db.reloj = () => DateTime(2026, 11, 18, 9);
      await db.saveCliente('Ana María', '573001234567', id: id);
      expect(await db.pendientes(), 2);
      final c = (await db.db.query('clientes')).single;
      expect(c['nombre_ts'], isNot(c['telefono_ts'])); // marca por campo
    });
  });
}
