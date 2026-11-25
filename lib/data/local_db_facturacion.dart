part of 'local_db.dart';

/// Factura electrónica (solo en este celular): datos del emisor, armar la
/// factura de una venta y la cola de emisión, que funciona sin internet: lo
/// que no se pudo enviar espera y se reintenta al sincronizar.
extension LocalDbFacturacion on LocalDb {
  Future<DatosEmisor> datosEmisor() async =>
      DatosEmisor.desdeAjustes({for (final c in DatosEmisor.claves) c: await ajuste(c)});

  Future<void> guardarEmisor(DatosEmisor e) async {
    for (final x in e.aAjustes().entries) {
      await setAjuste(x.key, x.value);
    }
    _avisar();
  }

  Future<List<FacturaEmitida>> facturas({int limite = 200}) async => [
        for (final f in await db.query('facturas_e', orderBy: 'consecutivo DESC', limit: limite))
          FacturaEmitida.desdeFila(f)
      ];

  Future<FacturaEmitida?> facturaDeVenta(String ventaId) async {
    final f = await db.query('facturas_e', where: 'venta_id = ?', whereArgs: [ventaId]);
    return f.isEmpty ? null : FacturaEmitida.desdeFila(f.first);
  }

  /// Arma la factura electrónica de una venta y la deja en la cola. Si la
  /// venta no tiene productos, [ivaSinProductos] dice su IVA (lo escoge el
  /// dueño: la app no supone tarifas).
  Future<FacturaEmitida> encolarFactura(String ventaId, {double? ivaSinProductos}) async {
    if (!this.puede(Permiso.configurarNegocio)) {
      throw const ErrorFactura('Solo el dueño o el administrador emiten facturas electrónicas');
    }
    final emisor = await datosEmisor();
    final faltan = emisor.faltantes();
    if (faltan.isNotEmpty) {
      throw ErrorFactura('Faltan datos del negocio para facturar: ${faltan.join(', ')}');
    }
    final vs = await db.query('ventas', where: 'id = ?', whereArgs: [ventaId]);
    if (vs.isEmpty || vs.first['tipo'] != 'ingreso') throw const ErrorFactura('Solo se facturan ventas');
    final v = vs.first;
    if (await estaAnulado(ventaId)) throw const ErrorFactura('La venta está anulada');
    if (await facturaDeVenta(ventaId) != null) {
      throw const ErrorFactura('Esta venta ya tiene factura electrónica');
    }

    final clienteId = v['cliente_id'] as String?;
    final cs = clienteId == null
        ? const <Map<String, Object?>>[]
        : await db.query('clientes', where: 'id = ?', whereArgs: [clienteId]);
    final c = cs.isEmpty ? null : cs.first;
    if (c == null || ((c['documento'] as String?) ?? '').trim().isEmpty) {
      throw const ErrorFactura(
          'La factura electrónica necesita un cliente con tipo y número de documento');
    }
    final comprador = CompradorFE(
      nombre: c['nombre'] as String,
      tipoDoc: (c['tipo_doc'] as String?) ?? 'CC',
      documento: (c['documento'] as String).trim(),
      correo: (c['correo'] as String?) ?? '',
    );

    final items = await db.rawQuery(
        'SELECT i.cantidad, i.precio_unit, p.nombre, p.unidad, p.iva FROM inventario i '
        'JOIN productos p ON p.id = i.producto_id '
        "WHERE i.venta_id = ? AND i.motivo = 'venta' ORDER BY i.rowid",
        [ventaId]);
    final lineas = <LineaFE>[];
    if (items.isEmpty) {
      if (ivaSinProductos == null) throw const ErrorFactura('Indica el IVA de esta venta');
      if (ivaSinProductos < 0 || !ivaValido(ivaSinProductos)) {
        throw const ErrorFactura('El IVA va de 0 a 100 %');
      }
      lineas.add(LineaFE(
          descripcion: v['concepto'] as String,
          cantidad: 1,
          unidad: 'und',
          precioConIva: LocalDb._dbl(v['monto']),
          ivaPct: ivaSinProductos));
    } else {
      final sinIva = {
        for (final x in items)
          if (LocalDb._dbl(x['iva']) < 0) x['nombre'] as String
      };
      if (sinIva.isNotEmpty) {
        throw ErrorFactura('Falta el IVA de: ${sinIva.join(', ')}. Escríbelo en cada producto.');
      }
      for (final x in items) {
        lineas.add(LineaFE(
            descripcion: x['nombre'] as String,
            cantidad: -LocalDb._dbl(x['cantidad']),
            unidad: (x['unidad'] as String?) ?? 'und',
            precioConIva: LocalDb._dbl(x['precio_unit']),
            ivaPct: LocalDb._dbl(x['iva'])));
      }
    }

    final pagosRaw = v['pagos'] is String ? jsonDecode(v['pagos'] as String) : null;
    final id = newId();
    late FacturaEmitida r;
    await db.transaction((t) async {
      final ult = await t.rawQuery('SELECT MAX(consecutivo) m FROM facturas_e');
      final n = siguienteNumero(emisor, (ult.first['m'] as num?)?.toInt(), reloj());
      if (n.error != null) throw ErrorFactura(n.error!);
      final f = FacturaElectronica(
        id: id,
        ventaId: ventaId,
        numero: '${emisor.prefijo}${n.numero}',
        fecha: reloj(),
        emisor: emisor,
        comprador: comprador,
        lineas: lineas,
        pagos: [
          for (final p in (pagosRaw as List? ?? const [])) Map<String, Object?>.from(p as Map)
        ],
      );
      final ahora = _ahora();
      final fila = <String, Object?>{
        'id': id,
        'venta_id': ventaId,
        'numero': f.numero,
        'consecutivo': n.numero,
        'estado': EstadoFE.pendiente.name,
        'payload': jsonEncode(f.aMapa()),
        'total': f.total,
        'comprador': comprador.nombre,
        'creado': ahora,
        'actualizado': ahora,
      };
      await t.insert('facturas_e', fila);
      r = FacturaEmitida.desdeFila(fila);
    });
    _avisar();
    return r;
  }

