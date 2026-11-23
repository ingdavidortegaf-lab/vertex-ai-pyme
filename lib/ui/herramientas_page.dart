import 'package:flutter/material.dart';
import '../domain/identificacion.dart' as ident;
import 'pagos_fijos_page.dart';
import 'terceros_page.dart';
import 'package:intl/intl.dart';
import '../data/local_db.dart';
import '../domain/roles.dart';
import '../data/sync_service.dart';
import '../domain/documentos.dart';
import '../domain/formato.dart';
import '../domain/resumen.dart';
import 'comun.dart';
import 'escaner.dart';
import '../pdf/archivo.dart';
import 'oficina_page.dart';
import 'pago_widget.dart';
import 'promocion_page.dart';
import 'seguimiento_page.dart';
import '../domain/pagos.dart';
import '../pdf/pdf_factura.dart';
import '../domain/codigos.dart';
import 'tema.dart';
import 'ventas_page.dart';

part 'herramientas_carrito.dart';
part 'herramientas_cotizaciones.dart';
part 'herramientas_documentos.dart';
part 'herramientas_pedido.dart';

// Herramientas para que el tendero maneje casi todo desde la app y por
// WhatsApp: comprobantes de venta, cotizaciones, pedidos al proveedor (con
// ingreso de la mercancía) y promociones.

/// Accesos a las herramientas, para el Inicio.
/// Permiso que pide cada herramienta del menú (por su título).
const _permisoHerramienta = {
  'Pagos fijos': Permiso.pagosFijos,
  'Proveedores y terceros': Permiso.verProveedores,
  'Cierre de caja': Permiso.verGastos,
  'Comprobantes': Permiso.verVentas,
  'Cotizaciones': Permiso.cotizaciones,
  'Pedir mercancía': Permiso.gestionarProveedores,
  'Lo que debo': Permiso.verGastos,
  'Promociones': Permiso.promociones,
  'Seguimiento': Permiso.seguimiento,
  'Informes': Permiso.verInformes,
  'Cartera': Permiso.verClientes,
  'Documentos': Permiso.verVentas,
};

class HerramientasGrid extends StatelessWidget {
  const HerramientasGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    void ir(Widget w) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    final modo = LocalDb.instance.modo.value;
    final items = [
      (
        Icons.event_repeat_outlined,
        'Pagos fijos',
        'Arriendo, luz, agua, internet',
        p.gastosFondo,
        p.gastos,
        () => ir(const PagosFijosPage())
      ),
      (
        Icons.storefront_outlined,
        'Proveedores y terceros',
        'NIT, celular y correo',
        p.asistenteFondo,
        p.asistente,
        () => ir(const TercerosPage())
      ),
      (
        Icons.point_of_sale_outlined,
        'Cierre de caja',
        'Efectivo, Nequi, bancos y tarjetas',
        p.ventasFondo,
        p.ventas,
        () => ir(const CierreCajaPage())
      ),
      (
        Icons.receipt_outlined,
        'Comprobantes',
        'Envía la venta por WhatsApp',
        p.ventasFondo,
        p.ventas,
        () => ir(const ComprobantesPage())
      ),
      (
        Icons.request_quote_outlined,
        'Cotizaciones',
        'Arma y envía precios',
        p.asistenteFondo,
        p.asistente,
        () => ir(const CotizacionesPage())
      ),
      if (modo.vendeProductos && modo.pedidos)
        (
          Icons.local_shipping_outlined,
          'Pedir mercancía',
          'Pedido sugerido al proveedor',
          p.fiadoFondo,
          p.fiado,
          () => ir(const PedidoProveedorPage())
        ),
      if (modo.vendeProductos && modo.pedidos)
        (
          Icons.account_balance_outlined,
          'Lo que debo',
          'Proveedores: saldos y abonos',
          p.gastosFondo,
          p.gastos,
          () => ir(const CuentasPagarPage())
        ),
      (
        Icons.campaign_outlined,
        'Promociones',
        'Ofertas para tu WhatsApp',
        p.gastosFondo,
        p.gastos,
        () => ir(const PromocionPage())
      ),
      (
        Icons.connect_without_contact_outlined,
        'Seguimiento',
        'A quién escribirle hoy',
        p.ventasFondo,
        p.ventas,
        () => ir(const SeguimientoPage())
      ),
      (
        Icons.insert_chart_outlined,
        'Informes',
        'Semana, quincena y mes en PDF',
        p.ventasFondo,
        p.ventas,
        () => ir(const InformesPage())
      ),
      if (modo.fia)
        (
          Icons.account_balance_wallet_outlined,
          'Cartera',
          'Quién debe y desde cuándo',
          p.fiadoFondo,
          p.fiado,
          () => ir(const CarteraPage())
        ),
      (
        Icons.folder_open_outlined,
        'Documentos',
        'Todo lo emitido, con su número',
        p.asistenteFondo,
        p.asistente,
        () => ir(const DocumentosPage())
      ),
    ];
    // Cada herramienta se ve solo si el rol la permite. Lo que no esté en la
    // tabla queda para el dueño (configurarNegocio), por seguridad.
    final db = LocalDb.instance;
    final visibles = [
      for (final it in items)
        if (db.puede(_permisoHerramienta[it.$2] ?? Permiso.configurarNegocio))
          it
    ];
    if (visibles.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, box) {
      final ancho = (box.maxWidth - 10) / 2;
      return Wrap(spacing: 10, runSpacing: 10, children: [
        for (final (i, (icono, titulo, sub, fondo, tinta, onTap))
            in visibles.indexed)
          Aparecer(
            orden: i,
            child: SizedBox(
              width: ancho,
              child: Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                                color: fondo,
                                borderRadius: BorderRadius.circular(12)),
                            child: Icon(icono, color: tinta, size: 22),
                          ),
                          const SizedBox(height: 10),
                          Text(titulo,
                              style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 2),
                          SizedBox(
                            height: 34,
                            child: Text(sub,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant)),
                          ),
                        ]),
                  ),
                ),
              ),
            ),
          ),
      ]);
    });
  }
}
