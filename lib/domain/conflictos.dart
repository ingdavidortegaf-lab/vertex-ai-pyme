/// Estrategia de conflictos (bases 4.3 y anteproyecto):
/// - Ventas, gastos y abonos: SOLO se agregan; nunca se editan ni se borran.
///   Si llega dos veces el mismo id, se ignora (sin duplicados).
/// - Clientes: gana el cambio MÁS RECIENTE DE CADA CAMPO (nombre, teléfono,
///   datos de identificación y correo, borrado). Si en un celular cambian el teléfono y en otro el nombre, se
///   conservan los dos cambios.
///
/// La misma regla corre en el servidor (trigger `merge_cliente` en
/// supabase_schema.sql) y en el celular al descargar cambios.
library;

String isoUtc(DateTime d) => DateTime.fromMillisecondsSinceEpoch(
      d.millisecondsSinceEpoch,
      isUtc: true,
    ).toIso8601String();

class ClienteCampos {
  final String id;
  final String nombre;
  final DateTime nombreTs;
  final String telefono;
  final DateTime telefonoTs;
  final bool deleted;
  final DateTime deletedTs;

  /// Identificación (tipo y número de documento) y correo. Se mueven juntos
  /// como un solo bloque «datos» con su propia marca de tiempo.
  final String tipoDoc;
  final String documento;
  final String correo;
  final DateTime datosTs;

  /// Fecha para campos que no existían en versiones anteriores: cualquier
  /// cambio real gana sobre ella al unir.
  static final inicio = DateTime.utc(1970);

  ClienteCampos({
    required this.id,
    required this.nombre,
    required this.nombreTs,
    required this.telefono,
    required this.telefonoTs,
    required this.deleted,
    required this.deletedTs,
    this.tipoDoc = 'CC',
    this.documento = '',
    this.correo = '',
    DateTime? datosTs,
  }) : datosTs = datosTs ?? inicio;

  DateTime get updatedAt {
    var m = nombreTs;
    if (telefonoTs.isAfter(m)) m = telefonoTs;
    if (deletedTs.isAfter(m)) m = deletedTs;
    if (datosTs.isAfter(m)) m = datosTs;
    return m;
  }

  /// Une dos versiones campo por campo. Ante empate se queda con [this].
  ClienteCampos merge(ClienteCampos otro) {
    final n = otro.nombreTs.isAfter(nombreTs);
    final t = otro.telefonoTs.isAfter(telefonoTs);
    final d = otro.deletedTs.isAfter(deletedTs);
    final x = otro.datosTs.isAfter(datosTs);
    return ClienteCampos(
      id: id,
      nombre: n ? otro.nombre : nombre,
      nombreTs: n ? otro.nombreTs : nombreTs,
      telefono: t ? otro.telefono : telefono,
      telefonoTs: t ? otro.telefonoTs : telefonoTs,
      deleted: d ? otro.deleted : deleted,
      deletedTs: d ? otro.deletedTs : deletedTs,
      tipoDoc: x ? otro.tipoDoc : tipoDoc,
      documento: x ? otro.documento : documento,
      correo: x ? otro.correo : correo,
      datosTs: x ? otro.datosTs : datosTs,
    );
  }

  static DateTime _ts(Object? v) => v is String ? DateTime.parse(v) : inicio;

  /// Fila de la base local (deleted como 0/1, fechas como texto ISO UTC).
  factory ClienteCampos.fromLocal(Map<String, Object?> r) => ClienteCampos(
        id: r['id'] as String,
        nombre: r['nombre'] as String,
        nombreTs: DateTime.parse(r['nombre_ts'] as String),
        telefono: (r['telefono'] as String?) ?? '',
        telefonoTs: DateTime.parse(r['telefono_ts'] as String),
        deleted: (r['deleted'] as int? ?? 0) == 1,
        deletedTs: DateTime.parse(r['deleted_ts'] as String),
        tipoDoc: (r['tipo_doc'] as String?) ?? 'CC',
        documento: (r['documento'] as String?) ?? '',
        correo: (r['correo'] as String?) ?? '',
        datosTs: _ts(r['datos_ts']),
      );

  /// Fila que llega de Supabase (deleted como bool).
  factory ClienteCampos.fromRemote(Map<String, dynamic> r) => ClienteCampos(
        id: r['id'] as String,
        nombre: r['nombre'] as String,
        nombreTs: DateTime.parse(r['nombre_ts'] as String),
        telefono: (r['telefono'] as String?) ?? '',
        telefonoTs: DateTime.parse(r['telefono_ts'] as String),
        deleted: r['deleted'] == true,
        deletedTs: DateTime.parse(r['deleted_ts'] as String),
        tipoDoc: (r['tipo_doc'] as String?) ?? 'CC',
        documento: (r['documento'] as String?) ?? '',
        correo: (r['correo'] as String?) ?? '',
        datosTs: _ts(r['datos_ts']),
      );

