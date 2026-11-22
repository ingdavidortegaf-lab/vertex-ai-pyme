part of 'local_db.dart';

/// Cotizaciones: guardar, convertir en venta y borrar.
extension LocalDbCotizaciones on LocalDb {
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


  /// Convierte la cotización en venta (descuenta inventario) y la marca.
  Future<String> venderCotizacion(String id,
      {bool fiado = false, List<Pago>? pagos}) async {
    final r = await db.query('cotizaciones', where: 'id = ?', whereArgs: [id]);
    if (r.isEmpty) throw ArgumentError('cotizacion');
    final c = r.first;
    if (c['estado'] == 'vendida') throw StateError('ya vendida');
    final ventaId = await saveVentaProductos(LocalDb.itemsCotizacion(c),
        fiado: fiado, clienteId: c['cliente_id'] as String?, pagos: pagos);
    await db.update('cotizaciones', {'estado': 'vendida', 'venta_id': ventaId},
        where: 'id = ?', whereArgs: [id]);
    _avisar();
    return ventaId;
  }

  Future<void> deleteCotizacion(String id) async {
    await db.delete('cotizaciones', where: 'id = ?', whereArgs: [id]);
    _avisar();
  }
}
