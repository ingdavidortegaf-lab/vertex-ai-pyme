/// Importar productos pegados desde Excel (o Google Sheets / LibreOffice):
/// se seleccionan las columnas, Ctrl+C y se pegan en la app. Llegan como
/// texto con tabuladores; también se acepta punto y coma (CSV de Excel en
/// español).
///
/// Con fila de títulos, las columnas se reconocen por su nombre (Nombre,
/// Precio, Costo, Stock, Código, Unidad, Mínimo, IVA, Precio por mayor,
/// Desde). Sin títulos, el orden es: Nombre, Precio, Costo, Stock, Código.
library;

import 'formato.dart';

class FilaImportada {
  final String nombre;
  final double precio, costo, stock, minimo;
  final String codigo, unidad;

  /// −1 = sin definir.
  final double iva;
  final double precioMayor, cantidadMayor;
  const FilaImportada({
    required this.nombre,
    required this.precio,
    this.costo = 0,
    this.stock = 0,
    this.minimo = 0,
    this.codigo = '',
    this.unidad = 'und',
    this.iva = -1,
    this.precioMayor = 0,
    this.cantidadMayor = 0,
  });
}

class ResultadoImportar {
  final List<FilaImportada> filas;

  /// «Fila 4: falta el precio», para que el dueño corrija en Excel.
  final List<String> errores;
  const ResultadoImportar(this.filas, this.errores);
}

/// Unidad escrita como sea («Kilo», «metros», «Galón») a la de la app.
String? unidadDesdeTexto(String s) {
  final t = _sinTildes(s.trim().toLowerCase()).replaceAll('.', '');
  if (t.isEmpty) return 'und';
  return switch (t) {
    'und' || 'un' || 'u' || 'unidad' || 'unidades' || 'c/u' || 'cu' => 'und',
    'kg' || 'kilo' || 'kilos' || 'kilogramo' || 'kilogramos' => 'kg',
    'lb' || 'libra' || 'libras' => 'lb',
    'm' || 'mt' || 'mts' || 'metro' || 'metros' => 'm',
    'l' || 'lt' || 'lts' || 'litro' || 'litros' => 'l',
    'gal' || 'galon' || 'galones' => 'gal',
    'caja' || 'cajas' || 'cj' => 'caja',
    'paq' || 'paquete' || 'paquetes' || 'pq' => 'paq',
    'serv' || 'servicio' || 'servicios' => 'serv',
    _ => null,
  };
}

String _sinTildes(String s) => s
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u');

/// Columna de la app que corresponde a un título de Excel.
String? _columna(String titulo) {
  final t = _sinTildes(titulo.trim().toLowerCase());
  if (t.isEmpty) return null;
  if (t.contains('mayor')) return 'precio_mayor';
  if (t == 'desde' || t.contains('cantidad minima por mayor') || t.contains('desde')) {
    return 'cantidad_mayor';
  }
  if (t.contains('nombre') || t.contains('producto') || t.contains('descripcion') || t == 'articulo') {
    return 'nombre';
  }
  if (t.contains('costo') || t.contains('compra')) return 'costo';
  if (t.contains('precio') || t.contains('venta') || t == 'valor') return 'precio';
  if (t.contains('stock') || t.contains('existencia') || t.contains('cantidad') || t.contains('inventario')) {
    return 'stock';
  }
  if (t.contains('codigo') || t.contains('barras') || t.contains('referencia') || t == 'ref' || t == 'plu') {
    return 'codigo';
  }
  if (t.contains('unidad') || t == 'medida') return 'unidad';
  if (t.contains('minimo') || t.contains('alerta')) return 'minimo';
  if (t == 'iva' || t.contains('iva')) return 'iva';
  return null;
}

const _ordenSinTitulos = ['nombre', 'precio', 'costo', 'stock', 'codigo'];

double? _cantidad(String s) {
  final t = s.trim().replaceAll(' ', '');
  if (t.isEmpty) return null;
  // «1.234,5» o «1234.5» o «12,5».
  final norm = t.contains(',') ? t.replaceAll('.', '').replaceAll(',', '.') : t;
  return double.tryParse(norm);
}

ResultadoImportar leerProductosPegados(String texto) {
  final lineas = texto
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .toList();
  if (lineas.isEmpty) return const ResultadoImportar([], ['No pegaste nada']);
  final sep = lineas.first.contains('\t') ? '\t' : ';';
  List<String> celdas(String l) => [
        for (final c in l.split(sep)) c.trim().replaceAll(RegExp(r'^"|"$'), ''),
      ];

  var columnas = _ordenSinTitulos;
  var inicio = 0;
  final primera = celdas(lineas.first);
  final titulos = [for (final c in primera) _columna(c)];
  if (titulos.contains('nombre') && titulos.whereType<String>().length >= 2) {
    columnas = [for (final t in titulos) t ?? ''];
    inicio = 1;
  }

  final filas = <FilaImportada>[];
  final errores = <String>[];
  for (var i = inicio; i < lineas.length; i++) {
    final c = celdas(lineas[i]);
    String v(String col) {
      final k = columnas.indexOf(col);
      return k >= 0 && k < c.length ? c[k] : '';
    }

    final n = i + 1;
    final nombre = v('nombre').replaceAll(RegExp(r'\s+'), ' ');
    if (nombre.length < 2) {
      errores.add('Fila $n: falta el nombre');
      continue;
    }
    final precio = parseMonto(v('precio'));
    if (precio == null || precio <= 0) {
      errores.add('Fila $n ($nombre): falta el precio o no es un número');
      continue;
    }
    final unidad = unidadDesdeTexto(v('unidad'));
    if (unidad == null) {
      errores.add('Fila $n ($nombre): no reconozco la unidad «${v('unidad')}»');
      continue;
    }
    final iva = _cantidad(v('iva').replaceAll('%', ''));
    if (iva != null && (iva < 0 || iva > 100)) {
      errores.add('Fila $n ($nombre): el IVA debe ser de 0 a 100');
      continue;
    }
    final costo = parseMonto(v('costo')) ?? 0;
    final stock = _cantidad(v('stock')) ?? 0;
    final pm = parseMonto(v('precio_mayor')) ?? 0;
    final cm = _cantidad(v('cantidad_mayor')) ?? 0;
    if (stock < 0) {
      errores.add('Fila $n ($nombre): el stock no puede ser negativo');
      continue;
    }
    filas.add(FilaImportada(
      nombre: nombre.length > 80 ? nombre.substring(0, 80) : nombre,
      precio: precio,
      costo: costo,
      stock: unidad == 'serv' ? 0 : stock,
      minimo: _cantidad(v('minimo')) ?? 0,
      codigo: v('codigo').replaceAll(RegExp(r'\s'), ''),
      unidad: unidad,
      iva: iva ?? -1,
      // Por mayor solo si está completo y es más barato que el normal.
      precioMayor: pm > 0 && cm > 0 && pm < precio ? pm : 0,
      cantidadMayor: pm > 0 && cm > 0 && pm < precio ? cm : 0,
    ));
  }
  return ResultadoImportar(filas, errores);
}
