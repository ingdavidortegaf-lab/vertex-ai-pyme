import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../domain/conflictos.dart';
import '../domain/resumen.dart';

/// Base local CIFRADA (SQLCipher). La clave (256 bits aleatorios) se genera
/// en el primer arranque y vive en el almacén seguro del sistema
/// (Android Keystore / iOS Keychain). Nunca se escribe en el código.
///
/// Toda escritura guarda el dato Y su entrada en la cola de sincronización
/// dentro de UNA transacción: si la app se cierra, o se guardan los dos o
/// ninguno. Así no se pierde ningún cambio.
class LocalDb {
  LocalDb._();
  static final instance = LocalDb._();

  /// Fallos del servidor tolerados antes de apartar un registro (no se borra:
  /// queda en estado "error" y se reintenta al abrir la app o a mano).
  static const maxIntentos = 5;
  static const _tablasSync = {'clientes', 'ventas'};
  static const tiposMovimiento = {'ingreso', 'egreso', 'abono'};

  Database? _db;
  Database get db => _db ?? (throw StateError('La base local no está abierta'));
  final _uuid = const Uuid();

  /// Reloj inyectable (las pruebas lo cambian para simular fechas).
  DateTime Function() reloj = DateTime.now;

  /// Aumenta cada vez que cambian los datos: las pantallas lo escuchan.
  final cambios = ValueNotifier<int>(0);
  void _avisar() => cambios.value++;

  Future<void> open() async {
    const storage = FlutterSecureStorage();
    var key = await storage.read(key: 'db_key');
    if (key == null) {
      final r = Random.secure();
      key = base64UrlEncode(List<int>.generate(32, (_) => r.nextInt(256)));
      await storage.write(key: 'db_key', value: key);
    }
    final path = p.join(await getDatabasesPath(), 'vertex.db');
    _db = await openDatabase(path,
        password: key, version: 1, onCreate: (d, _) => crearEsquema(d));
  }

  /// Solo para pruebas: usa una base ya abierta (sqflite_common_ffi).
  void usarBase(Database d) => _db = d;

  static Future<void> crearEsquema(Database d) async {
    await d.execute('''CREATE TABLE clientes(
      id TEXT PRIMARY KEY,
      nombre TEXT NOT NULL, nombre_ts TEXT NOT NULL,
      telefono TEXT NOT NULL DEFAULT '', telefono_ts TEXT NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0, deleted_ts TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      sync TEXT NOT NULL DEFAULT 'pendiente')''');
    await d.execute('''CREATE TABLE ventas(
      id TEXT PRIMARY KEY,
      cliente_id TEXT,
      concepto TEXT NOT NULL,
      monto REAL NOT NULL CHECK (monto > 0),
      tipo TEXT NOT NULL CHECK (tipo IN ('ingreso','egreso','abono')),
      credito INTEGER NOT NULL DEFAULT 0,
      fecha TEXT NOT NULL,
      sync TEXT NOT NULL DEFAULT 'pendiente')''');
    await d.execute('CREATE INDEX ventas_fecha_idx ON ventas(fecha)');
    await d.execute('CREATE INDEX ventas_cliente_idx ON ventas(cliente_id)');
    await d.execute('''CREATE TABLE cola_sync(
      n INTEGER PRIMARY KEY AUTOINCREMENT,
      tabla TEXT NOT NULL,
      registro_id TEXT NOT NULL,
      payload TEXT NOT NULL,
      creado TEXT NOT NULL,
      estado TEXT NOT NULL DEFAULT 'pendiente',
      intentos INTEGER NOT NULL DEFAULT 0,
      proximo_intento TEXT NOT NULL,
      ultimo_error TEXT)''');
    await d.execute(
        'CREATE INDEX cola_estado_idx ON cola_sync(estado, proximo_intento)');
    await d.execute('CREATE INDEX cola_registro_idx ON cola_sync(registro_id)');
    await d.execute('''CREATE TABLE preguntas_ia(
      id TEXT PRIMARY KEY,
      pregunta TEXT NOT NULL,
      respuesta TEXT,
      estado TEXT NOT NULL,
      creado TEXT NOT NULL)''');
    await d.execute(
        'CREATE TABLE ajustes(clave TEXT PRIMARY KEY, valor TEXT NOT NULL)');
  }

