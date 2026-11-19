/// Pagos fijos del negocio (obligaciones): arriendo, luz, agua, internet,
/// el sueldo del ayudante… Cada uno tiene un valor aproximado y el día del
/// mes en que se paga. La app avisa cuáles vencen pronto y cuáles ya se
/// pasaron, y al pagarlos quedan como gasto con su medio de pago.
library;

enum EstadoFijo { pagado, vencido, pronto, pendiente }

class PagoFijo {
  final String id;
  final String nombre;
  final double monto;

  /// Día del mes (1 a 31). Si el mes tiene menos días, vence el último.
  final int dia;
  final String? terceroId;
  final String? terceroNombre;

  /// Periodo ('AAAA-MM') del último pago registrado, o null.
  final String? ultimoPeriodo;
  final double pagadoEsteMes;

  const PagoFijo({
    required this.id,
    required this.nombre,
    required this.monto,
    required this.dia,
    this.terceroId,
    this.terceroNombre,
    this.ultimoPeriodo,
    this.pagadoEsteMes = 0,
  });
}

/// 'AAAA-MM' de una fecha.
String periodoDe(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

/// Fecha en que vence un pago fijo en el mes de [ref].
DateTime vencimiento(int dia, DateTime ref) {
  final ultimo = DateTime(ref.year, ref.month + 1, 0).day;
  return DateTime(ref.year, ref.month, dia.clamp(1, ultimo));
}

/// Estado de un pago fijo en el mes de [hoy]. «Pronto» = vence en los
/// próximos [aviso] días.
EstadoFijo estadoFijo(PagoFijo f, DateTime hoy, {int aviso = 5}) {
  if (f.ultimoPeriodo == periodoDe(hoy)) return EstadoFijo.pagado;
  final d0 = DateTime(hoy.year, hoy.month, hoy.day);
  final v = vencimiento(f.dia, hoy);
  if (v.isBefore(d0)) return EstadoFijo.vencido;
  if (v.difference(d0).inDays <= aviso) return EstadoFijo.pronto;
  return EstadoFijo.pendiente;
}

/// Texto corto para la lista: «Vence hoy», «Vence en 3 días», «Se pasó hace
/// 2 días», «Pagado este mes», «Vence el 20».
String textoEstadoFijo(PagoFijo f, DateTime hoy) {
  final d0 = DateTime(hoy.year, hoy.month, hoy.day);
  final v = vencimiento(f.dia, hoy);
  final dif = v.difference(d0).inDays;
  return switch (estadoFijo(f, hoy)) {
    EstadoFijo.pagado => 'Pagado este mes',
    EstadoFijo.vencido => dif == -1 ? 'Se pasó ayer' : 'Se pasó hace ${-dif} días',
    EstadoFijo.pronto => dif == 0 ? 'Vence hoy' : (dif == 1 ? 'Vence mañana' : 'Vence en $dif días'),
    EstadoFijo.pendiente => 'Vence el ${v.day}',
  };
}

/// Orden para mostrar: primero lo vencido, luego lo que vence pronto, luego
/// lo pendiente y al final lo pagado; dentro de cada grupo, por día.
List<PagoFijo> ordenarFijos(List<PagoFijo> l, DateTime hoy) {
  int peso(PagoFijo f) => switch (estadoFijo(f, hoy)) {
        EstadoFijo.vencido => 0,
        EstadoFijo.pronto => 1,
        EstadoFijo.pendiente => 2,
        EstadoFijo.pagado => 3,
      };
  return [...l]..sort((a, b) {
      final p = peso(a).compareTo(peso(b));
      return p != 0 ? p : a.dia.compareTo(b.dia);
    });
}

/// Lo que falta por pagar este mes (sin contar lo ya pagado).
double faltaEsteMes(List<PagoFijo> l, DateTime hoy) => l
    .where((f) => estadoFijo(f, hoy) != EstadoFijo.pagado)
    .fold(0.0, (s, f) => s + f.monto);

/// Nombre del mes para el concepto del gasto: «Luz (noviembre 2026)».
String conceptoFijo(String nombre, DateTime fecha) {
  const meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
    'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
  ];
  var c = '$nombre (${meses[fecha.month - 1]} ${fecha.year})';
  if (c.length > 120) c = '${c.substring(0, 117)}…';
  return c;
}
