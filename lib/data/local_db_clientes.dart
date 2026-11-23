part of 'local_db.dart';

/// Clientes: crear, editar, borrar (lógico), saldos y resumen para el seguimiento.
extension LocalDbClientes on LocalDb {
  // --------------------------------------------------------------- clientes
  /// Crea o edita. En una edición solo cambia la marca de tiempo de los
  /// campos que realmente cambiaron (conflictos por campo).
  Future<String> saveCliente(String nombre, String telefono,
      {String? id, String? tipoDoc, String? documento, String? correo}) async {
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
          'tipo_doc': tipoDoc ?? 'CC',
          'documento': documento ?? '',
          'correo': correo ?? '',
          'datos_ts': ts,
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
        final datos = {
          if (tipoDoc != null) 'tipo_doc': tipoDoc,
          if (documento != null) 'documento': documento,
          if (correo != null) 'correo': correo,
        };
        if (datos.entries.any((e) => row[e.key] != e.value)) {
          row.addAll(datos);
          row['datos_ts'] = ts;
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


  /// Clientes activos con su saldo pendiente.
  Future<List<Map<String, Object?>>> clientes() => db.rawQuery(
      'SELECT c.id, c.nombre, c.telefono, c.tipo_doc, c.documento, c.correo, c.sync, '
      '${LocalDb._saldoSql} AS saldo '
      'FROM clientes c WHERE c.deleted = 0 ORDER BY c.nombre COLLATE NOCASE');

  /// Compras de cada cliente (cuántas, cuánto, primera y última) para el
  /// seguimiento por WhatsApp, más si autorizó y cuándo se le escribió.
  Future<List<ResumenCliente>> resumenClientes() async {
    final r = await db.rawQuery(
        "SELECT c.id, c.nombre, c.telefono, ${LocalDb._saldoSql} AS saldo, "
        "(SELECT COALESCE(SUM(v.signo), 0) FROM ventas_netas v WHERE v.cliente_id = c.id AND v.tipo = 'ingreso') AS compras, "
        "(SELECT COALESCE(SUM(v.monto), 0) FROM ventas_netas v WHERE v.cliente_id = c.id AND v.tipo = 'ingreso') AS total, "
        "(SELECT MIN(v.fecha) FROM ventas_netas v WHERE v.cliente_id = c.id AND v.tipo = 'ingreso' AND v.signo = 1) AS primera, "
        "(SELECT MAX(v.fecha) FROM ventas_netas v WHERE v.cliente_id = c.id AND v.tipo = 'ingreso' AND v.signo = 1) AS ultima "
        'FROM clientes c WHERE c.deleted = 0');
    final ajustes = {
      for (final a in await db.rawQuery(
          "SELECT clave, valor FROM ajustes WHERE clave LIKE 'aut_cli_%' OR clave LIKE 'contacto_cli_%'"))
        a['clave'] as String: a['valor'] as String
    };
    DateTime? fecha(Object? v) => v == null ? null : DateTime.tryParse(v as String)?.toLocal();
    return [
      for (final x in r)
        ResumenCliente(
          id: x['id'] as String,
          nombre: x['nombre'] as String,
          telefono: (x['telefono'] as String?) ?? '',
          compras: (x['compras'] as num).toInt(),
          total: LocalDb._dbl(x['total']),
          primera: fecha(x['primera']),
          ultima: fecha(x['ultima']),
          saldo: LocalDb._dbl(x['saldo']),
          autorizo: ajustes.containsKey('aut_cli_${x['id']}'),
          contactado: fecha(ajustes['contacto_cli_${x['id']}']),
        )
    ];
  }

  Future<void> marcarContactado(String clienteId) => setAjuste('contacto_cli_$clienteId', _ahora());

  Future<Map<String, Object?>?> cliente(String id) async {
    final r = await db.rawQuery(
        'SELECT c.id, c.nombre, c.telefono, c.tipo_doc, c.documento, c.correo, '
        'c.sync, c.deleted, ${LocalDb._saldoSql} AS saldo FROM clientes c WHERE c.id = ?',
        [id]);
    return r.isEmpty ? null : r.first;
  }

  Future<List<ClienteSaldo>> clientesConSaldo() async => [
        for (final c in await clientes())
          ClienteSaldo(
            id: c['id'] as String,
            nombre: c['nombre'] as String,
            telefono: (c['telefono'] as String?) ?? '',
            saldo: LocalDb._dbl(c['saldo']),
          )
      ];
}
