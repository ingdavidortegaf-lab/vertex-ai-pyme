/// Contabilidad básica para la MiPyme y su contador:
/// - Cuenta de cobro (estado de cuenta) con trazabilidad: cada fiado con su
///   fecha, cada abono, el saldo después de cada movimiento y la antigüedad
///   de lo que sigue pendiente (0–30, 31–60, 61–90 y más de 90 días).
/// - Periodos para informes: semana, quincena y mes.
///
/// Regla de aplicación de abonos: PRIMERO EN ENTRAR, PRIMERO EN PAGARSE
/// (cada abono paga los fiados más antiguos). Así se sabe exactamente qué
/// está pendiente y desde cuándo.
library;

/// Una línea del extracto.
class LineaCuenta {
  final DateTime fecha;
  final String concepto;
  final double cargo; // fiado
  final double abono;
  final double saldo; // saldo después de este movimiento
  const LineaCuenta(this.fecha, this.concepto, this.cargo, this.abono, this.saldo);
}

/// Un fiado que todavía no se ha pagado completo.
class PartidaAbierta {
  final DateTime fecha;
  final String concepto;
  final double original;
  final double pendiente;
  final int dias;
  const PartidaAbierta(this.fecha, this.concepto, this.original, this.pendiente, this.dias);
}

class EstadoCuenta {
  final List<LineaCuenta> lineas;
  final List<PartidaAbierta> abiertas;
  final double totalFiado;
  final double totalAbonado;

  /// Saldo pendiente por antigüedad: '0-30', '31-60', '61-90', '90+'.
  final Map<String, double> edades;
  const EstadoCuenta(
      this.lineas, this.abiertas, this.totalFiado, this.totalAbonado, this.edades);

  double get saldo => totalFiado - totalAbonado;

  /// Días del fiado pendiente más antiguo (0 si está al día).
  int get diasMora => abiertas.isEmpty ? 0 : abiertas.first.dias;

  /// Fecha desde la que debe (el fiado pendiente más antiguo).
  DateTime? get debeDesde => abiertas.isEmpty ? null : abiertas.first.fecha;
}

const rangosEdad = ['0-30', '31-60', '61-90', '90+'];

String rangoEdad(int dias) => dias <= 30
    ? '0-30'
    : dias <= 60
        ? '31-60'
        : dias <= 90
            ? '61-90'
            : '90+';

/// Arma la cuenta de cobro a partir de los fiados y abonos del cliente
/// (filas con tipo, credito, monto, fecha y concepto), en cualquier orden.
EstadoCuenta estadoDeCuenta(List<Map<String, Object?>> movs, DateTime ahora) {
  final l = [...movs]
    ..sort((a, b) => (a['fecha'] as String).compareTo(b['fecha'] as String));
  final lineas = <LineaCuenta>[];
  final cola = <({DateTime fecha, String concepto, double original, double pendiente})>[];
  var saldo = 0.0, fiado = 0.0, abonado = 0.0;
  for (final m in l) {
    final fecha = DateTime.parse(m['fecha'] as String).toLocal();
    final monto = (m['monto'] as num).toDouble();
    final concepto = m['concepto'] as String? ?? '';
    final esFiado = m['tipo'] == 'ingreso' && (m['credito'] == 1 || m['credito'] == true);
    if (esFiado) {
      saldo += monto;
      fiado += monto;
      cola.add((fecha: fecha, concepto: concepto, original: monto, pendiente: monto));
      lineas.add(LineaCuenta(fecha, concepto, monto, 0, saldo));
    } else if (m['tipo'] == 'abono') {
      saldo -= monto;
      abonado += monto;
      var resto = monto;
      for (var i = 0; i < cola.length && resto > 0.0001; i++) {
        final p = cola[i];
        if (p.pendiente <= 0) continue;
        final pago = resto < p.pendiente ? resto : p.pendiente;
        cola[i] = (
          fecha: p.fecha,
          concepto: p.concepto,
          original: p.original,
          pendiente: p.pendiente - pago
        );
        resto -= pago;
      }
      lineas.add(LineaCuenta(fecha, concepto.isEmpty ? 'Abono' : concepto, 0, monto, saldo));
    }
  }
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  final abiertas = <PartidaAbierta>[];
  final edades = {for (final r in rangosEdad) r: 0.0};
  for (final p in cola) {
    if (p.pendiente <= 0.5) continue;
    final dia = DateTime(p.fecha.year, p.fecha.month, p.fecha.day);
    final dias = hoy.difference(dia).inDays;
    abiertas.add(PartidaAbierta(p.fecha, p.concepto, p.original, p.pendiente, dias));
    edades[rangoEdad(dias)] = edades[rangoEdad(dias)]! + p.pendiente;
  }
  return EstadoCuenta(lineas, abiertas, fiado, abonado, edades);
}

/// Periodos de informe.
enum Periodo { semanaActual, semanaPasada, quincenaActual, quincenaAnterior, mesActual, mesAnterior }

const nombresPeriodo = {
  Periodo.semanaActual: 'Esta semana',
  Periodo.semanaPasada: 'Semana pasada',
  Periodo.quincenaActual: 'Esta quincena',
  Periodo.quincenaAnterior: 'Quincena anterior',
  Periodo.mesActual: 'Este mes',
  Periodo.mesAnterior: 'Mes anterior',
};

/// Rango [desde, hasta) del periodo (hasta excluido) y el periodo anterior
/// de igual tipo, para comparar.
({DateTime desde, DateTime hasta, DateTime antDesde, DateTime antHasta}) rangoPeriodo(
    Periodo p, DateTime ahora) {
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  final lunes = hoy.subtract(Duration(days: hoy.weekday - 1));
  DateTime dia(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);
  ({DateTime desde, DateTime hasta}) quincena(DateTime d) => d.day <= 15
      ? (desde: DateTime(d.year, d.month, 1), hasta: DateTime(d.year, d.month, 16))
      : (desde: DateTime(d.year, d.month, 16), hasta: DateTime(d.year, d.month + 1, 1));
  switch (p) {
    case Periodo.semanaActual:
      return (desde: lunes, hasta: dia(lunes, 7), antDesde: dia(lunes, -7), antHasta: lunes);
    case Periodo.semanaPasada:
      return (
        desde: dia(lunes, -7),
        hasta: lunes,
        antDesde: dia(lunes, -14),
        antHasta: dia(lunes, -7)
      );
    case Periodo.quincenaActual:
      final q = quincena(hoy);
      final a = quincena(dia(q.desde, -1));
      return (desde: q.desde, hasta: q.hasta, antDesde: a.desde, antHasta: a.hasta);
    case Periodo.quincenaAnterior:
      final q = quincena(dia(quincena(hoy).desde, -1));
      final a = quincena(dia(q.desde, -1));
      return (desde: q.desde, hasta: q.hasta, antDesde: a.desde, antHasta: a.hasta);
    case Periodo.mesActual:
      return (
        desde: DateTime(hoy.year, hoy.month),
        hasta: DateTime(hoy.year, hoy.month + 1),
        antDesde: DateTime(hoy.year, hoy.month - 1),
        antHasta: DateTime(hoy.year, hoy.month)
      );
    case Periodo.mesAnterior:
      return (
        desde: DateTime(hoy.year, hoy.month - 1),
        hasta: DateTime(hoy.year, hoy.month),
        antDesde: DateTime(hoy.year, hoy.month - 2),
        antHasta: DateTime(hoy.year, hoy.month - 1)
      );
  }
}
