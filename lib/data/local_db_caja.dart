part of 'local_db.dart';

/// Caja: anular movimientos (siempre con un movimiento nuevo, nunca
/// borrando), turnos con diferencia de caja y lo que llega de la nube.
extension LocalDbCaja on LocalDb {
  // ------------------------------------------------------------ anulaciones

  /// ¿Ya se anuló este movimiento?
  Future<bool> estaAnulado(String id) async =>
      LocalDb._int(await db.rawQuery('SELECT COUNT(*) FROM ventas WHERE anula = ?', [id])) > 0;

  /// Anula un movimiento agregando otro en contra, por el mismo valor, del
  /// mismo cliente y con los mismos medios de pago. Si era una venta con
  /// productos, lo vendido vuelve al inventario. Solo el dueño o el
  /// administrador (el servidor lo exige). Si atiende alguien sin ese
  /// permiso, hace falta que un dueño o administrador lo autorice con su PIN
  /// ([autoriza] es su nombre).
  Future<String> anular(String id, {String motivo = '', String autoriza = ''}) async {
    if (!equipo.value.puede(Permiso.anularMovimiento)) throw StateError('permiso');
    if (!this.puede(Permiso.anularMovimiento) && autoriza.trim().isEmpty) throw StateError('autorizacion');
    final nuevo = newId();
    await db.transaction((t) async {
      final f = await t.query('ventas', where: 'id = ?', whereArgs: [id]);
      if (f.isEmpty) throw StateError('no existe');
      final o = f.first;
      if (o['tipo'] == 'anulacion') throw StateError('es una anulacion');
      if (LocalDb._int(await t.rawQuery('SELECT COUNT(*) FROM ventas WHERE anula = ?', [id])) > 0) {
        throw StateError('ya anulado');
      }
      // Con factura electrónica no se anula así (iría con nota crédito).
      if (LocalDb._int(await t.rawQuery("SELECT COUNT(*) FROM facturas_e WHERE venta_id = ? AND estado <> 'rechazado'", [id])) > 0) {
        throw StateError('facturada');
      }
      var concepto = 'Anulación: ${o['concepto']}';
      final m = motivo.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (m.isNotEmpty) concepto = '$concepto · $m';
      if (concepto.length > 120) concepto = '${concepto.substring(0, 117)}…';
      final fila = <String, Object?>{
        'id': nuevo,
        'cliente_id': o['cliente_id'],
        'concepto': concepto,
        'monto': o['monto'],
        'tipo': 'anulacion',
        'credito': 0,
        'fecha': _ahora(),
        'anula': id,
        'anula_tipo': o['tipo'],
        if (autoriza.trim().isNotEmpty) 'autoriza': autoriza.trim(),
        ..._quien,
      };
      await t.insert('ventas', {...fila, 'pagos': o['pagos'], 'sync': 'pendiente'});
      final pagos = o['pagos'] is String ? jsonDecode(o['pagos'] as String) : null;
      await _enqueue(t, 'ventas', nuevo, {...fila, 'credito': false, 'pagos': pagos});
      // Lo vendido vuelve al inventario, al mismo precio y costo.
      final vendidos = await t.query('inventario',
          where: "venta_id = ? AND motivo = 'venta'", whereArgs: [id], orderBy: 'rowid');
      for (final x in vendidos) {
        await _insertarInventario(
            t,
            _filaInventario(newId(), x['producto_id'] as String, -(x['cantidad'] as num).toDouble(), 'anulacion',
                ventaId: id,
                precio: (x['precio_unit'] as num?)?.toDouble(),
                costo: (x['costo_unit'] as num?)?.toDouble()));
      }
    });
    _avisar();
    return nuevo;
  }

