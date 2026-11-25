/// Exportar a Excel y reportes de detalle (kárdex, ventas por vendedor,
/// utilidad por producto). Todo se calcula con los datos del equipo, sin
/// internet.
///
/// El archivo es CSV con punto y coma y coma decimal, en UTF-8 con BOM: así
/// Excel en español (Colombia) lo abre con las columnas y las tildes bien,
/// con doble clic.
library;

import 'package:intl/intl.dart';
import 'codigos.dart';
import 'contabilidad.dart';
import 'pagos.dart';
import 'resumen.dart';

const _bom = '﻿';

String _celda(Object? v) {
  final String s;
  if (v == null) {
    s = '';
  } else if (v is num) {
    s = _numero(v.toDouble());
  } else if (v is DateTime) {
    s = DateFormat('yyyy-MM-dd HH:mm').format(v.toLocal());
  } else {
    s = v.toString();
  }
  // Evita que Excel interprete una celda como fórmula (=, +, -, @).
  final seguro = RegExp(r'^[=+\-@]').hasMatch(s) && v is! num ? "'$s" : s;
  if (seguro.contains(';') || seguro.contains('"') || seguro.contains('\n')) {
    return '"${seguro.replaceAll('"', '""')}"';
  }
  return seguro;
}

String _numero(double x) {
  if (x == x.roundToDouble()) return x.toInt().toString();
  return x
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceAll('.', ',');
}

/// Tabla → texto CSV para Excel.
String aCsv(List<String> titulos, List<List<Object?>> filas) {
  final b = StringBuffer(_bom)..writeln(titulos.map(_celda).join(';'));
  for (final f in filas) {
    b.writeln(f.map(_celda).join(';'));
  }
  return b.toString();
}

/// Nombre de archivo con la fecha: «ventas_2026-11-25.csv».
String nombreCsv(String que, DateTime cuando) =>
    '${que}_${DateFormat('yyyy-MM-dd').format(cuando)}.csv';

String _tipo(Map<String, Object?> m) {
  final credito = m['credito'] == 1 || m['credito'] == true;
  return switch (m['tipo']) {
    'ingreso' => credito ? 'Venta fiada' : 'Venta',
    'egreso' => 'Gasto',
    'abono' => 'Abono',
    _ => '${m['tipo']}',
  };
}

/// Libro de movimientos (filas de `ventas_netas`): una anulación sale con
/// valor negativo en su fecha, como en los informes.
String csvMovimientos(List<Map<String, Object?>> movs) => aCsv([
      'Fecha',
      'Tipo',
      'Concepto',
      'Cliente o tercero',
      'Documento',
      'Valor',
      'Descuento',
      'Medios de pago',
      'Registró',
      'Anulación',
    ], [
      for (final m in movs)
        [
          DateTime.parse(m['fecha'] as String),
          _tipo(m),
          m['concepto'],
          m['cliente_nombre'] ?? m['tercero_nombre'] ?? '',
          [
            m['cliente_tipo_doc'] ?? m['tercero_tipo_doc'] ?? '',
            m['cliente_documento'] ?? m['tercero_documento'] ?? '',
          ].where((x) => '$x'.isNotEmpty).join(' '),
          (m['monto'] as num).toDouble(),
          (m['descuento'] as num?)?.toDouble() ?? 0,
          m['credito'] == 1
              ? 'Fiado'
              : textoPagos(
                  leerPagos(m['pagos'],
                      monto: (m['monto'] as num).toDouble().abs(),
                      tipo: m['tipo'] as String,
                      credito: false),
                  conValor: false),
          m['perfil'] ?? '',
          ((m['signo'] as num?) ?? 1) < 0 ? 'Sí' : '',
        ],
    ]);

String csvProductos(List<ProductoStock> l, {required bool conCostos}) => aCsv([
      'Código',
      'Nombre',
      'Unidad',
      'Precio',
      'Precio por mayor',
      'Desde',
      if (conCostos) 'Costo',
      'Stock',
      'Mínimo',
      'IVA',
      'Vence',
    ], [
      for (final p in l)
        [
          p.codigo,
          p.nombre,
          nombresUnidad[p.unidad] ?? p.unidad,
          p.precio,
          p.tienePrecioMayor ? p.precioMayor : null,
          p.tienePrecioMayor ? p.cantidadMayor : null,
          if (conCostos) p.costo,
          p.esServicio ? null : p.stock,
          p.esServicio ? null : p.minimo,
          p.iva < 0 ? '' : '${_numero(p.iva)} %',
          p.vence,
        ],
    ]);

