/// Documentos que la tienda envía por WhatsApp: comprobante de venta,
/// cotización, pedido al proveedor y promociones. Son funciones puras (sin
/// base de datos ni red) para poder probarlas.
///
/// El comprobante NO es una factura electrónica ante la DIAN: trae los mismos
/// datos (emisor, cliente, ítems, cantidades, precios, total y número) para
/// conectarlo después con un proveedor tecnológico autorizado.
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'codigos.dart';
import 'formato.dart';
import 'resumen.dart';

/// Datos del negocio que salen en los documentos.
class PerfilNegocio {
  final String nombre;
  final String tipo;
  final String nit;
  final String direccion;
  final String telefono;
  final double meta;

  /// Ruta del logo guardado en el celular (vacío si no hay).
  final String logo;
  const PerfilNegocio({
    this.logo = '',
    this.nombre = '',
    this.tipo = '',
    this.nit = '',
    this.direccion = '',
    this.telefono = '',
    this.meta = 0,
  });

  String get nombreVisible => nombre.trim().isEmpty ? 'Mi negocio' : nombre.trim();
}

/// El logo se guarda DENTRO de la base como texto («b64:» + la imagen en
/// base64). Así funciona igual en el celular, en Windows y en la versión
/// web (el navegador no deja guardar archivos sueltos). Los logos viejos,
/// guardados como ruta de archivo, siguen sirviendo en celular y PC.
const prefijoLogo = 'b64:';

String logoComoTexto(Uint8List bytes) => '$prefijoLogo${base64Encode(bytes)}';

/// Bytes del logo si está guardado en la base; null si es una ruta vieja o
/// no hay logo.
Uint8List? bytesDeLogo(String logo) {
  if (!logo.startsWith(prefijoLogo)) return null;
  try {
    return base64Decode(logo.substring(prefijoLogo.length));
  } catch (_) {
    return null;
  }
}

/// Línea de un documento (venta, cotización o pedido).
class LineaDoc {
  final String nombre;
  final double cantidad;
  final double precio;

  /// Unidad de venta (ver `nombresUnidad`).
  final String unidad;
  const LineaDoc(this.nombre, this.cantidad, this.precio, [this.unidad = 'und']);
  double get total => cantidad * precio;
  String get cantidadTexto => cantidadConUnidad(cantidad, unidad);
  String get precioTexto => precioConUnidad(precio, unidad);
}

String cantidadDoc(double c) =>
    c == c.roundToDouble() ? c.toInt().toString() : c.toStringAsFixed(1);

/// Número corto y único a partir del id del registro (no choca entre
/// celulares porque el id es un UUID).
String numeroDoc(String id) {
  final limpio = id.replaceAll('-', '').toUpperCase();
  return limpio.length >= 8 ? limpio.substring(0, 8) : limpio;
}

String _encabezado(PerfilNegocio n) {
  final datos = [
    if (n.nit.trim().isNotEmpty) 'NIT/C.C. ${n.nit.trim()}',
    if (n.direccion.trim().isNotEmpty) n.direccion.trim(),
    if (n.telefono.trim().isNotEmpty) 'Tel. ${n.telefono.trim()}',
  ];
  return '*${n.nombreVisible}*${datos.isEmpty ? '' : '\n${datos.join(' · ')}'}';
}

String _lineas(List<LineaDoc> l) => [
      for (final x in l)
        x.cantidad == 1 && !esFraccionable(x.unidad)
            ? '• ${x.nombre}: ${cop(x.total)}'
            : !esFraccionable(x.unidad)
                ? '• ${x.cantidadTexto} × ${x.nombre} (${x.precioTexto}): ${cop(x.total)}'
                : '• ${x.nombre} ${x.cantidadTexto} (${x.precioTexto}): ${cop(x.total)}'
    ].join('\n');

final _fecha = DateFormat('d/MM/y h:mm a', 'es_CO');

/// Comprobante de una venta, listo para WhatsApp.
String textoComprobante({
  required PerfilNegocio negocio,
  required String ventaId,
  required DateTime fecha,
  required List<LineaDoc> lineas,
  required double total,
  String? cliente,
  bool fiado = false,
  double saldoCliente = 0,
  String? formaPago,
  ({String numero, String cufe})? facturaElectronica,
}) {
  final b = StringBuffer()
    ..writeln(_encabezado(negocio))
    ..writeln()
    ..writeln(facturaElectronica == null
        ? '*Comprobante de venta N.º ${numeroDoc(ventaId)}*'
        : '*Factura electrónica de venta N.º ${facturaElectronica.numero}*')
    ..writeln('Fecha: ${_fecha.format(fecha)}');
  if (cliente != null && cliente.trim().isNotEmpty) b.writeln('Cliente: $cliente');
  b
    ..writeln()
    ..writeln(_lineas(lineas))
    ..writeln()
    ..writeln('*Total: ${cop(total)}*')
    ..writeln('Forma de pago: ${fiado ? 'a crédito (fiado)' : formaPago ?? 'contado'}');
  if (fiado && saldoCliente > 0) {
    b.writeln('Saldo pendiente a la fecha: ${cop(saldoCliente)}');
  }
  b
    ..writeln()
    ..writeln('¡Gracias por su compra!');
  if (facturaElectronica == null) {
    b.write('_Comprobante de venta; no es factura electrónica._');
  } else {
    b.write('CUFE: ${facturaElectronica.cufe}');
  }
  return b.toString();
}