  /// Productos de una venta (para devolver algunos): id, nombre, cantidad
  /// vendida, precio y costo unitarios con el descuento ya repartido.
  Future<List<ItemVenta>> productosDeVenta(String ventaId) async {
    final r = await db.rawQuery(
        'SELECT i.producto_id, p.nombre, p.unidad, -i.cantidad AS cantidad, i.precio_unit, i.costo_unit '
        "FROM inventario i JOIN productos p ON p.id = i.producto_id WHERE i.venta_id = ? AND i.motivo = 'venta' "
        'ORDER BY i.rowid',
        [ventaId]);
    return [
      for (final x in r)
        ItemVenta(
          productoId: x['producto_id'] as String,
          nombre: x['nombre'] as String,
          cantidad: LocalDb._dbl(x['cantidad']),
          precio: LocalDb._dbl(x['precio_unit']),
          costo: LocalDb._dbl(x['costo_unit']),
          unidad: (x['unidad'] as String?) ?? 'und',
        ),
    ];
  }

  /// Devuelve algunos productos de una venta. Como las ventas solo se
  /// agregan, se hace así: se anula la venta completa (todo vuelve al
  /// inventario) y se registra una venta nueva con lo que el cliente se
  /// queda, al mismo precio, del mismo cliente y con el mismo medio de pago.
  /// [devueltos] es producto → cantidad devuelta. Devuelve cuánto dinero se
  /// le regresa (o se le descuenta de la deuda, si era fiado) y el id de la
  /// venta nueva (null si devolvió todo).
  Future<({double devolver, String? nuevaVenta})> devolverProductos(
      String ventaId, Map<String, double> devueltos,
      {String motivo = '', String autoriza = ''}) async {
    final f = await db.query('ventas', where: 'id = ?', whereArgs: [ventaId]);
    if (f.isEmpty) throw StateError('no existe');
    final o = f.first;
    if (o['tipo'] != 'ingreso') throw StateError('no es una venta');
    final items = await productosDeVenta(ventaId);
    if (items.isEmpty) throw StateError('sin productos');
    final quedan = <ItemVenta>[];
    var hayDevolucion = false;
    for (final i in items) {
      final d = (devueltos[i.productoId] ?? 0).clamp(0, i.cantidad).toDouble();
      if (d > 0) hayDevolucion = true;
      final q = ((i.cantidad - d) * 1000).round() / 1000;
      if (q > 0) {
        quedan.add(ItemVenta(
            productoId: i.productoId,
            nombre: i.nombre,
            cantidad: q,
            precio: i.precio,
            costo: i.costo,
            unidad: i.unidad));
      }
    }
    if (!hayDevolucion) throw ArgumentError('devueltos');
    final total = LocalDb._dbl(o['monto']);
    final m = motivo.trim();
    await anular(ventaId, motivo: m.isEmpty ? 'devolución' : 'devolución · $m', autoriza: autoriza);
    if (quedan.isEmpty) return (devolver: total, nuevaVenta: null);
    final nuevo = quedan.fold(0.0, (s, i) => s + i.total);
    final fiado = (o['credito'] as int? ?? 0) == 1;
    final antes = leerPagos(o['pagos'], monto: total, tipo: 'ingreso', credito: fiado);
    final medio = antes.any((p) => p.medio == 'efectivo')
        ? 'efectivo'
        : (antes.isEmpty ? 'efectivo' : antes.first.medio);
    final id = await saveVentaProductos(quedan,
        fiado: fiado,
        clienteId: o['cliente_id'] as String?,
        concepto: 'Tras devolución: ${quedan.map((i) => '${cantidadDoc(i.cantidad)} × ${i.nombre}').join(', ')}',
        pagos: fiado ? null : [Pago(medio, nuevo)]);
    return (devolver: ((total - nuevo) * 100).round() / 100, nuevaVenta: id);
  }

  // ----------------------------------------------------------------- turnos

