import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vertex_ai_pyme/data/remote_api.dart';
import 'package:vertex_ai_pyme/data/sync_service.dart';
import 'package:vertex_ai_pyme/domain/caja.dart';
import 'package:vertex_ai_pyme/domain/pagos.dart';
import 'package:vertex_ai_pyme/domain/resumen.dart';
import 'package:vertex_ai_pyme/domain/roles.dart';
import 'soporte.dart';

void main() {
  late LocalDb db;
  const it = 50;

  setUp(() async => db = await baseDePrueba());

  Future<List<Map<String, dynamic>>> colaVentas() async => [
        for (final c in await db.colaLista())
          if (c['tabla'] == 'ventas') jsonDecode(c['payload'] as String) as Map<String, dynamic>
      ];

  group('reglas de caja (dominio)', () {
    test('tope de descuento: el dueño libre; los demás hasta el porcentaje', () {
      expect(descuentoMaximo(10000, 10), 1000);
      expect(problemaDescuento(1000, 10000, topePct: 10, libre: false), isNull);
      expect(problemaDescuento(1500, 10000, topePct: 10, libre: false), contains('10 %'));
      expect(problemaDescuento(500, 10000, topePct: 0, libre: false), contains('no ha permitido'));
      expect(problemaDescuento(5000, 10000, topePct: 0, libre: true), isNull);
      expect(problemaDescuento(10000, 10000, topePct: 0, libre: true), isNotNull, reason: 'no puede quedar en cero');
      expect(problemaDescuento(-1, 10000, topePct: 50, libre: true), isNotNull);
      expect(libreDeTope(const ContextoEquipo(), null), isTrue);
      expect(libreDeTope(const ContextoEquipo(), Rol.despachador), isFalse);
      expect(libreDeTope(const ContextoEquipo(rol: Rol.administrador), null), isFalse);
    });

    test('efectivo del turno: solo cuenta el efectivo y las anulaciones restan', () {
      final ef = efectivoDelTurno(50000, [
        {'tipo': 'ingreso', 'credito': 0, 'monto': 10000, 'pagos': null, 'signo': 1},
        {'tipo': 'ingreso', 'credito': 0, 'monto': 5000, 'pagos': '[{"medio":"nequi","monto":5000}]', 'signo': 1},
        {'tipo': 'egreso', 'credito': 0, 'monto': 3000, 'pagos': null, 'signo': 1},
        {'tipo': 'ingreso', 'credito': 1, 'monto': 8000, 'pagos': null, 'signo': 1},
        {'tipo': 'abono', 'credito': 0, 'monto': 2000, 'pagos': null, 'signo': 1},
        {'tipo': 'ingreso', 'credito': 0, 'monto': -10000, 'pagos': null, 'signo': -1},
        {'tipo': null, 'credito': 0, 'monto': -999, 'pagos': null, 'signo': -1},
      ]);
      expect(ef.entradas, 2000);
      expect(ef.salidas, 3000);
      expect(ef.otrosMedios, 5000);
      expect(ef.esperado, 49000);
      expect(textoDiferencia(-500), 'Faltan');
      expect(textoDiferencia(0.2), 'Cuadra exacto');
    });
  });

  group('anulaciones', () {
    test('anular una venta de contado: queda en la lista, sale de los totales y del efectivo', () async {
      final id = await db.saveMovimiento('Venta de mostrador', 10000);
      final anul = await db.anular(id, motivo: 'Se cobró dos veces');

      final movs = await db.movimientos();
      expect(movs, hasLength(2), reason: 'nada se borra');
      final a = movs.singleWhere((m) => m['id'] == anul);
      expect(a['tipo'], 'anulacion');
      expect(a['concepto'], 'Anulación: Venta de mostrador · Se cobró dos veces');
      expect(movs.singleWhere((m) => m['id'] == id)['anulada'], 1);

      final hoy = DateTime.now();
      final r = await db.resumenPeriodo(DateTime(hoy.year, hoy.month, hoy.day), hoy.add(const Duration(days: 1)));
      expect(r.ventas, 0);
      expect(r.nVentas, 0);
      expect(r.medios.entradas['efectivo'] ?? 0, 0);
      expect((await db.resumenMes()).ingresos, 0);

      final payload = (await colaVentas()).last;
      expect(payload['tipo'], 'anulacion');
      expect(payload['anula'], id);
      expect(payload['anula_tipo'], 'ingreso');
      expect(payload['monto'], 10000);

      await expectLater(db.anular(id), throwsStateError, reason: 'se anula una sola vez');
      await expectLater(db.anular(anul), throwsStateError, reason: 'una anulación no se anula');
    });

    test('anular un fiado: el cliente deja de deber y no aparece en su cuenta de cobro', () async {
      final ana = await db.saveCliente('Ana Pérez', '3001234567');
      final f = await db.saveMovimiento('Mercado', 30000, credito: true, clienteId: ana);
      await db.saveMovimiento('Abono', 10000, tipo: 'abono', clienteId: ana);
      expect((await db.clientesConSaldo()).single.saldo, 20000);
      await db.anular(f);
      expect((await db.clientesConSaldo()).single.saldo, -10000, reason: 'queda a favor el abono');
      final credito = await db.movimientosDeCredito(ana);
      expect(credito.map((m) => m['concepto']), ['Abono']);
    });

    test('anular una venta con productos: lo vendido vuelve al inventario y la ganancia se ajusta', () async {
      final arroz = await db.saveProducto('Arroz', precio: 2500, costo: 2000, stockInicial: 10);
      final v = await db.saveVentaProductos(
          [ItemVenta(productoId: arroz, nombre: 'Arroz', cantidad: 4, precio: 2500, costo: 2000, unidad: 'und')]);
      expect((await db.productos()).single.stock, 6);
      await db.anular(v);
      expect((await db.productos()).single.stock, 10);
      final hoy = DateTime.now();
      final r = await db.resumenPeriodo(DateTime(hoy.year, hoy.month, hoy.day), hoy.add(const Duration(days: 1)));
      expect(r.gananciaProductos, 0);
      final inv = await db.db.query('inventario', where: "motivo = 'anulacion'");
      expect(inv.single['cantidad'], 4);
      expect(inv.single['venta_id'], v);
    });

    test('la anulación cuenta en su fecha: el informe del día de la venta no cambia', () async {
      var ahora = DateTime(2026, 11, 20, 10);
      db.reloj = () => ahora;
      final v = await db.saveMovimiento('Venta del jueves', 8000);
      ahora = DateTime(2026, 11, 21, 9);
      await db.anular(v);
      db.reloj = DateTime.now;
      final jueves = await db.resumenPeriodo(DateTime(2026, 11, 20), DateTime(2026, 11, 21));
      final viernes = await db.resumenPeriodo(DateTime(2026, 11, 21), DateTime(2026, 11, 22));
      expect(jueves.ventas, 8000);
      expect(viernes.ventas, -8000);
      expect(viernes.nVentas, -1);
    });

    test('anular un gasto devuelve el valor a la caja', () async {
      final g = await db.saveMovimiento('Arriendo', 900000, tipo: 'egreso');
      await db.anular(g);
      expect((await db.resumenMes()).egresos, 0);
    });

    test('solo dueño o administrador; con un perfil sin permiso hace falta quien autorice', () async {
      final v = await db.saveMovimiento('Venta', 5000);
      db.equipo.value = const ContextoEquipo(rol: Rol.despachador);
      await expectLater(db.anular(v), throwsStateError, reason: 'la cuenta de despachador nunca anula');

      db.equipo.value = const ContextoEquipo();
      final luis = await db.crearPerfil('Luis', Rol.despachador, '2580', iteraciones: it);
      await db.entrarComo(luis, '2580');
      await expectLater(db.anular(v),
          throwsA(isA<StateError>().having((e) => e.message, 'm', 'autorizacion')));
      final a = await db.anular(v, autoriza: 'Marta');
      final fila = (await db.db.query('ventas', where: 'id = ?', whereArgs: [a])).single;
      expect(fila['autoriza'], 'Marta');
      expect(fila['perfil'], 'Luis');
    });

    test('se sube a la nube; el servidor rechaza la segunda anulación del mismo movimiento', () async {
      final srv = ServidorFalso();
      final sync = SyncService.instance
        ..db = db
        ..remoto = srv
        ..hayRed = () async => true;
      final v = await db.saveMovimiento('Venta', 5000);
      await sync.sync();
      // Otro celular lo anuló primero.
      await srv.enviar('ventas', {
        'id': 'a-otro', 'concepto': 'Anulación: Venta', 'monto': 5000, 'tipo': 'anulacion', 'credito': false,
        'fecha': DateTime.now().toUtc().toIso8601String(), 'anula': v,
      });
      await db.anular(v);
      await sync.sync();
      expect(await db.pendientes(), 1, reason: 'no se borra: se reintenta y luego queda a la vista como error');
      expect((await db.colaLista()).isEmpty, isTrue, reason: 'espera antes de reintentar');
      expect(srv.tablas['ventas']!.values.where((x) => x['tipo'] == 'anulacion'), hasLength(1));
      await expectLater(
          srv.enviar('ventas', {
            'id': 'a-mal', 'concepto': 'x', 'monto': 1, 'tipo': 'anulacion', 'credito': false,
            'fecha': DateTime.now().toUtc().toIso8601String(), 'anula': 'no-existe',
          }),
          throwsA(isA<RechazoServidor>()));
    });

    test('lo que baja de la nube trae la anulación y se descuenta igual', () async {
      final f = DateTime.now().toUtc().toIso8601String();
      await db.aplicarVentasRemotas([
        {'id': 'v1', 'concepto': 'Venta', 'monto': 7000, 'tipo': 'ingreso', 'credito': false, 'fecha': f},
        {'id': 'a1', 'concepto': 'Anulación: Venta', 'monto': 7000, 'tipo': 'anulacion', 'credito': false,
          'fecha': f, 'anula': 'v1', 'anula_tipo': 'ingreso', 'autoriza': 'Marta'},
      ]);
      expect((await db.resumenMes()).ingresos, 0);
      expect((await db.movimientos()).singleWhere((m) => m['id'] == 'v1')['anulada'], 1);
    });
  });

  group('descuentos', () {
    test('el dueño da el descuento que quiera; el precio de cada producto lo refleja', () async {
      final arroz = await db.saveProducto('Arroz', precio: 2500, costo: 2000, stockInicial: 10);
      final v = await db.saveVentaProductos(
          [ItemVenta(productoId: arroz, nombre: 'Arroz', cantidad: 4, precio: 2500, costo: 2000, unidad: 'und')],
          descuento: 1000);
      final fila = (await db.db.query('ventas', where: 'id = ?', whereArgs: [v])).single;
      expect(fila['monto'], 9000);
      expect(fila['descuento'], 1000);
      final inv = (await db.db.query('inventario', where: "motivo = 'venta'")).single;
      expect(inv['precio_unit'], 2250);
      final hoy = DateTime.now();
      final r = await db.resumenPeriodo(DateTime(hoy.year, hoy.month, hoy.day), hoy.add(const Duration(days: 1)));
      expect(r.gananciaProductos, 1000, reason: '4 × (2250 − 2000)');
      expect((await colaVentas()).last['descuento'], 1000);
    });

    test('el despachador solo hasta el tope; sin tope, nada', () async {
      db.equipo.value = const ContextoEquipo(rol: Rol.despachador);
      expect(() => db.saveMovimiento('Venta', 10000, descuento: 500), throwsArgumentError);
      db.equipo.value = const ContextoEquipo(rol: Rol.despachador, descuentoMaxPct: 10);
      await db.saveMovimiento('Venta', 10000, descuento: 1000);
      expect(() => db.saveMovimiento('Venta', 10000, descuento: 1500), throwsArgumentError);
      expect((await db.movimientos()).single['monto'], 9000);
      expect(() => db.saveMovimiento('Pago', 10000, tipo: 'egreso', descuento: 100), throwsArgumentError,
          reason: 'el descuento es solo para ventas');
    });

    test('el bodeguero no da descuentos y los pagos deben sumar el valor con descuento', () async {
      db.equipo.value = const ContextoEquipo(rol: Rol.bodeguero, descuentoMaxPct: 50);
      expect(() => db.saveMovimiento('Venta', 10000, descuento: 100), throwsArgumentError);
      db.equipo.value = const ContextoEquipo();
      expect(() => db.saveMovimiento('Venta', 10000, descuento: 1000, pagos: [const Pago('efectivo', 10000)]),
          throwsArgumentError);
      await db.saveMovimiento('Venta', 10000, descuento: 1000, pagos: [const Pago('efectivo', 9000)]);
    });

    test('el servidor también lo impide si el celular se salta el tope', () async {
      final srv = ServidorFalso()..miembro('u-duena', 'e1', Rol.dueno);
      srv.miembro('u-pedro', 'e1', Rol.despachador);
      srv.yo = 'u-pedro';
      final f = DateTime.now().toUtc().toIso8601String();
      await expectLater(
          srv.enviar('ventas', {'id': 'v', 'concepto': 'V', 'monto': 5000, 'tipo': 'ingreso', 'credito': false,
            'fecha': f, 'descuento': 5000}),
          throwsA(isA<RechazoServidor>()));
      srv.yo = 'u-duena';
      await srv.definirDescuentoMaximo(10);
      srv.yo = 'u-pedro';
      await srv.enviar('ventas', {'id': 'v2', 'concepto': 'V', 'monto': 9000, 'tipo': 'ingreso', 'credito': false,
        'fecha': f, 'descuento': 1000});
    });
  });

  group('turnos', () {
    test('abrir, vender, cerrar contando: el esperado y la diferencia salen solos', () async {
      final ana = await db.saveCliente('Ana Pérez', '3001234567');
      final luis = await db.crearPerfil('Luis', Rol.despachador, '2580', iteraciones: it);
      await db.entrarComo(luis, '2580');
      final t = await db.abrirTurno(50000);
      expect(t.perfil, 'Luis');
      await expectLater(db.abrirTurno(0), throwsStateError, reason: 'uno a la vez');

      final v = await db.saveMovimiento('Venta', 10000);
      await db.saveMovimiento('Venta Nequi', 5000, pagos: [const Pago('nequi', 5000)]);
      db.salirPerfil(); // la dueña registra un gasto y un fiado en el mismo turno
      await db.saveMovimiento('Hielo', 3000, tipo: 'egreso');
      await db.saveMovimiento('Fiado', 8000, credito: true, clienteId: ana);
      await db.saveMovimiento('Abono', 2000, tipo: 'abono', clienteId: ana);
      await db.anular(v);

      final ef = (await db.efectivoTurnoAbierto())!;
      expect(ef.esperado, 49000);
      expect(ef.otrosMedios, 5000);
      final cerrado = await db.cerrarTurno(48500, nota: 'Billete roto');
      expect(cerrado.diferencia, -500);
      expect(db.turnoAbierto.value, isNull);
      expect((await db.turnos()).single.id, t.id);

      final enCola = (await db.colaLista()).where((c) => c['tabla'] == 'turnos').single;
      final p = jsonDecode(enCola['payload'] as String) as Map<String, dynamic>;
      expect(p['esperado'], 49000);
      expect(p['contado'], 48500);
      expect(p['perfil'], 'Luis');

      await db.saveMovimiento('Fuera de turno', 1000);
      expect((await db.movimientos()).first['turno'], isNull);
    });

    test('el turno abierto se recuerda al abrir la app y sube a la nube al cerrarlo', () async {
      final srv = ServidorFalso();
      final sync = SyncService.instance
        ..db = db
        ..remoto = srv
        ..hayRed = () async => true;
      final t = await db.abrirTurno(20000);
      db.turnoAbierto.value = null;
      await db.cargarModo();
      expect(db.turnoAbierto.value?.id, t.id);
      await db.saveMovimiento('Venta', 4000);
      await db.cerrarTurno(24000);
      await sync.sync();
      expect(srv.tablas['turnos']![t.id]!['esperado'], 24000);
      expect(srv.tablas['ventas']!.values.single['turno'], t.id);
    });

    test('el dueño baja los turnos de sus empleados; el bodeguero no abre turnos', () async {
      await db.aplicarTurnosRemotos([
        {'id': 't1', 'perfil': 'Pedro', 'abre': '2026-11-21T13:00:00Z', 'cierra': '2026-11-21T22:00:00Z',
          'base': 50000, 'esperado': 180000, 'contado': 179000, 'nota': ''},
      ]);
      expect((await db.turnos()).single.diferencia, -1000);
      db.equipo.value = const ContextoEquipo(rol: Rol.bodeguero);
      await expectLater(db.abrirTurno(0), throwsStateError);
    });
  });

  test('una base v9 sube a v10 sin perder ventas ni inventario', () async {
    sqfliteFfiInit();
    final v9 = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false));
    await v9.execute('''CREATE TABLE ventas(id TEXT PRIMARY KEY, cliente_id TEXT, concepto TEXT NOT NULL,
      monto REAL NOT NULL CHECK (monto > 0), tipo TEXT NOT NULL CHECK (tipo IN ('ingreso','egreso','abono')),
      credito INTEGER NOT NULL DEFAULT 0, fecha TEXT NOT NULL, sync TEXT NOT NULL DEFAULT 'pendiente',
      pagos TEXT, tercero_id TEXT, perfil TEXT NOT NULL DEFAULT '')''');
    await v9.execute('''CREATE TABLE inventario(id TEXT PRIMARY KEY, producto_id TEXT NOT NULL,
      cantidad REAL NOT NULL, motivo TEXT NOT NULL CHECK (motivo IN ('venta','entrada','ajuste')),
      venta_id TEXT, precio_unit REAL, costo_unit REAL, fecha TEXT NOT NULL, sync TEXT NOT NULL DEFAULT 'pendiente')''');
    await v9.insert('ventas', {'id': 'v1', 'concepto': 'Venta vieja', 'monto': 500, 'tipo': 'ingreso', 'fecha': 't',
      'perfil': 'Luis', 'sync': 'enviado'});
    await v9.insert('inventario', {'id': 'i1', 'producto_id': 'p1', 'cantidad': 3, 'motivo': 'entrada', 'fecha': 't'});
    await LocalDb.migrar(v9, 9, 10);
    final v = (await v9.query('ventas')).single;
    expect(v['perfil'], 'Luis');
    expect(v['sync'], 'enviado');
    expect(v['descuento'], 0);
    expect((await v9.query('inventario')).single['cantidad'], 3);
    expect((await v9.query('ventas_netas')).single['signo'], 1);
    await v9.close();
  });
}