  String newId() => _uuid.v4();
  String _ahora() => isoUtc(reloj());

  static int _int(List<Map<String, Object?>> r) =>
      r.isEmpty ? 0 : ((r.first.values.first as num?)?.toInt() ?? 0);
  static double _dbl(Object? v) => (v as num?)?.toDouble() ?? 0;

  void _validarTabla(String tabla) {
    if (!_tablasSync.contains(tabla)) throw ArgumentError('tabla');
  }

  // ---------------------------------------------------------------- ajustes
  Future<String?> ajuste(String clave) async {
    final r = await db.query('ajustes', where: 'clave = ?', whereArgs: [clave]);
    return r.isEmpty ? null : r.first['valor'] as String;
  }

  Future<void> setAjuste(String clave, String valor) => db.insert(
      'ajustes', {'clave': clave, 'valor': valor},
      conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> borrarAjuste(String clave) =>
      db.delete('ajustes', where: 'clave = ?', whereArgs: [clave]);

  // ------------------------------------------------------------------- cola
  Future<void> _enqueue(DatabaseExecutor d, String tabla, String id,
      Map<String, Object?> payload) {
    final ahora = _ahora();
    return d.insert('cola_sync', {
      'tabla': tabla,
      'registro_id': id,
      'payload': jsonEncode(payload),
      'creado': ahora,
      'proximo_intento': ahora,
    });
  }

  /// Lo que toca enviar ahora (pendiente y con su espera cumplida), en orden.
  Future<List<Map<String, Object?>>> colaLista() => db.query('cola_sync',
      where: "estado = 'pendiente' AND proximo_intento <= ?",
      whereArgs: [_ahora()],
      orderBy: 'n');

  /// El servidor confirmó: sale de la cola. El registro queda "enviado" solo
  /// si no tiene otros cambios esperando.
  Future<void> confirmarEnvio(int n, String tabla, String id) async {
    _validarTabla(tabla);
    await db.transaction((t) async {
      await t.delete('cola_sync', where: 'n = ?', whereArgs: [n]);
      final quedan = _int(await t.rawQuery(
          'SELECT COUNT(*) FROM cola_sync WHERE registro_id = ?', [id]));
      if (quedan == 0) {
        await t.update(tabla, {'sync': 'enviado'},
            where: 'id = ?', whereArgs: [id]);
      }
    });
  }

  /// El servidor rechazó el registro: se reintenta con espera creciente y,
  /// tras [maxIntentos], queda en "error" (NO se borra).
  /// [codigo] es un código técnico corto, nunca datos del cliente.
  Future<void> marcarFallo(
      int n, String tabla, String id, int intentosPrevios, String codigo) async {
    _validarTabla(tabla);
    final intentos = intentosPrevios + 1;
    final agotado = intentos >= maxIntentos;
    await db.transaction((t) async {
      await t.update(
          'cola_sync',
          {
            'intentos': intentos,
            'ultimo_error': codigo.length > 40 ? codigo.substring(0, 40) : codigo,
            'estado': agotado ? 'error' : 'pendiente',
            'proximo_intento':
                isoUtc(reloj().add(esperaReintento(intentos))),
          },
          where: 'n = ?',
          whereArgs: [n]);
      if (agotado) {
        await t.update(tabla, {'sync': 'error'},
            where: 'id = ?', whereArgs: [id]);
      }
    });
  }

  /// Vuelve a poner en cola los registros apartados por error.
  Future<int> reintentarErrores() async {
    final ahora = _ahora();
    final n = await db.transaction((t) async {
      final c = await t.rawUpdate(
          "UPDATE cola_sync SET estado = 'pendiente', intentos = 0, "
          "proximo_intento = ? WHERE estado = 'error'",
          [ahora]);
      // También adelanta los que esperaban su turno.
      await t.rawUpdate(
          "UPDATE cola_sync SET proximo_intento = ? WHERE estado = 'pendiente'",
          [ahora]);
      await t.rawUpdate(
          "UPDATE clientes SET sync = 'pendiente' WHERE sync = 'error'");
      await t.rawUpdate(
          "UPDATE ventas SET sync = 'pendiente' WHERE sync = 'error'");
      return c;
    });
    if (n > 0) _avisar();
    return n;
  }

  Future<int> pendientes() async => _int(await db.rawQuery(
      "SELECT COUNT(*) FROM cola_sync WHERE estado = 'pendiente'"));

  Future<int> conError() async => _int(await db
      .rawQuery("SELECT COUNT(*) FROM cola_sync WHERE estado = 'error'"));

  // --------------------------------------------------------------- clientes
  /// Crea o edita. En una edición solo cambia la marca de tiempo de los
  /// campos que realmente cambiaron (conflictos por campo).
  Future<String> saveCliente(String nombre, String telefono,
      {String? id}) async {
    final cid = id ?? newId();
    final ts = _ahora();
    var cambio = false;
    await db.transaction((t) async {
      final prev =
          await t.query('clientes', where: 'id = ?', whereArgs: [cid]);
      final Map<String, Object?> row;
      if (prev.isEmpty) {
        row = {
          'id': cid,
          'nombre': nombre,
          'nombre_ts': ts,
          'telefono': telefono,
          'telefono_ts': ts,
          'deleted': 0,
          'deleted_ts': ts,
          'updated_at': ts,
          'sync': 'pendiente',
        };
        await t.insert('clientes', row);
      } else {
        row = Map<String, Object?>.of(prev.first);
        if (row['nombre'] != nombre) {
          row['nombre'] = nombre;
          row['nombre_ts'] = ts;
          cambio = true;
        }
        if (row['telefono'] != telefono) {
          row['telefono'] = telefono;
          row['telefono_ts'] = ts;
          cambio = true;
        }
        if (!cambio) return;
        row['updated_at'] = ts;
        row['sync'] = 'pendiente';
        await t.update('clientes', row, where: 'id = ?', whereArgs: [cid]);
      }
      cambio = true;
      await _enqueue(t, 'clientes', cid, ClienteCampos.fromLocal(row).toRemote());
    });
    if (cambio) _avisar();
    return cid;
  }

  /// Borrado lógico: así el borrado también se sincroniza. Sus movimientos se
  /// conservan (las ventas nunca se borran).
  Future<void> deleteCliente(String id) async {
    final ts = _ahora();
    await db.transaction((t) async {
      final prev = await t.query('clientes', where: 'id = ?', whereArgs: [id]);
      if (prev.isEmpty) return;
      final row = Map<String, Object?>.of(prev.first)
        ..['deleted'] = 1
        ..['deleted_ts'] = ts
        ..['updated_at'] = ts
        ..['sync'] = 'pendiente';
      await t.update('clientes', row, where: 'id = ?', whereArgs: [id]);
      await _enqueue(t, 'clientes', id, ClienteCampos.fromLocal(row).toRemote());
    });
    _avisar();
  }

  static const _saldoSql =
      "COALESCE((SELECT SUM(CASE WHEN v.tipo = 'ingreso' AND v.credito = 1 "
      "THEN v.monto WHEN v.tipo = 'abono' THEN -v.monto ELSE 0 END) "
      'FROM ventas v WHERE v.cliente_id = c.id), 0)';

  /// Clientes activos con su saldo pendiente.
  Future<List<Map<String, Object?>>> clientes() => db.rawQuery(
      'SELECT c.id, c.nombre, c.telefono, c.sync, $_saldoSql AS saldo '
      'FROM clientes c WHERE c.deleted = 0 ORDER BY c.nombre COLLATE NOCASE');

  Future<Map<String, Object?>?> cliente(String id) async {
    final r = await db.rawQuery(
        'SELECT c.id, c.nombre, c.telefono, c.sync, c.deleted, '
        '$_saldoSql AS saldo FROM clientes c WHERE c.id = ?',
        [id]);
    return r.isEmpty ? null : r.first;
  }

  Future<List<ClienteSaldo>> clientesConSaldo() async => [
        for (final c in await clientes())
          ClienteSaldo(
            id: c['id'] as String,
            nombre: c['nombre'] as String,
            telefono: (c['telefono'] as String?) ?? '',
            saldo: _dbl(c['saldo']),
          )
      ];

  // ------------------------------------------- ventas, gastos y abonos
  /// Solo se agregan. tipo: 'ingreso' (venta), 'egreso' (gasto) o 'abono'
  /// (pago de una deuda). [credito] = venta fiada (queda por cobrar).
  Future<String> saveMovimiento(String concepto, double monto,
      {String tipo = 'ingreso', bool credito = false, String? clienteId}) async {
    if (!tiposMovimiento.contains(tipo)) throw ArgumentError('tipo');
    if (!monto.isFinite || monto <= 0) throw ArgumentError('monto');
    if (concepto.trim().isEmpty) throw ArgumentError('concepto');
    final fiado = tipo == 'ingreso' && credito;
    if ((fiado || tipo == 'abono') && clienteId == null) {
      throw ArgumentError('cliente');
    }
    final id = newId();
    final row = <String, Object?>{
      'id': id,
      'cliente_id': tipo == 'egreso' ? null : clienteId,
      'concepto': concepto.trim(),
      'monto': monto,
      'tipo': tipo,
      'credito': fiado ? 1 : 0,
      'fecha': _ahora(),
    };
    await db.transaction((t) async {
      await t.insert('ventas', {...row, 'sync': 'pendiente'});
      await _enqueue(t, 'ventas', id, {...row, 'credito': fiado});
    });
    _avisar();
    return id;
  }

  Future<List<Map<String, Object?>>> movimientos(
          {String? clienteId, int limite = 300}) =>
      db.rawQuery(
          'SELECT v.*, c.nombre AS cliente_nombre FROM ventas v '
          'LEFT JOIN clientes c ON c.id = v.cliente_id '
          '${clienteId == null ? '' : 'WHERE v.cliente_id = ? '}'
          'ORDER BY v.fecha DESC LIMIT ?',
          [if (clienteId != null) clienteId, limite]);

  /// Ventas (tipo ingreso) desde una fecha local: (total, cantidad).
  Future<(double, int)> ventasDesde(DateTime desdeLocal) async {
    final r = await db.rawQuery(
        "SELECT COALESCE(SUM(monto), 0) s, COUNT(*) c FROM ventas "
        "WHERE tipo = 'ingreso' AND fecha >= ?",
        [isoUtc(desdeLocal)]);
    return (_dbl(r.first['s']), (r.first['c'] as num?)?.toInt() ?? 0);
  }

  /// Totales del mes en curso (el mes se mide en hora LOCAL de Colombia).
  Future<Resumen> resumenMes() async {
    final now = reloj();
    final ini = isoUtc(DateTime(now.year, now.month));
    final r = (await db.rawQuery(
            "SELECT COALESCE(SUM(CASE WHEN tipo = 'ingreso' THEN monto END), 0) ing, "
            "COUNT(CASE WHEN tipo = 'ingreso' THEN 1 END) ning, "
            "COALESCE(SUM(CASE WHEN tipo = 'egreso' THEN monto END), 0) egr, "
            "COUNT(CASE WHEN tipo = 'egreso' THEN 1 END) negr "
            'FROM ventas WHERE fecha >= ?',
            [ini]))
        .first;
    final deuda = (await db.rawQuery(
            'SELECT COALESCE(SUM(saldo), 0) total, COUNT(*) n FROM ('
            'SELECT $_saldoSql AS saldo FROM clientes c WHERE c.deleted = 0'
            ') WHERE saldo > 0'))
        .first;
    final nClientes = _int(
        await db.rawQuery('SELECT COUNT(*) FROM clientes WHERE deleted = 0'));
    return Resumen(
      ingresos: _dbl(r['ing']),
      nIngresos: (r['ning'] as num?)?.toInt() ?? 0,
      egresos: _dbl(r['egr']),
      nEgresos: (r['negr'] as num?)?.toInt() ?? 0,
      porCobrar: _dbl(deuda['total']),
      nDeudores: (deuda['n'] as num?)?.toInt() ?? 0,
      nClientes: nClientes,
    );
  }

  Future<List<TopCliente>> topClientesMes({int limite = 3}) async {
    final now = reloj();
    final r = await db.rawQuery(
        'SELECT c.nombre, SUM(v.monto) total FROM ventas v '
        'JOIN clientes c ON c.id = v.cliente_id '
        "WHERE v.tipo = 'ingreso' AND v.fecha >= ? AND c.deleted = 0 "
        'GROUP BY v.cliente_id ORDER BY total DESC LIMIT ?',
        [isoUtc(DateTime(now.year, now.month)), limite]);
    return [for (final x in r) TopCliente(x['nombre'] as String, _dbl(x['total']))];
  }

  Future<DatosAsistente> datosAsistente() async {
    final now = reloj();
    final hoy = DateTime(now.year, now.month, now.day);
    final lunes = hoy.subtract(Duration(days: hoy.weekday - 1));
    final (vHoy, nHoy) = await ventasDesde(hoy);
    final (vSem, nSem) = await ventasDesde(lunes);
    return DatosAsistente(
      mes: await resumenMes(),
      ventasHoy: vHoy,
      nVentasHoy: nHoy,
      ventasSemana: vSem,
      nVentasSemana: nSem,
      clientes: await clientesConSaldo(),
      topClientes: await topClientesMes(),
    );
  }

  // ------------------------------------------ cambios que llegan de la nube
  /// Une clientes descargados con los locales, campo por campo.
  Future<void> aplicarClientesRemotos(List<Map<String, dynamic>> filas) async {
    if (filas.isEmpty) return;
    await db.transaction((t) async {
      for (final f in filas) {
        final ClienteCampos remoto;
        try {
          remoto = ClienteCampos.fromRemote(f);
        } catch (_) {
          continue; // fila incompleta: se ignora sin bloquear el resto
        }
        final prev =
            await t.query('clientes', where: 'id = ?', whereArgs: [remoto.id]);
        if (prev.isEmpty) {
          await t.insert('clientes', {...remoto.toLocalRow(), 'sync': 'enviado'});
        } else {
          final unido = ClienteCampos.fromLocal(prev.first).merge(remoto);
          await t.update(
              'clientes', {...unido.toLocalRow(), 'sync': prev.first['sync']},
              where: 'id = ?', whereArgs: [remoto.id]);
        }
      }
    });
    _avisar();
  }

  /// Movimientos descargados: se agregan; si ya existen se ignoran.
  Future<void> aplicarVentasRemotas(List<Map<String, dynamic>> filas) async {
    if (filas.isEmpty) return;
    final b = db.batch();
    for (final f in filas) {
      final monto = (f['monto'] as num?)?.toDouble() ?? 0;
      final tipo = f['tipo'];
      final fecha = DateTime.tryParse('${f['fecha']}');
      if (monto <= 0 || !tiposMovimiento.contains(tipo) || fecha == null) {
        continue;
      }
      b.insert(
          'ventas',
          {
            'id': f['id'],
            'cliente_id': f['cliente_id'],
            'concepto': '${f['concepto'] ?? ''}',
            'monto': monto,
            'tipo': tipo,
            'credito': f['credito'] == true ? 1 : 0,
            'fecha': isoUtc(fecha),
            'sync': 'enviado',
          },
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await b.commit(noResult: true);
    _avisar();
  }

  // ------------------------------------------------ preguntas para la IA
  Future<String> guardarPreguntaIA(String pregunta, {String? respuesta}) async {
    final id = newId();
    await db.insert('preguntas_ia', {
      'id': id,
      'pregunta': pregunta,
      'respuesta': respuesta,
      'estado': respuesta == null ? 'pendiente' : 'respondida',
      'creado': _ahora(),
    });
    _avisar();
    return id;
  }

  Future<List<Map<String, Object?>>> preguntasIA({int limite = 20}) => db.query(
      'preguntas_ia',
      orderBy: 'creado DESC',
      limit: limite);

  Future<List<Map<String, Object?>>> preguntasIAPendientes({int limite = 3}) =>
      db.query('preguntas_ia',
          where: "estado = 'pendiente'", orderBy: 'creado', limit: limite);

  Future<void> responderPreguntaIA(String id, String respuesta) async {
    await db.update('preguntas_ia', {'respuesta': respuesta, 'estado': 'respondida'},
        where: 'id = ?', whereArgs: [id]);
    _avisar();
  }

  // ------------------------------------------------ derechos del titular
  /// Supresión (Ley 1581): borra los datos de ESTE celular. Lo que ya está
  /// en la nube se suprime escribiendo al canal de derechos.
  Future<void> borrarDatosLocales() async {
    await db.transaction((t) async {
      for (final tabla in ['cola_sync', 'ventas', 'clientes', 'preguntas_ia']) {
        await t.delete(tabla);
      }
      await t.delete('ajustes', where: "clave LIKE 'pull_%'");
    });
    _avisar();
  }
}