/// Quién debe, con la antigüedad de la deuda.
String csvCartera(List<(String nombre, EstadoCuenta estado)> deudores) => aCsv([
      'Cliente',
      'Debe',
      '0 a 30 días',
      '31 a 60 días',
      '61 a 90 días',
      'Más de 90 días',
    ], [
      for (final (n, e) in deudores)
        [
          n,
          e.edades.values.fold<double>(0, (s, x) => s + x),
          e.edades['0-30'] ?? 0,
          e.edades['31-60'] ?? 0,
          e.edades['61-90'] ?? 0,
          e.edades['90+'] ?? 0,
        ],
    ]);

// ------------------------------------------------------------------ kárdex

/// Una línea del kárdex de un producto: cada entrada, venta, ajuste o
/// anulación con el saldo que deja.
class LineaKardex {
  final DateTime fecha;
  final String motivo;
  final double cantidad;
  final double saldo;
  final double? costoUnit, precioUnit;

  /// La venta o el concepto, si lo hay.
  final String detalle;
  final String registro;
  const LineaKardex({
    required this.fecha,
    required this.motivo,
    required this.cantidad,
    required this.saldo,
    this.costoUnit,
    this.precioUnit,
    this.detalle = '',
    this.registro = '',
  });

  String get motivoTexto => switch (motivo) {
        'entrada' => 'Entrada',
        'venta' => 'Venta',
        'ajuste' => 'Ajuste',
        'anulacion' => 'Devolución por anulación',
        _ => motivo,
      };
}

/// Arma el kárdex desde los movimientos de inventario (en orden de fecha).
List<LineaKardex> armarKardex(List<Map<String, Object?>> filas) {
  var saldo = 0.0;
  return [
    for (final f in filas)
      () {
        final c = (f['cantidad'] as num).toDouble();
        saldo += c;
        return LineaKardex(
          fecha: DateTime.parse(f['fecha'] as String),
          motivo: f['motivo'] as String,
          cantidad: c,
          saldo: (saldo * 1000).round() / 1000,
          costoUnit: (f['costo_unit'] as num?)?.toDouble(),
          precioUnit: (f['precio_unit'] as num?)?.toDouble(),
          detalle: (f['concepto'] as String?) ?? '',
          registro: (f['perfil'] as String?) ?? '',
        );
      }(),
  ];
}

String csvKardex(String producto, List<LineaKardex> l,
        {required bool conCostos}) =>
    aCsv([
      'Fecha',
      'Producto',
      'Movimiento',
      'Entra',
      'Sale',
      'Saldo',
      if (conCostos) 'Costo unitario',
      'Precio unitario',
      'Detalle',
      'Registró',
    ], [
      for (final x in l)
        [
          x.fecha,
          producto,
          x.motivoTexto,
          x.cantidad > 0 ? x.cantidad : null,
          x.cantidad < 0 ? -x.cantidad : null,
          x.saldo,
          if (conCostos) x.costoUnit,
          x.precioUnit,
          x.detalle,
          x.registro,
        ],
    ]);

// ------------------------------------------------- ventas por vendedor

class VentasVendedor {
  final String nombre;
  final double total;
  final int ventas;
  const VentasVendedor(this.nombre, this.total, this.ventas);
  double get promedio => ventas > 0 ? total / ventas : 0;
}

/// Ventas por quien las registró (perfil del celular compartido o la cuenta),
/// de mayor a menor. Las anulaciones restan a quien hizo la venta original
/// solo si la registró la misma persona; si no, restan a quien anuló.
List<VentasVendedor> ventasPorVendedor(List<Map<String, Object?>> movs,
    {String sinPerfil = 'Cuenta principal'}) {
  final total = <String, double>{}, n = <String, int>{};
  for (final m in movs) {
    if (m['tipo'] != 'ingreso') continue;
    final p = ((m['perfil'] as String?) ?? '').trim();
    final quien = p.isEmpty ? sinPerfil : p;
    total[quien] = (total[quien] ?? 0) + (m['monto'] as num).toDouble();
    n[quien] = (n[quien] ?? 0) + ((m['signo'] as num?)?.toInt() ?? 1);
  }
  return [for (final k in total.keys) VentasVendedor(k, total[k]!, n[k]!)]
    ..sort((a, b) => b.total.compareTo(a.total));
}

// ------------------------------------------------ utilidad por producto

class UtilidadProducto {
  final String nombre;
  final String unidad;
  final double cantidad, ingresos, costo;
  const UtilidadProducto(
      this.nombre, this.unidad, this.cantidad, this.ingresos, this.costo);
  double get utilidad => ingresos - costo;
  double get margen => ingresos > 0 ? utilidad / ingresos : 0;
}
