/// Códigos de barras de productos y etiquetas de gramera (báscula).
///
/// - Producto empacado: se busca por su código exacto (EAN-13, UPC, interno).
/// - Producto por peso: muchas grameras imprimen una etiqueta EAN-13 que
///   empieza por 20–29 con el código del producto (5 dígitos) y el peso en
///   gramos (5 dígitos): 2X PPPPP GGGGG C. Al escanearla se agrega el producto
///   con ese peso. Es el formato más común; si la gramera usa otro, se ajusta
///   aquí.
library;

import 'formato.dart';
import 'resumen.dart';

String normalizarCodigo(String s) => s.replaceAll(RegExp(r'\s'), '').trim();

/// Dígito de control EAN-13 (o EAN-8/UPC-A con la misma regla).
bool controlEanValido(String c) {
  if (!RegExp(r'^\d{8,14}$').hasMatch(c)) return false;
  var suma = 0;
  final cuerpo = c.substring(0, c.length - 1);
  for (var i = 0; i < cuerpo.length; i++) {
    final d = int.parse(cuerpo[cuerpo.length - 1 - i]);
    suma += i.isEven ? d * 3 : d;
  }
  final control = (10 - suma % 10) % 10;
  return control == int.parse(c[c.length - 1]);
}

/// Etiqueta de gramera: código del producto (PLU) y peso en gramos.
({String plu, int gramos})? leerEtiquetaBalanza(String codigo) {
  final c = normalizarCodigo(codigo);
  if (c.length != 13 || !c.startsWith('2') || !controlEanValido(c)) return null;
  final gramos = int.parse(c.substring(7, 12));
  if (gramos <= 0) return null;
  return (plu: c.substring(2, 7), gramos: gramos);
}

String _sinCeros(String s) => s.replaceFirst(RegExp(r'^0+'), '');

/// Busca el producto de un código leído. Devuelve el producto y, si vino de
/// una etiqueta de gramera, la cantidad en la unidad del producto.
({ProductoStock producto, double? cantidad})? buscarPorCodigo(
    List<ProductoStock> productos, String codigo) {
  final c = normalizarCodigo(codigo);
  if (c.isEmpty) return null;
  for (final p in productos) {
    if (p.codigo.isNotEmpty && normalizarCodigo(p.codigo) == c) {
      return (producto: p, cantidad: null);
    }
  }
  final b = leerEtiquetaBalanza(c);
  if (b == null) return null;
  for (final p in productos) {
    final pc = normalizarCodigo(p.codigo);
    if (pc.isEmpty) continue;
    if (pc == b.plu || _sinCeros(pc) == _sinCeros(b.plu)) {
      return (producto: p, cantidad: pesoEnUnidad(b.gramos, p.unidad));
    }
  }
  return null;
}

/// Gramos a la unidad de venta del producto (redondeado a 3 decimales).
double pesoEnUnidad(int gramos, String unidad) {
  final v = switch (unidad) {
    'lb' => gramos / 453.59237,
    'kg' => gramos / 1000,
    _ => gramos.toDouble(),
  };
  return (v * 1000).round() / 1000;
}

bool esPorPeso(String unidad) => unidad == 'kg' || unidad == 'lb';

/// Unidades que se venden en fracciones: kilos y libras (gramera), metros
/// (cable, manguera, cadena), litros y galones (pintura, thinner, aceite).
bool esFraccionable(String unidad) => const {'kg', 'lb', 'm', 'l', 'gal'}.contains(unidad);

/// Servicio (corte, domicilio, consulta, reparación…): no lleva inventario.
bool esServicio(String unidad) => unidad == 'serv';

/// Nombre de cada unidad de venta para mostrar.
const nombresUnidad = {
  'und': 'Unidad',
  'kg': 'Kilo',
  'lb': 'Libra',
  'm': 'Metro',
  'l': 'Litro',
  'gal': 'Galón',
  'caja': 'Caja',
  'paq': 'Paquete',
  'serv': 'Servicio',
};

/// Precio con su unidad: «$2.500 c/u», «$9.000/kg», «$4.200/m»,
/// «$60.000/caja» o «$30.000» (servicio).
String precioConUnidad(double precio, String unidad) => switch (unidad) {
      'serv' => cop(precio),
      'und' => '${cop(precio)} c/u',
      _ => '${cop(precio)}/$unidad',
    };

/// «3», «0,750 kg», «1,5 lb», «12,5 m», «2 cajas».
String cantidadConUnidad(double c, String unidad) {
  if (!esFraccionable(unidad)) {
    final n = c == c.roundToDouble() ? c.toInt().toString() : c.toStringAsFixed(1);
    return switch (unidad) {
      'caja' => '$n ${c == 1 ? 'caja' : 'cajas'}',
      'paq' => '$n ${c == 1 ? 'paquete' : 'paquetes'}',
      _ => n,
    };
  }
  final s = c.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return '${s.replaceAll('.', ',')} $unidad';
}
