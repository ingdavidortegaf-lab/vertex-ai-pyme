import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi;
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../domain/conflictos.dart';
import '../domain/documentos.dart';
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
  static const _tablasSync = {'clientes', 'ventas', 'productos', 'inventario'};
  static const motivosInventario = {'venta', 'entrada', 'ajuste'};
  static const tiposMovimiento = {'ingreso', 'egreso', 'abono'};

  Database? _db;
  Database get db => _db ?? (throw StateError('La base local no está abierta'));
  final _uuid = const Uuid();

  /// Reloj inyectable (las pruebas lo cambian para simular fechas).
  DateTime Function() reloj = DateTime.now;

  /// Aumenta cada vez que cambian los datos: las pantallas lo escuchan.
  final cambios = ValueNotifier<int>(0);
  void _avisar() => cambios.value++;

  /// En el PC (Windows) se usa SQLite por FFI en la carpeta privada de la
  /// app. SQLCipher (cifrado) solo existe para Android e iOS; en el PC la
  /// protección es la de la cuenta de Windows.
  static bool get esEscritorio =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  Future<void> open() async {
    if (esEscritorio) {
      sqfliteFfiInit();
      final dir = await getApplicationSupportDirectory();
      _db = await databaseFactoryFfi.openDatabase(p.join(dir.path, 'vertex.db'),
          options: OpenDatabaseOptions(
            version: 4,
            onCreate: (d, _) => crearEsquema(d),
            onUpgrade: (d, viejo, _) async {
              if (viejo < 2) await crearInventario(d);
              if (viejo < 3) await crearHerramientas(d);
              if (viejo < 4) await agregarCodigoYUnidad(d);
            },
          ));
      return;
    }
    const storage = FlutterSecureStorage();
    var key = await storage.read(key: 'db_key');
    if (key == null) {
      final r = Random.secure();
      key = base64UrlEncode(List<int>.generate(32, (_) => r.nextInt(256)));
      await storage.write(key: 'db_key', value: key);
    }
    final path = p.join(await getDatabasesPath(), 'vertex.db');
    _db = await openDatabase(path,
        password: key,
        version: 4,
        onCreate: (d, _) => crearEsquema(d),
        onUpgrade: (d, viejo, _) async {
          // Los datos anteriores se conservan en cada versión.
          if (viejo < 2) await crearInventario(d); // v2: inventario
          if (viejo < 3) await crearHerramientas(d); // v3: cotizaciones, proveedores
          if (viejo < 4) await agregarCodigoYUnidad(d); // v4: código de barras y peso
        });
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
    await crearInventario(d);
    await crearHerramientas(d);
    await agregarCodigoYUnidad(d);
  }

  /// v4: código de barras y unidad de venta (und, kg, lb) por producto.
  static Future<void> agregarCodigoYUnidad(Database d) async {
    const inicio = '1970-01-01T00:00:00.000Z';
    await d.execute("ALTER TABLE productos ADD COLUMN codigo TEXT NOT NULL DEFAULT ''");
    await d.execute(
        "ALTER TABLE productos ADD COLUMN codigo_ts TEXT NOT NULL DEFAULT '$inicio'");
    await d.execute("ALTER TABLE productos ADD COLUMN unidad TEXT NOT NULL DEFAULT 'und'");
    await d.execute(
        "ALTER TABLE productos ADD COLUMN unidad_ts TEXT NOT NULL DEFAULT '$inicio'");
    await d.execute('CREATE INDEX productos_codigo_idx ON productos(codigo)');
  }

  /// Cotizaciones y proveedores. Viven solo en el celular (no se
  /// sincronizan): son borradores de trabajo del tendero.
  static Future<void> crearHerramientas(Database d) async {
    await d.execute('''CREATE TABLE cotizaciones(
      id TEXT PRIMARY KEY,
      cliente_id TEXT,
      cliente_nombre TEXT,
      items TEXT NOT NULL,
      total REAL NOT NULL,
      estado TEXT NOT NULL DEFAULT 'abierta',
      venta_id TEXT,
      creado TEXT NOT NULL)''');
    await d.execute('''CREATE TABLE proveedores(
      id TEXT PRIMARY KEY,
      nombre TEXT NOT NULL,
      telefono TEXT NOT NULL DEFAULT '',
      creado TEXT NOT NULL)''');
  }

  /// Productos (campos con marca de tiempo, como clientes) y movimientos de
  /// inventario (solo se agregan; el stock es la suma de las cantidades).
  static Future<void> crearInventario(Database d) async {
    await d.execute('''CREATE TABLE productos(
      id TEXT PRIMARY KEY,
      nombre TEXT NOT NULL, nombre_ts TEXT NOT NULL,
      precio REAL NOT NULL DEFAULT 0, precio_ts TEXT NOT NULL,
      costo REAL NOT NULL DEFAULT 0, costo_ts TEXT NOT NULL,
      minimo REAL NOT NULL DEFAULT 0, minimo_ts TEXT NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0, deleted_ts TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      sync TEXT NOT NULL DEFAULT 'pendiente')''');
    await d.execute('''CREATE TABLE inventario(
      id TEXT PRIMARY KEY,
      producto_id TEXT NOT NULL,
      cantidad REAL NOT NULL CHECK (cantidad <> 0),
      motivo TEXT NOT NULL CHECK (motivo IN ('venta','entrada','ajuste')),
      venta_id TEXT,
      precio_unit REAL,
      costo_unit REAL,
      fecha TEXT NOT NULL,
      sync TEXT NOT NULL DEFAULT 'pendiente')''');
    await d.execute('CREATE INDEX inventario_producto_idx ON inventario(producto_id)');
    await d.execute('CREATE INDEX inventario_fecha_idx ON inventario(motivo, fecha)');
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
      for (final tabla in const ['ventas', 'productos', 'inventario']) {
        await t.rawUpdate(
            "UPDATE $tabla SET sync = 'pendiente' WHERE sync = 'error'");
      }
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
    final ini = DateTime(now.year, now.month);
    final fin = DateTime(now.year, now.month + 1);
    return DatosAsistente(
      mes: await resumenMes(),
      ventasHoy: vHoy,
      nVentasHoy: nHoy,
      ventasSemana: vSem,
      nVentasSemana: nSem,
      clientes: await clientesConSaldo(),
      topClientes: await topClientesMes(),
      productos: await productos(),
      topProductos: await topProductos(ini, fin),
      gananciaProductosMes: (await resumenPeriodo(ini, fin)).gananciaProductos,
      nombreNegocio: await ajuste('negocio_nombre') ?? '',
      metaMensual: double.tryParse(await ajuste('negocio_meta') ?? '') ?? 0,
    );
  }

  // ------------------------------------------------------------ inventario
  static const _stockSql =
      'COALESCE((SELECT SUM(i.cantidad) FROM inventario i '
      'WHERE i.producto_id = p.id), 0)';

  Future<List<ProductoStock>> productos() async {
    final r = await db.rawQuery(
        'SELECT p.*, $_stockSql AS stock FROM productos p WHERE p.deleted = 0 '
        'ORDER BY p.nombre COLLATE NOCASE');
    return [
      for (final x in r)
        ProductoStock(
          id: x['id'] as String,
          nombre: x['nombre'] as String,
          precio: _dbl(x['precio']),
          costo: _dbl(x['costo']),
          minimo: _dbl(x['minimo']),
          stock: _dbl(x['stock']),
          sync: x['sync'] as String? ?? 'pendiente',
          codigo: (x['codigo'] as String?) ?? '',
          unidad: (x['unidad'] as String?) ?? 'und',
        )
    ];
  }

  Map<String, Object?> _filaInventario(String id, String productoId,
          double cantidad, String motivo,
          {String? ventaId, double? precio, double? costo}) =>
      {
        'id': id,
        'producto_id': productoId,
        'cantidad': cantidad,
        'motivo': motivo,
        'venta_id': ventaId,
        'precio_unit': precio,
        'costo_unit': costo,
        'fecha': _ahora(),
      };

  Future<void> _insertarInventario(
      DatabaseExecutor t, Map<String, Object?> fila) async {
    await t.insert('inventario', {...fila, 'sync': 'pendiente'});
    await _enqueue(t, 'inventario', fila['id'] as String, fila);
  }

  /// Crea o edita un producto. Solo cambia la marca de tiempo de los campos
  /// que cambiaron. [stockInicial] (al crear) se registra como entrada.
  Future<String> saveProducto(String nombre,
      {required double precio,
      double costo = 0,
      double minimo = 0,
      double stockInicial = 0,
      String codigo = '',
      String unidad = 'und',
      String? id}) async {
    if (nombre.trim().isEmpty) throw ArgumentError('nombre');
    if (!ProductoCampos.unidades.contains(unidad)) throw ArgumentError('unidad');
    if (!precio.isFinite || precio < 0 || !costo.isFinite || costo < 0) {
      throw ArgumentError('precio');
    }
    final pid = id ?? newId();
    final ts = _ahora();
    var cambio = false;
    await db.transaction((t) async {
      final prev = await t.query('productos', where: 'id = ?', whereArgs: [pid]);
      final nuevos = <String, Object>{
        'nombre': nombre.trim(),
        'precio': precio,
        'costo': costo,
        'minimo': minimo < 0 ? 0 : minimo,
        'codigo': codigo.replaceAll(RegExp(r'\s'), ''),
        'unidad': unidad,
      };
      final Map<String, Object?> row;
      if (prev.isEmpty) {
        row = {
          'id': pid,
          ...nuevos,
          'deleted': 0,
          for (final c in ProductoCampos.campos) '${c}_ts': ts,
          'updated_at': ts,
          'sync': 'pendiente',
        };
        await t.insert('productos', row);
        if (stockInicial > 0) {
          await _insertarInventario(
              t, _filaInventario(newId(), pid, stockInicial, 'entrada', costo: costo));
        }
      } else {
        row = Map<String, Object?>.of(prev.first);
        for (final e in nuevos.entries) {
          if (row[e.key] != e.value) {
            row[e.key] = e.value;
            row['${e.key}_ts'] = ts;
            cambio = true;
          }
        }
        if (!cambio) return;
        row['updated_at'] = ts;
        row['sync'] = 'pendiente';
        await t.update('productos', row, where: 'id = ?', whereArgs: [pid]);
      }
      cambio = true;
      await _enqueue(t, 'productos', pid, ProductoCampos.fromLocal(row).toRemote());
    });
    if (cambio) _avisar();
    return pid;
  }

  Future<void> deleteProducto(String id) async {
    final ts = _ahora();
    await db.transaction((t) async {
      final prev = await t.query('productos', where: 'id = ?', whereArgs: [id]);
      if (prev.isEmpty) return;
      final row = Map<String, Object?>.of(prev.first)
        ..['deleted'] = 1
        ..['deleted_ts'] = ts
        ..['updated_at'] = ts
        ..['sync'] = 'pendiente';
      await t.update('productos', row, where: 'id = ?', whereArgs: [id]);
      await _enqueue(t, 'productos', id, ProductoCampos.fromLocal(row).toRemote());
    });
    _avisar();
  }

  /// Entrada de mercancía (cantidad > 0) o ajuste por conteo (+/−).
  Future<void> moverStock(String productoId, double cantidad,
      {String motivo = 'entrada', double? costo}) async {
    if (!cantidad.isFinite || cantidad == 0) throw ArgumentError('cantidad');
    if (motivo == 'entrada' && cantidad < 0) throw ArgumentError('cantidad');
    if (!motivosInventario.contains(motivo) || motivo == 'venta') {
      throw ArgumentError('motivo');
    }
    await db.transaction((t) => _insertarInventario(
        t, _filaInventario(newId(), productoId, cantidad, motivo, costo: costo)));
    _avisar();
  }

  /// Venta con productos: un movimiento de venta por el total y una salida de
  /// inventario por cada producto, todo en una sola transacción.
  Future<String> saveVentaProductos(List<ItemVenta> items,
      {bool fiado = false, String? clienteId, String? concepto}) async {
    final validos = items.where((i) => i.cantidad > 0).toList();
    if (validos.isEmpty) throw ArgumentError('items');
    if (fiado && clienteId == null) throw ArgumentError('cliente');
    final total = validos.fold(0.0, (s, i) => s + i.total);
    if (total <= 0) throw ArgumentError('monto');
    String cant(double c) =>
        c == c.roundToDouble() ? c.toInt().toString() : c.toString();
    var texto = concepto?.trim().isNotEmpty == true
        ? concepto!.trim()
        : validos.map((i) => '${cant(i.cantidad)} × ${i.nombre}').join(', ');
    if (texto.length > 120) texto = '${texto.substring(0, 117)}…';
    final id = newId();
    final venta = <String, Object?>{
      'id': id,
      'cliente_id': clienteId,
      'concepto': texto,
      'monto': total,
      'tipo': 'ingreso',
      'credito': fiado ? 1 : 0,
      'fecha': _ahora(),
    };
    await db.transaction((t) async {
      await t.insert('ventas', {...venta, 'sync': 'pendiente'});
      await _enqueue(t, 'ventas', id, {...venta, 'credito': fiado});
      for (final i in validos) {
        await _insertarInventario(
            t,
            _filaInventario(newId(), i.productoId, -i.cantidad, 'venta',
                ventaId: id, precio: i.precio, costo: i.costo));
      }
    });
    _avisar();
    return id;
  }

  // ----------------------------------------------------------- herramientas
  Future<PerfilNegocio> perfilNegocio() async => PerfilNegocio(
        nombre: await ajuste('negocio_nombre') ?? '',
        tipo: await ajuste('negocio_tipo') ?? '',
        nit: await ajuste('negocio_nit') ?? '',
        direccion: await ajuste('negocio_direccion') ?? '',
        telefono: await ajuste('negocio_telefono') ?? '',
        meta: double.tryParse(await ajuste('negocio_meta') ?? '') ?? 0,
        logo: await ajuste('negocio_logo') ?? '',
      );

  /// Una venta con el nombre y celular del cliente.
  Future<Map<String, Object?>?> movimiento(String id) async {
    final r = await db.rawQuery(
        'SELECT v.*, c.nombre AS cliente_nombre, c.telefono AS cliente_telefono '
        'FROM ventas v LEFT JOIN clientes c ON c.id = v.cliente_id WHERE v.id = ?',
        [id]);
    return r.isEmpty ? null : r.first;
  }

  /// Líneas de una venta: sus productos, o el concepto si no tuvo productos.
  Future<List<LineaDoc>> lineasDeVenta(String ventaId) async {
    final r = await db.rawQuery(
        'SELECT p.nombre, p.unidad, -i.cantidad AS cant, COALESCE(i.precio_unit, 0) AS precio '
        'FROM inventario i JOIN productos p ON p.id = i.producto_id '
        "WHERE i.venta_id = ? AND i.motivo = 'venta' ORDER BY i.rowid",
        [ventaId]);
    if (r.isNotEmpty) {
      return [
        for (final x in r)
          LineaDoc(x['nombre'] as String, _dbl(x['cant']), _dbl(x['precio']),
              (x['unidad'] as String?) ?? 'und')
      ];
    }
    final v = await movimiento(ventaId);
    if (v == null) return const [];
    return [LineaDoc(v['concepto'] as String, 1, _dbl(v['monto']))];
  }

  Future<List<Map<String, Object?>>> proveedores() =>
      db.query('proveedores', orderBy: 'nombre COLLATE NOCASE');

  Future<String> saveProveedor(String nombre, String telefono, {String? id}) async {
    final pid = id ?? newId();
    await db.insert(
        'proveedores',
        {'id': pid, 'nombre': nombre.trim(), 'telefono': telefono, 'creado': _ahora()},
        conflictAlgorithm: ConflictAlgorithm.replace);
    _avisar();
    return pid;
  }

  Future<void> deleteProveedor(String id) async {
    await db.delete('proveedores', where: 'id = ?', whereArgs: [id]);
    _avisar();
  }

  /// Llegó la mercancía: entrada de inventario por cada producto y, si se
  /// pide, el gasto de la compra; todo en una sola transacción.
  Future<void> recibirPedido(List<(String productoId, double cantidad, double costo)> items,
      {String? conceptoGasto}) async {
    final validos = items.where((x) => x.$2 > 0).toList();
    if (validos.isEmpty) throw ArgumentError('items');
    final total = validos.fold(0.0, (s, x) => s + x.$2 * x.$3);
    await db.transaction((t) async {
      for (final (pid, cant, costo) in validos) {
        await _insertarInventario(
            t, _filaInventario(newId(), pid, cant, 'entrada', costo: costo));
      }
      if (conceptoGasto != null && total > 0) {
        final id = newId();
        var c = conceptoGasto.trim().isEmpty ? 'Compra de mercancía' : conceptoGasto.trim();
        if (c.length > 120) c = '${c.substring(0, 117)}…';
        final row = <String, Object?>{
          'id': id,
          'cliente_id': null,
          'concepto': c,
          'monto': total,
          'tipo': 'egreso',
          'credito': 0,
          'fecha': _ahora(),
        };
        await t.insert('ventas', {...row, 'sync': 'pendiente'});
        await _enqueue(t, 'ventas', id, {...row, 'credito': false});
      }
    });
    _avisar();
  }

  Future<List<Map<String, Object?>>> cotizaciones() =>
      db.query('cotizaciones', orderBy: 'creado DESC', limit: 100);

  Future<String> saveCotizacion(List<ItemVenta> items,
      {String? clienteId, String? clienteNombre}) async {
    final validos = items.where((i) => i.cantidad > 0).toList();
    if (validos.isEmpty) throw ArgumentError('items');
    final id = newId();
    await db.insert('cotizaciones', {
      'id': id,
      'cliente_id': clienteId,
      'cliente_nombre': clienteNombre,
      'items': jsonEncode([
        for (final i in validos)
          {
            'producto_id': i.productoId,
            'nombre': i.nombre,
            'cantidad': i.cantidad,
            'precio': i.precio,
            'costo': i.costo,
            'unidad': i.unidad,
          }
      ]),
      'total': validos.fold<double>(0, (s, i) => s + i.total),
      'creado': _ahora(),
    });
    _avisar();
    return id;
  }

  static List<ItemVenta> itemsCotizacion(Map<String, Object?> c) => [
        for (final x in jsonDecode(c['items'] as String) as List)
          ItemVenta(
            productoId: x['producto_id'] as String,
            nombre: x['nombre'] as String,
            cantidad: (x['cantidad'] as num).toDouble(),
            precio: (x['precio'] as num).toDouble(),
            costo: (x['costo'] as num? ?? 0).toDouble(),
            unidad: (x['unidad'] as String?) ?? 'und',
          )
      ];

  /// Convierte la cotización en venta (descuenta inventario) y la marca.
  Future<String> venderCotizacion(String id, {bool fiado = false}) async {
    final r = await db.query('cotizaciones', where: 'id = ?', whereArgs: [id]);
    if (r.isEmpty) throw ArgumentError('cotizacion');
    final c = r.first;
    if (c['estado'] == 'vendida') throw StateError('ya vendida');
    final ventaId = await saveVentaProductos(itemsCotizacion(c),
        fiado: fiado, clienteId: c['cliente_id'] as String?);
    await db.update('cotizaciones', {'estado': 'vendida', 'venta_id': ventaId},
        where: 'id = ?', whereArgs: [id]);
    _avisar();
    return ventaId;
  }

  Future<void> deleteCotizacion(String id) async {
    await db.delete('cotizaciones', where: 'id = ?', whereArgs: [id]);
    _avisar();
  }

  // -------------------------------------------------------------- reportes
  /// Totales entre [desde] y [hasta] (fechas locales; hasta excluido).
  Future<ResumenPeriodo> resumenPeriodo(DateTime desde, DateTime hasta) async {
    final a = isoUtc(desde), b = isoUtc(hasta);
    final r = (await db.rawQuery(
            "SELECT COALESCE(SUM(CASE WHEN tipo = 'ingreso' THEN monto END), 0) ven, "
            "COUNT(CASE WHEN tipo = 'ingreso' THEN 1 END) nven, "
            "COALESCE(SUM(CASE WHEN tipo = 'ingreso' AND credito = 1 THEN monto END), 0) fia, "
            "COALESCE(SUM(CASE WHEN tipo = 'egreso' THEN monto END), 0) gas, "
            "COALESCE(SUM(CASE WHEN tipo = 'abono' THEN monto END), 0) abo "
            'FROM ventas WHERE fecha >= ? AND fecha < ?',
            [a, b]))
        .first;
    final g = await db.rawQuery(
        'SELECT COALESCE(SUM(-cantidad * (COALESCE(precio_unit, 0) - '
        "COALESCE(costo_unit, 0))), 0) FROM inventario WHERE motivo = 'venta' "
        'AND fecha >= ? AND fecha < ?',
        [a, b]);
    final ventas = _dbl(r['ven']), fiado = _dbl(r['fia']);
    return ResumenPeriodo(
      ventas: ventas,
      nVentas: (r['nven'] as num?)?.toInt() ?? 0,
      gastos: _dbl(r['gas']),
      fiado: fiado,
      contado: ventas - fiado,
      abonos: _dbl(r['abo']),
      gananciaProductos: _dbl(g.first.values.first),
    );
  }

  /// Ventas y gastos por día local entre [desde] y [hasta] (días completos).
  Future<List<DiaSerie>> seriePorDia(DateTime desde, DateTime hasta) async {
    final r = await db.rawQuery(
        "SELECT tipo, monto, fecha FROM ventas WHERE tipo IN ('ingreso','egreso') "
        'AND fecha >= ? AND fecha < ?',
        [isoUtc(desde), isoUtc(hasta)]);
    final ven = <DateTime, double>{}, gas = <DateTime, double>{};
    for (final x in r) {
      final f = DateTime.parse(x['fecha'] as String).toLocal();
      final d = DateTime(f.year, f.month, f.day);
      final m = x['tipo'] == 'ingreso' ? ven : gas;
      m[d] = (m[d] ?? 0) + _dbl(x['monto']);
    }
    final out = <DiaSerie>[];
    for (var d = DateTime(desde.year, desde.month, desde.day);
        d.isBefore(hasta);
        d = DateTime(d.year, d.month, d.day + 1)) {
      out.add(DiaSerie(d, ven[d] ?? 0, gas[d] ?? 0));
    }
    return out;
  }

  Future<List<TopProducto>> topProductos(DateTime desde, DateTime hasta,
      {int limite = 5}) async {
    final r = await db.rawQuery(
        'SELECT p.nombre, SUM(-i.cantidad) cant, '
        'SUM(-i.cantidad * COALESCE(i.precio_unit, 0)) total '
        'FROM inventario i JOIN productos p ON p.id = i.producto_id '
        "WHERE i.motivo = 'venta' AND i.fecha >= ? AND i.fecha < ? "
        'GROUP BY i.producto_id ORDER BY total DESC LIMIT ?',
        [isoUtc(desde), isoUtc(hasta), limite]);
    return [
      for (final x in r)
        TopProducto(x['nombre'] as String, _dbl(x['cant']), _dbl(x['total']))
    ];
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

  /// Productos descargados: unión campo por campo, como clientes.
  Future<void> aplicarProductosRemotos(List<Map<String, dynamic>> filas) async {
    if (filas.isEmpty) return;
    await db.transaction((t) async {
      for (final f in filas) {
        final ProductoCampos remoto;
        try {
          remoto = ProductoCampos.fromRemote(f);
        } catch (_) {
          continue;
        }
        final prev =
            await t.query('productos', where: 'id = ?', whereArgs: [remoto.id]);
        if (prev.isEmpty) {
          await t.insert('productos', {...remoto.toLocalRow(), 'sync': 'enviado'});
        } else {
          final unido = ProductoCampos.fromLocal(prev.first).merge(remoto);
          await t.update(
              'productos', {...unido.toLocalRow(), 'sync': prev.first['sync']},
              where: 'id = ?', whereArgs: [remoto.id]);
        }
      }
    });
    _avisar();
  }

  /// Movimientos de inventario descargados: se agregan; repetidos se ignoran.
  Future<void> aplicarInventarioRemoto(List<Map<String, dynamic>> filas) async {
    if (filas.isEmpty) return;
    final b = db.batch();
    for (final f in filas) {
      final cantidad = (f['cantidad'] as num?)?.toDouble() ?? 0;
      final fecha = DateTime.tryParse('${f['fecha']}');
      if (cantidad == 0 ||
          !motivosInventario.contains(f['motivo']) ||
          fecha == null ||
          f['producto_id'] is! String) {
        continue;
      }
      b.insert(
          'inventario',
          {
            'id': f['id'],
            'producto_id': f['producto_id'],
            'cantidad': cantidad,
            'motivo': f['motivo'],
            'venta_id': f['venta_id'],
            'precio_unit': (f['precio_unit'] as num?)?.toDouble(),
            'costo_unit': (f['costo_unit'] as num?)?.toDouble(),
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
      for (final tabla in [
        'cola_sync',
        'ventas',
        'clientes',
        'preguntas_ia',
        'inventario',
        'productos',
        'cotizaciones',
        'proveedores'
      ]) {
        await t.delete(tabla);
      }
      await t.delete('ajustes', where: "clave LIKE 'pull_%'");
    });
    _avisar();
  }
}
