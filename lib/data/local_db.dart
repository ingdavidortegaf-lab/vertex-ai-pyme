import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'abrir_base.dart' as base_abrir show abrirBase, esEscritorio;
import 'package:uuid/uuid.dart';
import '../domain/conflictos.dart';
import '../domain/documentos.dart';
import '../domain/identificacion.dart';
import '../domain/legal.dart';
import '../domain/obligaciones.dart';
import '../domain/modo_negocio.dart';
import '../domain/pagos.dart';
import '../domain/resumen.dart';
import '../domain/seguimiento.dart';

part 'local_db_asistente.dart';
part 'local_db_clientes.dart';
part 'local_db_cotizaciones.dart';
part 'local_db_documentos.dart';
part 'local_db_inventario.dart';
part 'local_db_movimientos.dart';
part 'local_db_negocio.dart';
part 'local_db_nube.dart';
part 'local_db_proveedores.dart';

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

  /// Cómo trabaja el negocio (respuestas del registro guiado). Las pantallas
  /// lo escuchan para adaptarse.
  final modo = ValueNotifier<ModoNegocio>(const ModoNegocio());

  /// Tipo de negocio (licorera, droguería…): de ahí salen los ejemplos de
  /// las casillas.
  final tipoNegocio = ValueNotifier<String>('');
  void _avisar() => cambios.value++;

  /// En el PC (Windows) se usa SQLite por FFI en la carpeta privada de la
  /// app. SQLCipher (cifrado) solo existe para Android e iOS; en el PC la
  /// protección es la de la cuenta de Windows.
  /// ¿Corre en un computador? (Windows, Linux o macOS; en la web, no).
  static bool get esEscritorio => base_abrir.esEscritorio;

  Future<void> open() async {
    _db = await base_abrir.abrirBase(
        version: versionEsquema, onCreate: (d, _) => crearEsquema(d), onUpgrade: migrar);
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
    await crearDocumentos(d);
    await agregarPagos(d);
    await crearCuentasPagar(d);
    await agregarTerceros(d);
  }

  /// Versión actual del esquema local.
  static const versionEsquema = 8;

  /// Migraciones: los datos anteriores se conservan en cada versión.
  static Future<void> migrar(Database d, int viejo, int nuevo) async {
    if (viejo < 2) await crearInventario(d); // v2: inventario
    if (viejo < 3) await crearHerramientas(d); // v3: cotizaciones, proveedores
    if (viejo < 4) await agregarCodigoYUnidad(d); // v4: código de barras y peso
    if (viejo < 5) await crearDocumentos(d); // v5: archivo de documentos
    if (viejo < 6) await agregarPagos(d); // v6: medios de pago
    if (viejo < 7) await crearCuentasPagar(d); // v7: lo que se le debe a proveedores
    if (viejo < 8) await agregarTerceros(d); // v8: documentos, correo, terceros y pagos fijos
  }

  /// v8: identificación y correo de clientes y terceros (proveedores,
  /// arrendador, empresas de servicios, empleados), a quién se le pagó cada
  /// gasto, y los pagos fijos del mes (arriendo, luz, internet…).
  static Future<void> agregarTerceros(Database d) async {
    const inicio = '1970-01-01T00:00:00.000Z';
    await d.execute("ALTER TABLE clientes ADD COLUMN tipo_doc TEXT NOT NULL DEFAULT 'CC'");
    await d.execute("ALTER TABLE clientes ADD COLUMN documento TEXT NOT NULL DEFAULT ''");
    await d.execute("ALTER TABLE clientes ADD COLUMN correo TEXT NOT NULL DEFAULT ''");
    await d.execute("ALTER TABLE clientes ADD COLUMN datos_ts TEXT NOT NULL DEFAULT '$inicio'");
    await d.execute("ALTER TABLE proveedores ADD COLUMN tipo_doc TEXT NOT NULL DEFAULT 'NIT'");
    await d.execute("ALTER TABLE proveedores ADD COLUMN documento TEXT NOT NULL DEFAULT ''");
    await d.execute("ALTER TABLE proveedores ADD COLUMN correo TEXT NOT NULL DEFAULT ''");
    await d.execute("ALTER TABLE proveedores ADD COLUMN clase TEXT NOT NULL DEFAULT 'proveedor'");
    await d.execute('ALTER TABLE ventas ADD COLUMN tercero_id TEXT');
    await d.execute('''CREATE TABLE pagos_fijos(
      id TEXT PRIMARY KEY,
      nombre TEXT NOT NULL,
      monto REAL NOT NULL DEFAULT 0,
      dia INTEGER NOT NULL CHECK (dia BETWEEN 1 AND 31),
      tercero_id TEXT,
      activo INTEGER NOT NULL DEFAULT 1,
      creado TEXT NOT NULL)''');
    await d.execute('''CREATE TABLE pagos_fijos_hechos(
      id TEXT PRIMARY KEY,
      fijo_id TEXT NOT NULL REFERENCES pagos_fijos(id),
      periodo TEXT NOT NULL,
      monto REAL NOT NULL CHECK (monto > 0),
      egreso_id TEXT,
      fecha TEXT NOT NULL)''');
    await d.execute('CREATE INDEX pagos_fijos_hechos_idx ON pagos_fijos_hechos(fijo_id, periodo)');
  }

  /// v7: cuentas por pagar a proveedores (la tienda paga una parte del
  /// pedido y el resto queda fiado) y los abonos que se les hacen. Como los
  /// proveedores, viven en este dispositivo; cada abono además queda como
  /// gasto en `ventas` (sí se sincroniza) con su medio de pago.
  static Future<void> crearCuentasPagar(Database d) async {
    await d.execute('''CREATE TABLE cuentas_pagar(
      id TEXT PRIMARY KEY,
      proveedor_id TEXT,
      proveedor_nombre TEXT NOT NULL,
      concepto TEXT NOT NULL,
      total REAL NOT NULL CHECK (total > 0),
      fecha TEXT NOT NULL,
      vence TEXT NOT NULL)''');
    await d.execute('''CREATE TABLE pagos_proveedor(
      id TEXT PRIMARY KEY,
      cuenta_id TEXT NOT NULL REFERENCES cuentas_pagar(id),
      monto REAL NOT NULL CHECK (monto > 0),
      fecha TEXT NOT NULL,
      egreso_id TEXT)''');
    await d.execute('CREATE INDEX pagos_proveedor_cuenta_idx ON pagos_proveedor(cuenta_id)');
  }

  /// v6: medios de pago de cada movimiento (JSON: [{"medio","monto"}]).
  /// Los movimientos anteriores quedan sin pagos y se leen como efectivo.
  static Future<void> agregarPagos(Database d) async {
    await d.execute('ALTER TABLE ventas ADD COLUMN pagos TEXT');
  }

  /// Valida y ordena los pagos de un movimiento. La venta fiada no lleva
  /// pagos. Si no se indicó cómo pagó, es efectivo.
  static List<Pago>? _pagosDe(String tipo, bool fiado, double monto, List<Pago>? pagos) {
    if (tipo == 'ingreso' && fiado) return null;
    final l = normalizarPagos(pagos ?? [Pago('efectivo', monto)]);
    if (problemaPagos(l, monto) != null) throw ArgumentError('pagos');
    return l;
  }

  /// v5: archivo de documentos emitidos (facturas, cotizaciones, cuentas de
  /// cobro, pedidos e informes) con número único y su PDF guardado. Solo en
  /// este dispositivo.
  static Future<void> crearDocumentos(Database d) async {
    await d.execute('''CREATE TABLE documentos(
      id TEXT PRIMARY KEY,
      tipo TEXT NOT NULL,
      numero TEXT NOT NULL UNIQUE,
      ref_id TEXT,
      cliente_id TEXT,
      cliente_nombre TEXT,
      total REAL NOT NULL DEFAULT 0,
      fecha TEXT NOT NULL,
      archivo TEXT,
      resumen TEXT)''');
    await d.execute('CREATE INDEX documentos_ref_idx ON documentos(tipo, ref_id)');
    await d.execute('CREATE INDEX documentos_fecha_idx ON documentos(fecha)');
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

  static const _saldoSql =
      "COALESCE((SELECT SUM(CASE WHEN v.tipo = 'ingreso' AND v.credito = 1 "
      "THEN v.monto WHEN v.tipo = 'abono' THEN -v.monto ELSE 0 END) "
      'FROM ventas v WHERE v.cliente_id = c.id), 0)';

  static const _stockSql =
      'COALESCE((SELECT SUM(i.cantidad) FROM inventario i '
      'WHERE i.producto_id = p.id), 0)';

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

  /// Prefijos de cada tipo de documento.
  static const prefijosDoc = {
    'venta': 'CV', // comprobante de venta (no es factura electrónica DIAN)
    'cotizacion': 'CT',
    'cobro': 'CC',
    'pedido': 'PD',
    'informe': 'IN',
    'autorizacion': 'AU', // autorización de datos de un cliente
  };

  void _validarTabla(String tabla) {
    if (!_tablasSync.contains(tabla)) throw ArgumentError('tabla');
  }

  // ---------------------------------------------------------------- ajustes
  Future<String?> ajuste(String clave) async {
    final r = await db.query('ajustes', where: 'clave = ?', whereArgs: [clave]);
    return r.isEmpty ? null : r.first['valor'] as String;
  }

  Future<void> setAjuste(String clave, String valor) {
    if (clave == 'negocio_tipo') tipoNegocio.value = valor;
    return _guardarAjuste(clave, valor);
  }

  Future<void> _guardarAjuste(String clave, String valor) => db.insert(
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
        'proveedores',
        'documentos',
        'pagos_proveedor',
        'cuentas_pagar',
        'pagos_fijos_hechos',
        'pagos_fijos'
      ]) {
        await t.delete(tabla);
      }
      await t.delete('ajustes', where: "clave LIKE 'pull_%'");
    });
    _avisar();
  }
}
