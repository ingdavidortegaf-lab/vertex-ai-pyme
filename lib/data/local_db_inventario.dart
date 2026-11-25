part of 'local_db.dart';

/// Productos e inventario: el stock es la suma de los movimientos; venta con productos.
extension LocalDbInventario on LocalDb {
  // ------------------------------------------------------------ inventario

  Future<List<ProductoStock>> productos() async {
    final r = await db.rawQuery(
        'SELECT p.*, ${LocalDb._stockSql} AS stock FROM productos p WHERE p.deleted = 0 '
        'ORDER BY p.nombre COLLATE NOCASE');
    return [
      for (final x in r)
        ProductoStock(
          id: x['id'] as String,
          nombre: x['nombre'] as String,
          precio: LocalDb._dbl(x['precio']),
          costo: LocalDb._dbl(x['costo']),
          minimo: LocalDb._dbl(x['minimo']),
          stock: LocalDb._dbl(x['stock']),
          sync: x['sync'] as String? ?? 'pendiente',
          codigo: (x['codigo'] as String?) ?? '',
          unidad: (x['unidad'] as String?) ?? 'und',
          iva: LocalDb._dbl(x['iva'] ?? -1),
          precioMayor: LocalDb._dbl(x['precio_mayor']),
          cantidadMayor: LocalDb._dbl(x['cantidad_mayor']),
          vence: (x['vence'] as String?) ?? '',
        )
    ];
  }

  Map<String, Object?> _filaInventario(String id, String productoId,
          double cantidad, String motivo,
          {String? ventaId, double? precio, double? costo}) =>
      {
        'id': id,
        'producto_id': productoId,
        'cantidad': cantidad,
        'motivo': motivo,
        'venta_id': ventaId,
        'precio_unit': precio,
        'costo_unit': costo,
        'fecha': _ahora(),
      };

  Future<void> _insertarInventario(
      DatabaseExecutor t, Map<String, Object?> fila) async {
    await t.insert('inventario', {...fila, 'sync': 'pendiente'});
    await _enqueue(t, 'inventario', fila['id'] as String, fila);
  }

  /// Crea o edita un producto. Solo cambia la marca de tiempo de los campos
  /// que cambiaron. [stockInicial] (al crear) se registra como entrada.
  Future<String> saveProducto(String nombre,
      {required double precio,
      double costo = 0,
      double minimo = 0,
      double stockInicial = 0,
      String codigo = '',
      String unidad = 'und',
      double? iva,
      double? precioMayor,
      double? cantidadMayor,
      String? vence,
      String? id}) async {
    if (nombre.trim().isEmpty) throw ArgumentError('nombre');
    if (iva != null && !ivaValido(iva)) throw ArgumentError('iva');
    for (final x in [precioMayor, cantidadMayor]) {
      if (x != null && (!x.isFinite || x < 0)) throw ArgumentError('mayor');
    }
    if (vence != null && vence.isNotEmpty && fechaVenceValida(vence) != vence) {
      throw ArgumentError('vence');
    }
    if (!ProductoCampos.unidades.contains(unidad)) throw ArgumentError('unidad');
    if (!precio.isFinite || precio < 0 || !costo.isFinite || costo < 0) {
      throw ArgumentError('precio');
    }
    final pid = id ?? newId();
    final ts = _ahora();
    var cambio = false;
    await db.transaction((t) async {
      final prev = await t.query('productos', where: 'id = ?', whereArgs: [pid]);
      final nuevos = <String, Object>{
        'nombre': nombre.trim(),
        'precio': precio,
        'costo': costo,
        'minimo': minimo < 0 ? 0 : minimo,
        'codigo': codigo.replaceAll(RegExp(r'\s'), ''),
        'unidad': unidad,
        // Si no se dice, el IVA se deja como estaba (al crear: sin definir).
        if (iva != null) 'iva': iva,
        if (precioMayor != null) 'precio_mayor': precioMayor,
        if (cantidadMayor != null) 'cantidad_mayor': cantidadMayor,
        if (vence != null) 'vence': vence,
      };
      final Map<String, Object?> row;
      if (prev.isEmpty) {
        row = {
          'id': pid,
          ...nuevos,
          'deleted': 0,
          for (final c in ProductoCampos.campos) '${c}_ts': ts,
          'updated_at': ts,
          'sync': 'pendiente',
        };
        await t.insert('productos', row);
        if (stockInicial > 0) {
          await _insertarInventario(
              t, _filaInventario(newId(), pid, stockInicial, 'entrada', costo: costo));
        }
      } else {
        row = Map<String, Object?>.of(prev.first);
        for (final e in nuevos.entries) {
          if (row[e.key] != e.value) {
            row[e.key] = e.value;
            row['${e.key}_ts'] = ts;
            cambio = true;
          }
        }
        if (!cambio) return;
        row['updated_at'] = ts;
        row['sync'] = 'pendiente';
        await t.update('productos', row, where: 'id = ?', whereArgs: [pid]);
      }
      cambio = true;
      await _enqueue(t, 'productos', pid, ProductoCampos.fromLocal(row).toRemote());
    });
    if (cambio) _avisar();
    return pid;
  }

