part of 'local_db.dart';

/// Ventas, gastos y abonos (solo se agregan), resumen del mes, datos del asistente y reportes por periodo.
extension LocalDbMovimientos on LocalDb {
  // ------------------------------------------- ventas, gastos y abonos
  /// Solo se agregan. tipo: 'ingreso' (venta), 'egreso' (gasto) o 'abono'
  /// (pago de una deuda). [credito] = venta fiada (queda por cobrar).
  Future<String> saveMovimiento(String concepto, double monto,
      {String tipo = 'ingreso',
      bool credito = false,
      String? clienteId,
      String? terceroId,
      List<Pago>? pagos}) async {
    if (!LocalDb.tiposMovimiento.contains(tipo)) throw ArgumentError('tipo');
    if (!monto.isFinite || monto <= 0) throw ArgumentError('monto');
    if (concepto.trim().isEmpty) throw ArgumentError('concepto');
    final fiado = tipo == 'ingreso' && credito;
    if ((fiado || tipo == 'abono') && clienteId == null) {
      throw ArgumentError('cliente');
    }
    final medios = LocalDb._pagosDe(tipo, fiado, monto, pagos);
    final id = newId();
    final row = <String, Object?>{
      'id': id,
      'cliente_id': tipo == 'egreso' ? null : clienteId,
      'concepto': concepto.trim(),
      'monto': monto,
      'tipo': tipo,
      'credito': fiado ? 1 : 0,
      'fecha': _ahora(),
      ..._quien,
    };
    await db.transaction((t) async {
      await t.insert('ventas', {
        ...row,
        'pagos': medios == null ? null : codificarPagos(medios),
        // A quién se le pagó el gasto: solo en este dispositivo.
        if (tipo == 'egreso' && terceroId != null) 'tercero_id': terceroId,
        'sync': 'pendiente'
      });
      await _enqueue(t, 'ventas', id, {
        ...row,
        'credito': fiado,
        'pagos': medios?.map((p) => p.aMapa()).toList(),
      });
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
    return (LocalDb._dbl(r.first['s']), (r.first['c'] as num?)?.toInt() ?? 0);
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
            'SELECT ${LocalDb._saldoSql} AS saldo FROM clientes c WHERE c.deleted = 0'
            ') WHERE saldo > 0'))
        .first;
    final nClientes = LocalDb._int(
        await db.rawQuery('SELECT COUNT(*) FROM clientes WHERE deleted = 0'));
    return Resumen(
      ingresos: LocalDb._dbl(r['ing']),
      nIngresos: (r['ning'] as num?)?.toInt() ?? 0,
      egresos: LocalDb._dbl(r['egr']),
      nEgresos: (r['negr'] as num?)?.toInt() ?? 0,
      porCobrar: LocalDb._dbl(deuda['total']),
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
    return [for (final x in r) TopCliente(x['nombre'] as String, LocalDb._dbl(x['total']))];
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
    final ventas = LocalDb._dbl(r['ven']), fiado = LocalDb._dbl(r['fia']);
    final medios = porMedio(await db.rawQuery(
        'SELECT tipo, credito, monto, pagos FROM ventas WHERE fecha >= ? AND fecha < ?',
        [a, b]));
    return ResumenPeriodo(
      medios: medios,
      ventas: ventas,
      nVentas: (r['nven'] as num?)?.toInt() ?? 0,
      gastos: LocalDb._dbl(r['gas']),
      fiado: fiado,
      contado: ventas - fiado,
      abonos: LocalDb._dbl(r['abo']),
      gananciaProductos: LocalDb._dbl(g.first.values.first),
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
      m[d] = (m[d] ?? 0) + LocalDb._dbl(x['monto']);
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
        TopProducto(x['nombre'] as String, LocalDb._dbl(x['cant']), LocalDb._dbl(x['total']))
    ];
  }
}