/// Cotización con vigencia, lista para WhatsApp.
String textoCotizacion({
  required PerfilNegocio negocio,
  required String cotizacionId,
  required DateTime fecha,
  required List<LineaDoc> lineas,
  String? cliente,
  int diasVigencia = 8,
}) {
  final total = lineas.fold(0.0, (s, x) => s + x.total);
  final vence = DateFormat('d/MM/y', 'es_CO')
      .format(fecha.add(Duration(days: diasVigencia)));
  final b = StringBuffer()
    ..writeln(_encabezado(negocio))
    ..writeln()
    ..writeln('*Cotización N.º ${numeroDoc(cotizacionId)}*')
    ..writeln('Fecha: ${_fecha.format(fecha)}');
  if (cliente != null && cliente.trim().isNotEmpty) b.writeln('Para: $cliente');
  b
    ..writeln()
    ..writeln(_lineas(lineas))
    ..writeln()
    ..writeln('*Total: ${cop(total)}*')
    ..writeln('Precios válidos hasta el $vence o hasta agotar existencias.')
    ..write('Para confirmar, responda este mensaje.');
  return b.toString();
}

/// Cuánto pedir de un producto por reponer: lo suficiente para quedar en el
/// doble del mínimo (o 1 unidad si no tiene mínimo y está agotado).
double cantidadSugerida(ProductoStock p) {
  final stock = p.stock < 0 ? 0.0 : p.stock;
  if (p.minimo <= 0) return p.agotado ? 1 : 0;
  final falta = p.minimo * 2 - stock;
  return falta <= 0 ? 0 : falta.ceilToDouble();
}

/// Pedido sugerido: productos agotados o bajos con su cantidad a pedir.
List<(ProductoStock, double)> pedidoSugerido(List<ProductoStock> productos) {
  final l = <(ProductoStock, double)>[];
  for (final p in productos) {
    if (!(p.agotado || p.bajo)) continue;
    final c = cantidadSugerida(p);
    if (c > 0) l.add((p, c));
  }
  l.sort((a, b) => a.$1.stock.compareTo(b.$1.stock));
  return l;
}

/// Mensaje del pedido al proveedor.
String textoPedido({
  required PerfilNegocio negocio,
  required DateTime fecha,
  required List<(String nombre, double cantidad)> items,
  String? proveedor,
}) {
  final b = StringBuffer()
    ..writeln(proveedor == null || proveedor.trim().isEmpty
        ? 'Buen día.'
        : 'Buen día, ${proveedor.trim()}.')
    ..writeln('Le escribe ${negocio.nombreVisible}. Quisiera hacer este pedido:')
    ..writeln();
  for (final (n, c) in items) {
    b.writeln('• ${cantidadDoc(c)} × $n');
  }
  b
    ..writeln()
    ..writeln('Fecha: ${DateFormat('d/MM/y', 'es_CO').format(fecha)}')
    ..write('Por favor me confirma disponibilidad, valor y día de entrega. ¡Gracias!');
  return b.toString();
}

/// Promoción o catálogo para compartir por WhatsApp (estado, grupos o
/// clientes).
String textoPromocion({
  required PerfilNegocio negocio,
  required List<(String nombre, double precio)> productos,
  String titulo = 'Ofertas de hoy',
  String nota = '',
}) {
  final b = StringBuffer()
    ..writeln('*${negocio.nombreVisible}*')
    ..writeln('*$titulo*')
    ..writeln();
  for (final (n, p) in productos) {
    b.writeln('• $n: ${cop(p)}');
  }
  if (nota.trim().isNotEmpty) {
    b
      ..writeln()
      ..writeln(nota.trim());
  }
  b
    ..writeln()
    ..write(negocio.direccion.trim().isEmpty
        ? 'Pedidos por este WhatsApp.'
        : 'Pedidos por este WhatsApp o visítenos en ${negocio.direccion.trim()}.');
  return b.toString();
}