  /// Abre un turno con la base de efectivo que hay en el cajón.
  Future<Turno> abrirTurno(double base) async {
    if (!this.puede(Permiso.venderContado)) throw StateError('permiso');
    if (turnoAbierto.value != null) throw StateError('ya hay un turno abierto');
    if (!base.isFinite || base < 0) throw ArgumentError('base');
    final fila = {
      'id': newId(),
      'perfil': _perfilNombre,
      'abre': _ahora(),
      'base': base,
      'sync': 'local',
    };
    await db.insert('turnos', fila);
    turnoAbierto.value = Turno.desdeFila(fila);
    _avisar();
    return turnoAbierto.value!;
  }

  /// El efectivo que debería haber en el cajón del turno abierto.
  Future<EfectivoTurno?> efectivoTurnoAbierto() async {
    final t = turnoAbierto.value;
    if (t == null) return null;
    return efectivoDelTurno(
        t.base, await db.query('ventas_netas', where: 'turno = ?', whereArgs: [t.id]));
  }

  /// Cierra el turno con el efectivo contado. Se sube a la nube completo.
  Future<Turno> cerrarTurno(double contado, {String nota = ''}) async {
    final t = turnoAbierto.value;
    if (t == null) throw StateError('no hay turno abierto');
    if (!contado.isFinite || contado < 0) throw ArgumentError('contado');
    final ef = (await efectivoTurnoAbierto())!;
    final n = nota.trim();
    final cierre = {
      'cierra': _ahora(),
      'esperado': (ef.esperado * 100).roundToDouble() / 100,
      'contado': contado,
      'nota': n.length > 200 ? n.substring(0, 200) : n,
    };
    await db.transaction((x) async {
      await x.update('turnos', {...cierre, 'sync': 'pendiente'}, where: 'id = ?', whereArgs: [t.id]);
      await _enqueue(x, 'turnos', t.id, {
        'id': t.id,
        'perfil': t.perfil,
        'abre': isoUtc(t.abre),
        'base': t.base,
        ...cierre,
      });
    });
    turnoAbierto.value = null;
    _avisar();
    return Turno.desdeFila((await db.query('turnos', where: 'id = ?', whereArgs: [t.id])).first);
  }

  /// Turnos cerrados, del más reciente al más viejo (de este celular y, para
  /// quien puede ver informes, de los demás).
  Future<List<Turno>> turnos({int limite = 100}) async => [
        for (final f in await db.query('turnos', where: 'cierra IS NOT NULL', orderBy: 'cierra DESC', limit: limite))
          Turno.desdeFila(f)
      ];

  Future<void> aplicarTurnosRemotos(List<Map<String, dynamic>> filas) async {
    if (filas.isEmpty) return;
    final b = db.batch();
    for (final f in filas) {
      final abre = DateTime.tryParse('${f['abre']}');
      final cierra = DateTime.tryParse('${f['cierra']}');
      if (abre == null || cierra == null || f['id'] is! String) continue;
      b.insert(
          'turnos',
          {
            'id': f['id'],
            'perfil': (f['perfil'] as String?) ?? '',
            'abre': isoUtc(abre),
            'cierra': isoUtc(cierra),
            'base': (f['base'] as num?)?.toDouble() ?? 0,
            'esperado': (f['esperado'] as num?)?.toDouble() ?? 0,
            'contado': (f['contado'] as num?)?.toDouble() ?? 0,
            'nota': (f['nota'] as String?) ?? '',
            'sync': 'enviado',
          },
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await b.commit(noResult: true);
    _avisar();
  }

  // ------------------------------------------------------------- descuentos

  /// Revisa el descuento de una venta según el rol y el tope del dueño.
  void _validarDescuento(double descuento, double total) {
    if (descuento == 0) return;
    if (!this.puede(Permiso.aplicarDescuento)) throw ArgumentError('descuento');
    final e = problemaDescuento(descuento, total,
        topePct: equipo.value.descuentoMaxPct, libre: libreDeTope(equipo.value, perfilActivo.value?.rol));
    if (e != null) throw ArgumentError('descuento');
  }
}