  Map<String, Object?> toLocalRow() => {
        'id': id,
        'nombre': nombre,
        'nombre_ts': isoUtc(nombreTs),
        'telefono': telefono,
        'telefono_ts': isoUtc(telefonoTs),
        'deleted': deleted ? 1 : 0,
        'deleted_ts': isoUtc(deletedTs),
        'tipo_doc': tipoDoc,
        'documento': documento,
        'correo': correo,
        'datos_ts': isoUtc(datosTs),
        'updated_at': isoUtc(updatedAt),
      };

  Map<String, dynamic> toRemote() => {
        'id': id,
        'nombre': nombre,
        'nombre_ts': isoUtc(nombreTs),
        'telefono': telefono,
        'telefono_ts': isoUtc(telefonoTs),
        'deleted': deleted,
        'deleted_ts': isoUtc(deletedTs),
        'tipo_doc': tipoDoc,
        'documento': documento,
        'correo': correo,
        'datos_ts': isoUtc(datosTs),
        'updated_at': isoUtc(updatedAt),
      };
}

/// Producto del inventario: misma regla que clientes (gana el cambio más
/// reciente de cada campo). El stock NO es un campo: se calcula sumando los
/// movimientos de inventario, que solo se agregan.
class ProductoCampos {
  static const campos = [
    'nombre',
    'precio',
    'costo',
    'minimo',
    'deleted',
    'codigo',
    'unidad',
    'iva'
  ];

  /// Unidades de venta: por unidad o por peso (gramera).
  static const unidades = ['und', 'kg', 'lb', 'serv'];

  /// Fecha para campos que no existían en versiones anteriores: cualquier
  /// cambio real gana sobre ella al unir.
  static final _inicio = DateTime.utc(1970);

  final String id;
  final Map<String, Object> valores;
  final Map<String, DateTime> ts;
  const ProductoCampos(this.id, this.valores, this.ts);

  String get nombre => valores['nombre'] as String;
  double get precio => (valores['precio'] as num).toDouble();
  double get costo => (valores['costo'] as num).toDouble();
  double get minimo => (valores['minimo'] as num).toDouble();
  bool get deleted => valores['deleted'] == true;
  String get codigo => valores['codigo'] as String;
  String get unidad => valores['unidad'] as String;

  /// Porcentaje de IVA (−1 = sin definir).
  double get iva => (valores['iva'] as num).toDouble();

  DateTime get updatedAt =>
      ts.values.reduce((a, b) => b.isAfter(a) ? b : a);

  ProductoCampos merge(ProductoCampos otro) {
    final v = Map<String, Object>.of(valores);
    final t = Map<String, DateTime>.of(ts);
    for (final c in campos) {
      if (otro.ts[c]!.isAfter(ts[c]!)) {
        v[c] = otro.valores[c]!;
        t[c] = otro.ts[c]!;
      }
    }
    return ProductoCampos(id, v, t);
  }

  static ProductoCampos _leer(Map<String, Object?> r, bool local) {
    final v = <String, Object>{
      'nombre': r['nombre'] as String,
      'precio': (r['precio'] as num).toDouble(),
      'costo': (r['costo'] as num? ?? 0).toDouble(),
      'minimo': (r['minimo'] as num? ?? 0).toDouble(),
      'deleted': local ? (r['deleted'] as int? ?? 0) == 1 : r['deleted'] == true,
      'codigo': (r['codigo'] as String?) ?? '',
      'unidad': unidades.contains(r['unidad']) ? r['unidad'] as String : 'und',
      'iva': _iva(r['iva']),
    };
    final t = {
      for (final c in campos)
        c: r['${c}_ts'] is String ? DateTime.parse(r['${c}_ts'] as String) : _inicio
    };
    return ProductoCampos(r['id'] as String, v, t);
  }

  static double _iva(Object? v) {
    final x = (v as num?)?.toDouble() ?? -1;
    return x == -1 || (x.isFinite && x >= 0 && x <= 100) ? x : -1;
  }

  factory ProductoCampos.fromLocal(Map<String, Object?> r) => _leer(r, true);
  factory ProductoCampos.fromRemote(Map<String, dynamic> r) => _leer(r, false);

  Map<String, Object?> _fila(bool local) => {
        'id': id,
        for (final c in campos)
          c: c == 'deleted' && local ? (deleted ? 1 : 0) : valores[c],
        for (final c in campos) '${c}_ts': isoUtc(ts[c]!),
        'updated_at': isoUtc(updatedAt),
      };

  Map<String, Object?> toLocalRow() => _fila(true);
  Map<String, dynamic> toRemote() => _fila(false);
}

/// Espera antes de reintentar un registro que el servidor rechazó:
/// 15 s, 30 s, 1 min, 2 min, 4 min… con tope de 30 min.
Duration esperaReintento(int intentos) {
  final n = intentos < 1 ? 1 : (intentos > 8 ? 8 : intentos);
  final seg = 15 * (1 << (n - 1));
  return Duration(seconds: seg > 1800 ? 1800 : seg);
}
