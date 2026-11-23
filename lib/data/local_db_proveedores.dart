part of 'local_db.dart';

/// Proveedores y terceros, pedidos, cuentas por pagar y pagos fijos.
extension LocalDbProveedores on LocalDb {
  /// Proveedores y demás terceros (arrendador, servicios, empleados), con
  /// lo que se les debe y lo que se les ha pagado en gastos.
  Future<List<Map<String, Object?>>> proveedores({String? clase}) => db.rawQuery(
      'SELECT p.*, '
      'COALESCE((SELECT SUM(c.total - COALESCE((SELECT SUM(x.monto) FROM pagos_proveedor x '
      'WHERE x.cuenta_id = c.id), 0)) FROM cuentas_pagar c WHERE c.proveedor_id = p.id), 0) AS debo, '
      "COALESCE((SELECT SUM(v.monto) FROM ventas v WHERE v.tercero_id = p.id AND v.tipo = 'egreso'), 0) AS pagado "
      'FROM proveedores p ${clase == null ? '' : 'WHERE p.clase = ? '}'
      'ORDER BY p.nombre COLLATE NOCASE',
      [if (clase != null) clase]);

  Future<Map<String, Object?>?> proveedor(String id) async {
    final r = await db.query('proveedores', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : r.first;
  }

  Future<String> saveProveedor(String nombre, String telefono,
      {String? id,
      String tipoDoc = 'NIT',
      String documento = '',
      String correo = '',
      String clase = 'proveedor'}) async {
    final pid = id ?? newId();
    final prev = id == null ? null : await proveedor(id);
    await db.insert(
        'proveedores',
        {
          'id': pid,
          'nombre': nombre.trim(),
          'telefono': telefono,
          'tipo_doc': tipoDoc,
          'documento': documento,
          'correo': correo,
          'clase': clasesTercero.containsKey(clase) ? clase : 'otro',
          'creado': prev?['creado'] ?? _ahora(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
    _avisar();
    return pid;
  }

  Future<void> deleteProveedor(String id) async {
    await db.delete('proveedores', where: 'id = ?', whereArgs: [id]);
    _avisar();
  }

  // ------------------------------------------------------------ pagos fijos
  /// Pagos fijos activos con el último periodo pagado.
  Future<List<PagoFijo>> pagosFijos() async {
    final hoy = periodoDe(reloj());
    final r = await db.rawQuery(
        'SELECT f.*, p.nombre AS tercero_nombre, '
        '(SELECT MAX(h.periodo) FROM pagos_fijos_hechos h WHERE h.fijo_id = f.id) AS ultimo, '
        '(SELECT COALESCE(SUM(h.monto), 0) FROM pagos_fijos_hechos h '
        'WHERE h.fijo_id = f.id AND h.periodo = ?) AS este_mes '
        'FROM pagos_fijos f LEFT JOIN proveedores p ON p.id = f.tercero_id '
        'WHERE f.activo = 1 ORDER BY f.dia',
        [hoy]);
    return [
      for (final x in r)
        PagoFijo(
          id: x['id'] as String,
          nombre: x['nombre'] as String,
          monto: LocalDb._dbl(x['monto']),
          dia: (x['dia'] as num).toInt(),
          terceroId: x['tercero_id'] as String?,
          terceroNombre: x['tercero_nombre'] as String?,
          ultimoPeriodo: x['ultimo'] as String?,
          pagadoEsteMes: LocalDb._dbl(x['este_mes']),
        )
    ];
  }

  Future<String> saveFijo(String nombre, double monto, int dia,
      {String? id, String? terceroId}) async {
    final n = nombre.trim();
    if (n.isEmpty) throw ArgumentError('nombre');
    if (dia < 1 || dia > 31) throw ArgumentError('dia');
    if (!monto.isFinite || monto < 0) throw ArgumentError('monto');
    final fid = id ?? newId();
    final prev = await db.query('pagos_fijos', where: 'id = ?', whereArgs: [fid]);
    await db.insert(
        'pagos_fijos',
        {
          'id': fid,
          'nombre': n.length > 80 ? n.substring(0, 80) : n,
          'monto': monto,
          'dia': dia,
          'tercero_id': terceroId,
          'activo': 1,
          'creado': prev.isEmpty ? _ahora() : prev.first['creado'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
    _avisar();
    return fid;
  }

  /// Se deja de usar (los pagos hechos se conservan en la historia).
  Future<void> deleteFijo(String id) async {
    await db.update('pagos_fijos', {'activo': 0}, where: 'id = ?', whereArgs: [id]);
    _avisar();
  }

  /// Pagar un pago fijo de este mes: queda como gasto (se sincroniza) con
  /// su medio de pago y a quién se le pagó.
  Future<String> pagarFijo(String fijoId, double monto, List<Pago> pagos) async {
    final r = await db.query('pagos_fijos', where: 'id = ?', whereArgs: [fijoId]);
    if (r.isEmpty) throw ArgumentError('fijo');
    if (!monto.isFinite || monto <= 0) throw ArgumentError('monto');
    final f = r.first;
    final medios = LocalDb._pagosDe('egreso', false, monto, pagos)!;
    final ahora = reloj();
    final id = newId();
    await db.transaction((t) async {
      final row = <String, Object?>{
        'id': id,
        'cliente_id': null,
        'concepto': conceptoFijo(f['nombre'] as String, ahora),
        'monto': monto,
        'tipo': 'egreso',
        'credito': 0,
        'fecha': _ahora(),
        ..._quien,
      };
      await t.insert('ventas', {
        ...row,
        'pagos': codificarPagos(medios),
        'tercero_id': f['tercero_id'],
        'sync': 'pendiente'
      });
      await _enqueue(t, 'ventas', id,
          {...row, 'credito': false, 'pagos': medios.map((p) => p.aMapa()).toList()});
      await t.insert('pagos_fijos_hechos', {
        'id': newId(),
        'fijo_id': fijoId,
        'periodo': periodoDe(ahora),
        'monto': monto,
        'egreso_id': id,
        'fecha': _ahora(),
      });
    });
    _avisar();
    return id;
  }

  /// Llegó la mercancía: entrada de inventario por cada producto y, si se
  /// pide, el gasto de la compra; todo en una sola transacción.
  /// [pagadoAhora]: cuánto se le pagó al proveedor al recibir (por defecto,
  /// todo). Lo que falte queda como cuenta por pagar que vence en [venceSaldo].
  Future<void> recibirPedido(List<(String productoId, double cantidad, double costo)> items,
      {String? conceptoGasto,
      List<Pago>? pagosGasto,
      double? pagadoAhora,
      String? proveedorId,
      String? proveedorNombre,
      DateTime? venceSaldo}) async {
    final validos = items.where((x) => x.$2 > 0).toList();
    if (validos.isEmpty) throw ArgumentError('items');
    final total = validos.fold(0.0, (s, x) => s + x.$2 * x.$3);
    await db.transaction((t) async {
      for (final (pid, cant, costo) in validos) {
        await _insertarInventario(
            t, _filaInventario(newId(), pid, cant, 'entrada', costo: costo));
      }
      if (conceptoGasto != null && total > 0) {
        var c = conceptoGasto.trim().isEmpty ? 'Compra de mercancía' : conceptoGasto.trim();
        if (c.length > 120) c = '${c.substring(0, 117)}…';
        final pagado = (pagadoAhora ?? total).clamp(0.0, total);
        final saldo = total - pagado;
        if (saldo > 0.5) {
          await t.insert('cuentas_pagar', {
            'id': newId(),
            'proveedor_id': proveedorId,
            'proveedor_nombre': (proveedorNombre ?? '').trim().isEmpty ? 'Proveedor' : proveedorNombre!.trim(),
            'concepto': c,
            'total': saldo,
            'fecha': _ahora(),
            'vence': isoUtc(venceSaldo ?? reloj().add(const Duration(days: 15))),
          });
        }
        if (pagado <= 0.5) return;
        final id = newId();
        final row = <String, Object?>{
          'id': id,
          'cliente_id': null,
          'concepto': saldo > 0.5 ? '$c (pago parcial)' : c,
          'monto': pagado,
          'tipo': 'egreso',
          'credito': 0,
          'fecha': _ahora(),
          ..._quien,
        };
        final medios = LocalDb._pagosDe('egreso', false, pagado, pagosGasto)!;
        await t.insert('ventas',
            {...row, 'pagos': codificarPagos(medios), 'sync': 'pendiente'});
        await _enqueue(t, 'ventas', id, {
          ...row,
          'credito': false,
          'pagos': medios.map((p) => p.aMapa()).toList(),
        });
      }
    });
    _avisar();
  }

  /// Lo que se le debe a cada proveedor: total, abonado, saldo y vencimiento.
  Future<List<Map<String, Object?>>> cuentasPorPagar({bool soloPendientes = true}) => db.rawQuery(
      'SELECT c.*, COALESCE((SELECT SUM(p.monto) FROM pagos_proveedor p WHERE p.cuenta_id = c.id), 0) AS abonado, '
      'c.total - COALESCE((SELECT SUM(p.monto) FROM pagos_proveedor p WHERE p.cuenta_id = c.id), 0) AS saldo, '
      'pr.telefono AS proveedor_telefono '
      'FROM cuentas_pagar c LEFT JOIN proveedores pr ON pr.id = c.proveedor_id '
      '${soloPendientes ? 'WHERE c.total - COALESCE((SELECT SUM(p.monto) FROM pagos_proveedor p WHERE p.cuenta_id = c.id), 0) > 0.5 ' : ''}'
      'ORDER BY c.vence');

  Future<double> totalPorPagar() async =>
      (await cuentasPorPagar()).fold<double>(0, (s, c) => s + LocalDb._dbl(c['saldo']));

  /// Abono a un proveedor: queda el pago y un gasto con su medio de pago.
  Future<void> pagarProveedor(String cuentaId, double monto, List<Pago> pagos) async {
    final r = await cuentasPorPagar(soloPendientes: false);
    final c = r.firstWhere((x) => x['id'] == cuentaId, orElse: () => const {});
    if (c.isEmpty) throw ArgumentError('cuenta');
    if (monto <= 0 || monto > LocalDb._dbl(c['saldo']) + 0.5) throw ArgumentError('monto');
    final medios = LocalDb._pagosDe('egreso', false, monto, pagos)!;
    await db.transaction((t) async {
      final id = newId();
      var concepto = 'Abono a ${c['proveedor_nombre']}';
      if (concepto.length > 120) concepto = concepto.substring(0, 120);
      final row = <String, Object?>{
        'id': id,
        'cliente_id': null,
        'concepto': concepto,
        'monto': monto,
        'tipo': 'egreso',
        'credito': 0,
        'fecha': _ahora(),
        ..._quien,
      };
      await t.insert('ventas', {...row, 'pagos': codificarPagos(medios), 'sync': 'pendiente'});
      await _enqueue(t, 'ventas', id,
          {...row, 'credito': false, 'pagos': medios.map((p) => p.aMapa()).toList()});
      await t.insert('pagos_proveedor',
          {'id': newId(), 'cuenta_id': cuentaId, 'monto': monto, 'fecha': _ahora(), 'egreso_id': id});
    });
    _avisar();
  }
}