  /// Importa productos pegados desde Excel. Si ya existe uno con el mismo
  /// código (o, sin código, con el mismo nombre) se actualizan sus datos y
  /// NO se toca su stock; los nuevos entran con su stock inicial.
  Future<({int nuevos, int actualizados})> importarProductos(List<FilaImportada> filas) async {
    final existentes = await productos();
    final porCodigo = {for (final p in existentes) if (p.codigo.isNotEmpty) p.codigo: p};
    final porNombre = {for (final p in existentes) p.nombre.toLowerCase(): p};
    var nuevos = 0, actualizados = 0;
    for (final f in filas) {
      final ya = (f.codigo.isNotEmpty ? porCodigo[f.codigo] : null) ?? porNombre[f.nombre.toLowerCase()];
      final id = await saveProducto(f.nombre,
          precio: f.precio,
          costo: f.costo > 0 ? f.costo : (ya?.costo ?? 0),
          minimo: f.minimo > 0 ? f.minimo : (ya?.minimo ?? 0),
          stockInicial: ya == null ? f.stock : 0,
          codigo: f.codigo.isNotEmpty ? f.codigo : (ya?.codigo ?? ''),
          unidad: f.unidad,
          iva: f.iva >= 0 ? f.iva : null,
          precioMayor: f.precioMayor > 0 ? f.precioMayor : null,
          cantidadMayor: f.cantidadMayor > 0 ? f.cantidadMayor : null,
          id: ya?.id);
      if (ya == null) {
        nuevos++;
        final p = ProductoStock(id: id, nombre: f.nombre, codigo: f.codigo);
        if (f.codigo.isNotEmpty) porCodigo[f.codigo] = p;
        porNombre[f.nombre.toLowerCase()] = p;
      } else {
        actualizados++;
      }
    }
    return (nuevos: nuevos, actualizados: actualizados);
  }

  Future<void> deleteProducto(String id) async {
    final ts = _ahora();
    await db.transaction((t) async {
      final prev = await t.query('productos', where: 'id = ?', whereArgs: [id]);
      if (prev.isEmpty) return;
      final row = Map<String, Object?>.of(prev.first)
        ..['deleted'] = 1
        ..['deleted_ts'] = ts
        ..['updated_at'] = ts
        ..['sync'] = 'pendiente';
      await t.update('productos', row, where: 'id = ?', whereArgs: [id]);
      await _enqueue(t, 'productos', id, ProductoCampos.fromLocal(row).toRemote());
    });
    _avisar();
  }

  /// Entrada de mercancía (cantidad > 0) o ajuste por conteo (+/−).
  Future<void> moverStock(String productoId, double cantidad,
      {String motivo = 'entrada', double? costo}) async {
    if (!cantidad.isFinite || cantidad == 0) throw ArgumentError('cantidad');
    if (motivo == 'entrada' && cantidad < 0) throw ArgumentError('cantidad');
    if (!LocalDb.motivosInventario.contains(motivo) || motivo == 'venta') {
      throw ArgumentError('motivo');
    }
    await db.transaction((t) => _insertarInventario(
        t, _filaInventario(newId(), productoId, cantidad, motivo, costo: costo)));
    _avisar();
  }

  /// Venta con productos: un movimiento de venta por el total y una salida de
  /// inventario por cada producto, todo en una sola transacción.
  Future<String> saveVentaProductos(List<ItemVenta> items,
      {bool fiado = false,
      String? clienteId,
      String? concepto,
      List<Pago>? pagos,
      double descuento = 0}) async {
    final validos = items.where((i) => i.cantidad > 0).toList();
    if (validos.isEmpty) throw ArgumentError('items');
    if (fiado && clienteId == null) throw ArgumentError('cliente');
    final bruto = validos.fold(0.0, (s, i) => s + i.total);
    if (bruto <= 0) throw ArgumentError('monto');
    _validarDescuento(descuento, bruto);
    // El descuento se reparte en el precio de cada producto: así la
    // ganancia por producto también lo refleja.
    final total = bruto - descuento;
    final factor = total / bruto;
    String cant(double c) =>
        c == c.roundToDouble() ? c.toInt().toString() : c.toString();
    var texto = concepto?.trim().isNotEmpty == true
        ? concepto!.trim()
        : validos.map((i) => '${cant(i.cantidad)} × ${i.nombre}').join(', ');
    if (texto.length > 120) texto = '${texto.substring(0, 117)}…';
    final medios = LocalDb._pagosDe('ingreso', fiado, total, pagos);
    final id = newId();
    final venta = <String, Object?>{
      'id': id,
      'cliente_id': clienteId,
      'concepto': texto,
      'monto': total,
      'tipo': 'ingreso',
      'credito': fiado ? 1 : 0,
      'fecha': _ahora(),
      if (descuento > 0) 'descuento': descuento,
      ..._quien,
    };
    await db.transaction((t) async {
      await t.insert('ventas', {
        ...venta,
        'pagos': medios == null ? null : codificarPagos(medios),
        'sync': 'pendiente'
      });
      await _enqueue(t, 'ventas', id, {
        ...venta,
        'credito': fiado,
        'pagos': medios?.map((p) => p.aMapa()).toList(),
      });
      for (final i in validos) {
        await _insertarInventario(
            t,
            _filaInventario(newId(), i.productoId, -i.cantidad, 'venta',
                ventaId: id, precio: i.precio * factor, costo: i.costo));
      }
    });
    _avisar();
    return id;
  }
}
