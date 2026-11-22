part of 'local_db.dart';

/// Cambios que llegan de la nube: unión campo por campo o se agregan sin duplicar.
extension LocalDbNube on LocalDb {
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
      if (monto <= 0 || !LocalDb.tiposMovimiento.contains(tipo) || fecha == null) {
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
            'pagos': f['pagos'] == null
                ? null
                : f['pagos'] is String
                    ? f['pagos']
                    : jsonEncode(f['pagos']),
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
          !LocalDb.motivosInventario.contains(f['motivo']) ||
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
}
