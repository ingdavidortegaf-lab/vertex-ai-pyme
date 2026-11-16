/// Estrategia de conflictos (bases 4.3 y anteproyecto):
/// - Ventas, gastos y abonos: SOLO se agregan; nunca se editan ni se borran.
///   Si llega dos veces el mismo id, se ignora (sin duplicados).
/// - Clientes: gana el cambio MÁS RECIENTE DE CADA CAMPO (nombre, teléfono,
///   borrado). Si en un celular cambian el teléfono y en otro el nombre, se
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

  const ClienteCampos({
    required this.id,
    required this.nombre,
    required this.nombreTs,
    required this.telefono,
    required this.telefonoTs,
    required this.deleted,
    required this.deletedTs,
  });

  DateTime get updatedAt {
    var m = nombreTs;
    if (telefonoTs.isAfter(m)) m = telefonoTs;
    if (deletedTs.isAfter(m)) m = deletedTs;
    return m;
  }

  /// Une dos versiones campo por campo. Ante empate se queda con [this].
  ClienteCampos merge(ClienteCampos otro) {
    final n = otro.nombreTs.isAfter(nombreTs);
    final t = otro.telefonoTs.isAfter(telefonoTs);
    final d = otro.deletedTs.isAfter(deletedTs);
    return ClienteCampos(
      id: id,
      nombre: n ? otro.nombre : nombre,
      nombreTs: n ? otro.nombreTs : nombreTs,
      telefono: t ? otro.telefono : telefono,
      telefonoTs: t ? otro.telefonoTs : telefonoTs,
      deleted: d ? otro.deleted : deleted,
      deletedTs: d ? otro.deletedTs : deletedTs,
    );
  }

  /// Fila de la base local (deleted como 0/1, fechas como texto ISO UTC).
  factory ClienteCampos.fromLocal(Map<String, Object?> r) => ClienteCampos(
        id: r['id'] as String,
        nombre: r['nombre'] as String,
        nombreTs: DateTime.parse(r['nombre_ts'] as String),
        telefono: (r['telefono'] as String?) ?? '',
        telefonoTs: DateTime.parse(r['telefono_ts'] as String),
        deleted: (r['deleted'] as int? ?? 0) == 1,
        deletedTs: DateTime.parse(r['deleted_ts'] as String),
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
      );

  Map<String, Object?> toLocalRow() => {
        'id': id,
        'nombre': nombre,
        'nombre_ts': isoUtc(nombreTs),
        'telefono': telefono,
        'telefono_ts': isoUtc(telefonoTs),
        'deleted': deleted ? 1 : 0,
        'deleted_ts': isoUtc(deletedTs),
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
        'updated_at': isoUtc(updatedAt),
      };
}

/// Espera antes de reintentar un registro que el servidor rechazó:
/// 15 s, 30 s, 1 min, 2 min, 4 min… con tope de 30 min.
Duration esperaReintento(int intentos) {
  final n = intentos < 1 ? 1 : (intentos > 8 ? 8 : intentos);
  final seg = 15 * (1 << (n - 1));
  return Duration(seconds: seg > 1800 ? 1800 : seg);
}
