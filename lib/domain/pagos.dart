/// Medios de pago: efectivo, Nequi, Daviplata, Bancolombia, otras
/// transferencias (Bre-B u otros bancos) y tarjetas. Un mismo movimiento se
/// puede pagar con varios medios (pago dividido): por ejemplo $20.000 por
/// Nequi y $5.000 en efectivo.
///
/// Se guardan junto con la venta, el abono o el gasto como una lista
/// [{"medio": "nequi", "monto": 20000}, …] cuya suma debe ser igual al valor
/// del movimiento. Una venta fiada no lleva pagos: queda por cobrar.
library;

import 'dart:convert';
import 'formato.dart';

const mediosPago = [
  'efectivo',
  'nequi',
  'daviplata',
  'bancolombia',
  'transferencia',
  'tarjeta_debito',
  'tarjeta_credito',
];

const nombresMedio = {
  'efectivo': 'Efectivo',
  'nequi': 'Nequi',
  'daviplata': 'Daviplata',
  'bancolombia': 'Bancolombia',
  'transferencia': 'Otra transferencia',
  'tarjeta_debito': 'Tarjeta débito',
  'tarjeta_credito': 'Tarjeta crédito',
};

/// ¿El dinero entra a la caja física (efectivo) o a una cuenta?
bool esEfectivo(String medio) => medio == 'efectivo';

class Pago {
  final String medio;
  final double monto;
  const Pago(this.medio, this.monto);

  Map<String, Object> aMapa() => {'medio': medio, 'monto': monto};

  @override
  bool operator ==(Object other) =>
      other is Pago && other.medio == medio && other.monto == monto;
  @override
  int get hashCode => Object.hash(medio, monto);
  @override
  String toString() => 'Pago($medio, $monto)';
}

/// Revisa los pagos de un movimiento. Devuelve el problema en palabras
/// sencillas, o null si están bien.
String? problemaPagos(List<Pago> pagos, double total) {
  if (pagos.isEmpty) return 'Elige cómo pagó';
  for (final p in pagos) {
    if (!mediosPago.contains(p.medio)) return 'Medio de pago no válido';
    if (!p.monto.isFinite || p.monto <= 0) return 'Cada pago debe ser mayor a cero';
  }
  final suma = pagos.fold(0.0, (s, p) => s + p.monto);
  final dif = total - suma;
  if (dif > 0.5) return 'Faltan ${cop(dif)} por repartir';
  if (dif < -0.5) return 'Sobran ${cop(-dif)}: la suma pasa del total';
  return null;
}

/// Junta los pagos del mismo medio y quita los vacíos.
List<Pago> normalizarPagos(List<Pago> pagos) {
  final m = <String, double>{};
  for (final p in pagos) {
    if (p.monto > 0) m[p.medio] = (m[p.medio] ?? 0) + p.monto;
  }
  return [for (final medio in mediosPago) if (m.containsKey(medio)) Pago(medio, m[medio]!)];
}

String codificarPagos(List<Pago> pagos) =>
    jsonEncode([for (final p in pagos) p.aMapa()]);

/// Lee los pagos guardados (texto JSON o lista que llega de la nube).
/// Los movimientos de versiones anteriores no tienen pagos: se toman como
/// efectivo, salvo la venta fiada, que no tiene pagos.
List<Pago> leerPagos(Object? valor,
    {required double monto, required String tipo, bool credito = false}) {
  if (tipo == 'ingreso' && credito) return const [];
  Object? datos = valor;
  if (valor is String && valor.isNotEmpty) {
    try {
      datos = jsonDecode(valor);
    } catch (_) {
      datos = null;
    }
  }
  if (datos is List) {
    final l = <Pago>[];
    for (final e in datos) {
      if (e is Map && mediosPago.contains(e['medio']) && e['monto'] is num) {
        l.add(Pago(e['medio'] as String, (e['monto'] as num).toDouble()));
      }
    }
    if (l.isNotEmpty) return l;
  }
  return [Pago('efectivo', monto)];
}

/// «Nequi $20.000 + Efectivo $5.000» (o «Efectivo» si es uno solo).
String textoPagos(List<Pago> pagos, {bool conValor = true}) {
  if (pagos.isEmpty) return 'a crédito (fiado)';
  if (pagos.length == 1) return nombresMedio[pagos.first.medio] ?? pagos.first.medio;
  return pagos
      .map((p) => conValor ? '${nombresMedio[p.medio]} ${cop(p.monto)}' : '${nombresMedio[p.medio]}')
      .join(' + ');
}

/// Cuánto entró y salió por cada medio en un grupo de movimientos
/// (ventas de contado y abonos entran; gastos salen; lo fiado no entra).
class PorMedio {
  final Map<String, double> entradas;
  final Map<String, double> salidas;
  const PorMedio(this.entradas, this.salidas);

  double entrada(String m) => entradas[m] ?? 0;
  double salida(String m) => salidas[m] ?? 0;
  double neto(String m) => entrada(m) - salida(m);

  /// Efectivo que debería haber en la caja: la base del día + lo que entró
  /// en efectivo − los gastos pagados en efectivo.
  double efectivoEsperado(double base) => base + neto('efectivo');

  double get totalEntradas => entradas.values.fold(0.0, (s, x) => s + x);
  double get totalDigital => totalEntradas - entrada('efectivo');

  /// Medios usados, en el orden de la lista oficial.
  List<String> get medios => [
        for (final m in mediosPago)
          if (entrada(m) > 0 || salida(m) > 0) m
      ];
}

PorMedio porMedio(Iterable<Map<String, Object?>> movs) {
  final ent = <String, double>{}, sal = <String, double>{};
  for (final m in movs) {
    final tipo = m['tipo'] as String;
    final credito = m['credito'] == 1 || m['credito'] == true;
    // Las anulaciones (vista ventas_netas) traen signo −1 y el valor en negativo.
    final signo = (m['signo'] as num?)?.toInt() ?? 1;
    final monto = (m['monto'] as num).toDouble().abs();
    for (final p in leerPagos(m['pagos'], monto: monto, tipo: tipo, credito: credito)) {
      final destino = tipo == 'egreso' ? sal : ent;
      destino[p.medio] = (destino[p.medio] ?? 0) + p.monto * signo;
    }
  }
  return PorMedio(ent, sal);
}

/// Cuentas del negocio para que el cliente pague por transferencia.
/// Salen en la cuenta de cobro, la cotización y el comprobante fiado.
class DatosPago {
  final String nequi;
  final String daviplata;
  final String bancolombia; // ej. «Ahorros 123-456789-01»
  final String llave; // llave Bre-B u otra llave de pagos
  const DatosPago({this.nequi = '', this.daviplata = '', this.bancolombia = '', this.llave = ''});

  bool get vacio => lineas().isEmpty;

  List<String> lineas() => [
        if (nequi.trim().isNotEmpty) 'Nequi: ${mostrarTelefono(nequi.trim())}',
        if (daviplata.trim().isNotEmpty) 'Daviplata: ${mostrarTelefono(daviplata.trim())}',
        if (bancolombia.trim().isNotEmpty) 'Bancolombia: ${bancolombia.trim()}',
        if (llave.trim().isNotEmpty) 'Llave Bre-B: ${llave.trim()}',
      ];
}
