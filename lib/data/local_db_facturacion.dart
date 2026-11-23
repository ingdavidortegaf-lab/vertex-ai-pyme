part of 'local_db.dart';

/// Factura electrónica (solo en este celular): datos del emisor y la cola.
/// Falta: armar la factura desde una venta, procesar la cola con el
/// proveedor y mostrar CUFE/QR en el PDF.
extension LocalDbFacturacion on LocalDb {
  Future<DatosEmisor> datosEmisor() async =>
      DatosEmisor.desdeAjustes({for (final c in DatosEmisor.claves) c: await ajuste(c)});

  Future<void> guardarEmisor(DatosEmisor e) async {
    for (final x in e.aAjustes().entries) {
      await setAjuste(x.key, x.value);
    }
  }

  Future<List<FacturaEmitida>> facturas({int limite = 200}) async => [
        for (final f in await db.query('facturas_e', orderBy: 'consecutivo DESC', limit: limite))
          FacturaEmitida.desdeFila(f)
      ];

  Future<FacturaEmitida?> facturaDeVenta(String ventaId) async {
    final f = await db.query('facturas_e', where: 'venta_id = ?', whereArgs: [ventaId]);
    return f.isEmpty ? null : FacturaEmitida.desdeFila(f.first);
  }
}
