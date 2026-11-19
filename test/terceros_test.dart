import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vertex_ai_pyme/data/local_db.dart';
import 'package:vertex_ai_pyme/domain/conflictos.dart';
import 'package:vertex_ai_pyme/domain/ejemplos.dart';
import 'package:vertex_ai_pyme/domain/identificacion.dart';
import 'package:vertex_ai_pyme/domain/obligaciones.dart';
import 'package:vertex_ai_pyme/domain/pagos.dart';
import 'soporte.dart';

void main() {
  group('documentos', () {
    test('dígito de verificación del NIT (DIAN)', () {
      expect(digitoVerificacion('890903938'), 8);
      expect(digitoVerificacion('900373913'), 4);
      expect(digitoVerificacion('800197268'), 4);
    });

    test('NIT: acepta con o sin guion, avisa si el dígito no cuadra', () {
      expect(problemaDocumento('NIT', '890.903.938-8'), isNull);
      expect(problemaDocumento('NIT', '890903938'), isNull);
      expect(problemaDocumento('NIT', '890903938-5'), contains('debería ser 8'));
      expect(normalizarDocumento('NIT', '890.903.938'), '890903938-8');
      expect(normalizarDocumento('NIT', '8909039388'), '890903938-8');
      expect(mostrarDocumento('NIT', '890903938-8'), 'NIT 890.903.938-8');
    });

    test('cédula y correo', () {
      expect(problemaDocumento('CC', '1.118.555.444'), isNull);
      expect(problemaDocumento('CC', '12'), isNotNull);
      expect(problemaDocumento('CC', ''), isNull);
      expect(normalizarDocumento('CC', '1.118.555.444'), '1118555444');
      expect(mostrarDocumento('CC', '1118555444'), 'CC 1.118.555.444');
      expect(problemaCorreo('ana@gmail.com'), isNull);
      expect(problemaCorreo('ana@gmail'), isNotNull);
      expect(problemaCorreo(''), isNull);
    });
  });

  test('ejemplos según el tipo de negocio', () {
    expect(ejemplosPara('Licorera').producto, contains('Aguardiente'));
    expect(ejemplosPara('Droguería').producto, contains('Acetaminofén'));
    expect(ejemplosPara('No existe').producto, ejemplosPara('').producto);
    final fijos = fijosSugeridos('Licorera');
    expect(fijos.take(4), fijosComunes);
    expect(fijos, contains('Música (derechos de autor)'));
  });

  group('pagos fijos', () {
    final hoy = DateTime(2026, 11, 18);
    PagoFijo f(int dia, {String? ultimo}) =>
        PagoFijo(id: 'x', nombre: 'Luz', monto: 85000, dia: dia, ultimoPeriodo: ultimo);

    test('estado: vencido, pronto, pendiente y pagado', () {
      expect(estadoFijo(f(10), hoy), EstadoFijo.vencido);
      expect(estadoFijo(f(20), hoy), EstadoFijo.pronto);
      expect(estadoFijo(f(28), hoy), EstadoFijo.pendiente);
      expect(estadoFijo(f(10, ultimo: '2026-11'), hoy), EstadoFijo.pagado);
      expect(estadoFijo(f(10, ultimo: '2026-10'), hoy), EstadoFijo.vencido);
      expect(textoEstadoFijo(f(18), hoy), 'Vence hoy');
      expect(textoEstadoFijo(f(15), hoy), 'Se pasó hace 3 días');
    });

    test('día 31 en un mes de 30 vence el último día', () {
      expect(vencimiento(31, DateTime(2026, 11, 2)), DateTime(2026, 11, 30));
      expect(vencimiento(31, DateTime(2027, 2, 2)), DateTime(2027, 2, 28));
    });

    test('orden y total pendiente', () {
      final l = [f(28), f(10, ultimo: '2026-11'), f(12), f(20)];
      expect(ordenarFijos(l, hoy).map((x) => x.dia), [12, 20, 28, 10]);
      expect(faltaEsteMes(l, hoy), 85000 * 3);
    });
  });

  test('cliente con cédula, NIT y correo; edición marca solo el bloque de datos', () async {
    final db = await baseDePrueba();
    final id = await db.saveCliente('Ana Pérez', '573001234567',
        tipoDoc: 'CC', documento: '1118555444', correo: 'ana@gmail.com');
    var c = (await db.cliente(id))!;
    expect(c['documento'], '1118555444');
    expect(c['correo'], 'ana@gmail.com');

    final antes = ClienteCampos.fromLocal((await db.db.query('clientes')).single);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await db.saveCliente('Ana Pérez', '573001234567',
        id: id, tipoDoc: 'NIT', documento: '890903938-8', correo: 'ana@gmail.com');
    final despues = ClienteCampos.fromLocal((await db.db.query('clientes')).single);
    expect(despues.tipoDoc, 'NIT');
    expect(despues.nombreTs, antes.nombreTs);
    expect(despues.datosTs.isAfter(antes.datosTs), isTrue);

    // Sin cambios no se encola nada nuevo.
    final cola = (await db.colaLista()).length;
    await db.saveCliente('Ana Pérez', '573001234567', id: id);
    expect((await db.colaLista()).length, cola);
    c = (await db.cliente(id))!;
    expect(c['tipo_doc'], 'NIT');
  });

  test('los datos de identificación se unen por fecha entre celulares', () {
    final t0 = DateTime.utc(2026, 11, 18, 10);
    final t1 = t0.add(const Duration(minutes: 1));
    final a = ClienteCampos(
        id: 'c', nombre: 'Ana', nombreTs: t1, telefono: '', telefonoTs: t0,
        deleted: false, deletedTs: t0);
    final b = ClienteCampos(
        id: 'c', nombre: 'Ana P', nombreTs: t0, telefono: '', telefonoTs: t0,
        deleted: false, deletedTs: t0,
        tipoDoc: 'NIT', documento: '890903938-8', correo: 'x@y.co', datosTs: t1);
    for (final u in [a.merge(b), b.merge(a)]) {
      expect(u.nombre, 'Ana');
      expect(u.documento, '890903938-8');
      expect(u.correo, 'x@y.co');
    }
    // Una fila remota de una versión anterior (sin datos) se lee bien.
    final viejo = ClienteCampos.fromRemote({
      'id': 'c', 'nombre': 'Ana', 'nombre_ts': t0.toIso8601String(),
      'telefono': '', 'telefono_ts': t0.toIso8601String(),
      'deleted': false, 'deleted_ts': t0.toIso8601String(),
    });
    expect(viejo.documento, '');
    expect(viejo.datosTs, ClienteCampos.inicio);
  });

  test('terceros: arrendador con NIT y gasto a su nombre', () async {
    final db = await baseDePrueba();
    final don = await db.saveProveedor('Inmobiliaria Los Llanos', '3101234567',
        tipoDoc: 'NIT', documento: '900373913-4', correo: 'pagos@llanos.co', clase: 'arriendo');
    await db.saveMovimiento('Arriendo noviembre', 900000, tipo: 'egreso', terceroId: don);
    final l = await db.proveedores(clase: 'arriendo');
    expect(l.single['documento'], '900373913-4');
    expect(l.single['pagado'], 900000);
    expect(await db.proveedores(clase: 'proveedor'), isEmpty);
    // El tercero no viaja a la nube (la tabla remota no lo tiene).
    expect((await db.colaLista()).last['payload'], isNot(contains('tercero_id')));
  });

  test('pago fijo: se paga, queda como gasto y no se vuelve a pedir este mes', () async {
    final db = await baseDePrueba();
    db.reloj = () => DateTime(2026, 11, 18, 9);
    final luz = await db.saveFijo('Luz', 85000, 20);
    await db.saveFijo('Arriendo del local', 900000, 5);
    var l = await db.pagosFijos();
    expect(l.map((x) => x.nombre), ['Arriendo del local', 'Luz']);
    expect(faltaEsteMes(l, DateTime(2026, 11, 18)), 985000);

    await db.pagarFijo(luz, 87300, [const Pago('nequi', 87300)]);
    l = await db.pagosFijos();
    expect(estadoFijo(l.firstWhere((x) => x.id == luz), DateTime(2026, 11, 18)), EstadoFijo.pagado);
    final gasto = (await db.movimientos()).single;
    expect(gasto['tipo'], 'egreso');
    expect(gasto['concepto'], 'Luz (noviembre 2026)');
    expect(gasto['monto'], 87300);

    await db.deleteFijo(luz);
    expect((await db.pagosFijos()).single.nombre, 'Arriendo del local');
    db.reloj = DateTime.now;
  });

  test('una base v7 sube a v8 sin perder clientes ni proveedores', () async {
    sqfliteFfiInit();
    // Tablas como estaban en la v7 (solo las que cambian en la v8).
    final v7 = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false));
    await v7.execute('''CREATE TABLE clientes(id TEXT PRIMARY KEY, nombre TEXT NOT NULL,
      nombre_ts TEXT NOT NULL, telefono TEXT NOT NULL DEFAULT '', telefono_ts TEXT NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0, deleted_ts TEXT NOT NULL, updated_at TEXT NOT NULL,
      sync TEXT NOT NULL DEFAULT 'pendiente')''');
    await v7.execute('''CREATE TABLE proveedores(id TEXT PRIMARY KEY, nombre TEXT NOT NULL,
      telefono TEXT NOT NULL DEFAULT '', creado TEXT NOT NULL)''');
    await v7.execute('''CREATE TABLE ventas(id TEXT PRIMARY KEY, cliente_id TEXT, concepto TEXT NOT NULL,
      monto REAL NOT NULL, tipo TEXT NOT NULL, credito INTEGER NOT NULL DEFAULT 0, fecha TEXT NOT NULL,
      sync TEXT NOT NULL DEFAULT 'pendiente', pagos TEXT)''');
    await v7.insert('clientes', {
      'id': 'c1', 'nombre': 'Ana', 'nombre_ts': 't', 'telefono_ts': 't',
      'deleted_ts': 't', 'updated_at': 't'
    });
    await v7.insert('proveedores', {'id': 'p1', 'nombre': 'Don Luis', 'creado': 't'});
    await LocalDb.migrar(v7, 7, 8);
    final c = (await v7.query('clientes')).single;
    expect(c['nombre'], 'Ana');
    expect(c['tipo_doc'], 'CC');
    expect(c['datos_ts'], '1970-01-01T00:00:00.000Z');
    expect((await v7.query('proveedores')).single['clase'], 'proveedor');
    expect(await v7.query('pagos_fijos'), isEmpty);
    await v7.close();
  });
}
