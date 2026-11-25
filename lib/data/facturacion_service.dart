import 'dart:convert';
import '../domain/facturacion.dart';
import 'local_db.dart';

/// Envía la cola de facturas electrónicas al proveedor. Sin proveedor o sin
/// internet no se pierde nada: las facturas esperan y se reintentan.
class FacturacionService {
  static const sinProveedor = 'Sin proveedor de facturación configurado';

  static Future<void> procesarCola(LocalDb db, ProveedorFacturacion p) async {
    for (final f in await db.colaFacturas()) {
      final id = f['id'] as String;
      if (!p.configurado) {
        if (f['mensaje'] != sinProveedor) await db.registrarIntentoFE(id, sinProveedor);
        continue;
      }
      try {
        final r = f['estado'] == EstadoFE.enviado.name && f['id_externo'] != null
            ? await p.consultar(f['id_externo'] as String)
            : await p.emitir(
                facturaDesdeMapa(jsonDecode(f['payload'] as String) as Map<String, dynamic>));
        // «Aceptada» sin CUFE no sirve como factura: se sigue preguntando.
        if (r.estado == EstadoFE.aceptado && (r.cufe ?? '').isEmpty) {
          await db.registrarRespuestaFE(
              id,
              RespuestaFE(
                  estado: EstadoFE.enviado,
                  idExterno: r.idExterno,
                  mensaje: 'Aceptada sin CUFE; se vuelve a consultar'));
        } else {
          await db.registrarRespuestaFE(id, r);
        }
      } on SinRespuestaFE catch (e) {
        await db.registrarIntentoFE(id, e.motivo);
      }
    }
  }
}
