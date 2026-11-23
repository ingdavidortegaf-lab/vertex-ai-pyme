part of 'local_db.dart';

/// Documentos emitidos con número único, autorizaciones de clientes y datos para informes y cuentas de cobro.
extension LocalDbDocumentos on LocalDb {
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
          LineaDoc(x['nombre'] as String, LocalDb._dbl(x['cant']), LocalDb._dbl(x['precio']),
              (x['unidad'] as String?) ?? 'und')
      ];
    }
    final v = await movimiento(ventaId);
    if (v == null) return const [];
    return [LineaDoc(v['concepto'] as String, 1, LocalDb._dbl(v['monto']))];
  }

  // ------------------------------------------------- documentos emitidos

  /// Autorización de tratamiento de datos de un cliente (Ley 1581): fecha,
  /// medio (en la tienda, por WhatsApp, firmada) y versión del texto.
  Future<void> registrarAutorizacionCliente(String clienteId, String medio) =>
      setAjuste('aut_cli_$clienteId',
          jsonEncode({'fecha': _ahora(), 'medio': medio, 'version': versionAutorizacion}));

  Future<Map<String, dynamic>?> autorizacionCliente(String clienteId) async {
    final v = await ajuste('aut_cli_$clienteId');
    if (v == null) return null;
    try {
      return jsonDecode(v) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Código corto de este dispositivo (4 caracteres) para que los números
  /// de documento no choquen entre celulares de la misma empresa.
  Future<String> codigoDispositivo() async {
    final c = await ajuste('dispositivo');
    if (c != null) return c;
    final nuevo = newId().replaceAll('-', '').substring(0, 4).toUpperCase();
    await setAjuste('dispositivo', nuevo);
    return nuevo;
  }

  /// Emite un documento con número único (p. ej. FV-A3F1-000012) y lo deja
  /// en el archivo. Con [reutilizar], si ese mismo registro ya tenía un
  /// documento de ese tipo, devuelve el mismo número (reimpresión).
  Future<Map<String, Object?>> emitirDocumento(String tipo,
      {String? refId,
      String? clienteId,
      String? clienteNombre,
      double total = 0,
      String resumen = '',
      bool reutilizar = false}) async {
    final prefijo = LocalDb.prefijosDoc[tipo];
    if (prefijo == null) throw ArgumentError('tipo');
    if (reutilizar && refId != null) {
      final r = await db.query('documentos',
          where: 'tipo = ? AND ref_id = ?', whereArgs: [tipo, refId], limit: 1);
      if (r.isNotEmpty) return r.first;
    }
    final disp = await codigoDispositivo();
    late Map<String, Object?> fila;
    await db.transaction((t) async {
      final r = await t.query('ajustes', where: 'clave = ?', whereArgs: ['consec_$tipo']);
      final n = (r.isEmpty ? 0 : int.tryParse(r.first['valor'] as String) ?? 0) + 1;
      await t.insert('ajustes', {'clave': 'consec_$tipo', 'valor': '$n'},
          conflictAlgorithm: ConflictAlgorithm.replace);
      fila = {
        'id': newId(),
        'tipo': tipo,
        'numero': '$prefijo-$disp-${n.toString().padLeft(6, '0')}',
        'ref_id': refId,
        'cliente_id': clienteId,
        'cliente_nombre': clienteNombre,
        'total': total,
        'fecha': _ahora(),
        'resumen': resumen.length > 200 ? resumen.substring(0, 200) : resumen,
      };
      await t.insert('documentos', fila);
    });
    _avisar();
    return fila;
  }

  /// Guarda la ruta del PDF del documento.
  Future<void> archivarPdf(String documentoId, String ruta) async {
    await db.update('documentos', {'archivo': ruta},
        where: 'id = ?', whereArgs: [documentoId]);
    _avisar();
  }

  Future<List<Map<String, Object?>>> documentos({String? tipo, int limite = 300}) =>
      db.query('documentos',
          where: tipo == null ? null : 'tipo = ?',
          whereArgs: tipo == null ? null : [tipo],
          orderBy: 'fecha DESC',
          limit: limite);

  /// Que el movimiento no esté anulado.
  static const _vigente = 'NOT EXISTS (SELECT 1 FROM ventas a WHERE a.anula = v.id)';

  /// Movimientos entre dos fechas locales (para informes).
  Future<List<Map<String, Object?>>> movimientosEntre(DateTime desde, DateTime hasta) =>
      db.rawQuery(
          'SELECT v.*, c.nombre AS cliente_nombre, c.tipo_doc AS cliente_tipo_doc, '
          'c.documento AS cliente_documento, p.nombre AS tercero_nombre, '
          'p.tipo_doc AS tercero_tipo_doc, p.documento AS tercero_documento FROM ventas_netas v '
          'LEFT JOIN clientes c ON c.id = v.cliente_id '
          'LEFT JOIN proveedores p ON p.id = v.tercero_id '
          'WHERE v.fecha >= ? AND v.fecha < ? ORDER BY v.fecha',
          [isoUtc(desde), isoUtc(hasta)]);

  /// Fiados y abonos de un cliente, del más antiguo al más nuevo (para la
  /// cuenta de cobro).
  Future<List<Map<String, Object?>>> movimientosDeCredito(String clienteId) =>
      db.rawQuery(
          "SELECT * FROM ventas v WHERE cliente_id = ? AND "
          "((tipo = 'ingreso' AND credito = 1) OR tipo = 'abono') AND $_vigente ORDER BY fecha",
          [clienteId]);

  /// Fiados y abonos de todos los clientes activos, agrupados por cliente
  /// (para la cartera por edades).
  Future<Map<String, List<Map<String, Object?>>>> creditoPorCliente() async {
    final r = await db.rawQuery(
        "SELECT v.* FROM ventas v JOIN clientes c ON c.id = v.cliente_id "
        "WHERE c.deleted = 0 AND ((v.tipo = 'ingreso' AND v.credito = 1) "
        "OR v.tipo = 'abono') AND $_vigente ORDER BY v.fecha");
    final m = <String, List<Map<String, Object?>>>{};
    for (final x in r) {
      (m[x['cliente_id'] as String] ??= []).add(x);
    }
    return m;
  }
}