  /// Facturas que faltan por enviar o por saber si la DIAN las aceptó.
  Future<List<Map<String, Object?>>> colaFacturas() => db.query('facturas_e',
      where: "estado IN ('pendiente','enviado')", orderBy: 'consecutivo');

  Future<void> registrarRespuestaFE(String id, RespuestaFE r) async {
    await db.update(
        'facturas_e',
        {
          'estado': r.estado.name,
          if (r.idExterno != null) 'id_externo': r.idExterno,
          if (r.cufe != null) 'cufe': r.cufe,
          if (r.qr != null) 'qr': r.qr,
          'mensaje': r.mensaje,
          'actualizado': _ahora(),
        },
        where: 'id = ?',
        whereArgs: [id]);
    _avisar();
  }

  /// Sin respuesta del proveedor: se queda en la cola con el motivo.
  Future<void> registrarIntentoFE(String id, String motivo) async {
    await db.rawUpdate(
        'UPDATE facturas_e SET intentos = intentos + 1, mensaje = ?, actualizado = ? WHERE id = ?',
        [motivo, _ahora(), id]);
  }

  /// Una rechazada vuelve a la cola (con el mismo número) después de corregir.
  Future<void> reintentarFactura(String id) async {
    await db.update('facturas_e',
        {'estado': EstadoFE.pendiente.name, 'mensaje': '', 'actualizado': _ahora()},
        where: "id = ? AND estado = 'rechazado'", whereArgs: [id]);
    _avisar();
  }

  /// Quita de la cola una factura que nunca se envió, solo si es la última
  /// numerada (así no quedan huecos en la numeración).
  Future<bool> quitarFacturaPendiente(String id) async {
    final f = await db.query('facturas_e',
        where: "id = ? AND estado = 'pendiente' AND id_externo IS NULL", whereArgs: [id]);
    if (f.isEmpty) return false;
    final ult = await db.rawQuery('SELECT MAX(consecutivo) m FROM facturas_e');
    if ((ult.first['m'] as num?)?.toInt() != f.first['consecutivo']) return false;
    await db.delete('facturas_e', where: 'id = ?', whereArgs: [id]);
    _avisar();
    return true;
  }
}
