import 'pagos.dart';
import 'roles.dart';

/// Un turno de caja: quien atiende lo abre con una base de efectivo y lo
/// cierra contando lo que hay en el cajón.
class Turno {
  final String id;
  final String perfil;
  final DateTime abre;
  final DateTime? cierra;
  final double base;
  final double? esperado;
  final double? contado;
  final String nota;
  const Turno({
    required this.id,
    required this.perfil,
    required this.abre,
    this.cierra,
    required this.base,
    this.esperado,
    this.contado,
    this.nota = '',
  });

  bool get abierto => cierra == null;

  /// Sobrante (+) o faltante (−) al cerrar.
  double? get diferencia => contado == null || esperado == null ? null : contado! - esperado!;

  factory Turno.desdeFila(Map<String, Object?> f) => Turno(
        id: f['id'] as String,
        perfil: (f['perfil'] as String?) ?? '',
        abre: DateTime.parse(f['abre'] as String).toLocal(),
        cierra: f['cierra'] == null ? null : DateTime.parse(f['cierra'] as String).toLocal(),
        base: (f['base'] as num?)?.toDouble() ?? 0,
        esperado: (f['esperado'] as num?)?.toDouble(),
        contado: (f['contado'] as num?)?.toDouble(),
        nota: (f['nota'] as String?) ?? '',
      );
}

/// Lo que pasó por el cajón en un turno.
class EfectivoTurno {
  final double base;
  final double entradas; // ventas de contado y abonos en efectivo
  final double salidas; // gastos pagados en efectivo
  final double otrosMedios; // Nequi, tarjeta, transferencia… (no van al cajón)
  final int movimientos;
  const EfectivoTurno({
    required this.base,
    required this.entradas,
    required this.salidas,
    required this.otrosMedios,
    required this.movimientos,
  });

  double get esperado => base + entradas - salidas;
}

/// Calcula el efectivo de un turno con los movimientos netos (las
/// anulaciones restan con el tipo del movimiento original; ver la vista
/// ventas_netas). Solo cuenta la parte en efectivo de cada pago.
EfectivoTurno efectivoDelTurno(double base, Iterable<Map<String, Object?>> movs) {
  var ent = 0.0, sal = 0.0, otros = 0.0, n = 0;
  for (final m in movs) {
    final tipo = m['tipo'] as String?;
    if (tipo == null) continue; // anulación de algo que no está en este celular
    final credito = m['credito'] == 1 || m['credito'] == true;
    final signo = (m['signo'] as num?)?.toInt() ?? 1;
    final monto = (m['monto'] as num).toDouble().abs();
    n++;
    for (final p in leerPagos(m['pagos'], monto: monto, tipo: tipo, credito: credito)) {
      final v = p.monto * signo;
      if (p.medio != 'efectivo') {
        otros += v;
      } else if (tipo == 'egreso') {
        sal += v;
      } else {
        ent += v;
      }
    }
  }
  return EfectivoTurno(base: base, entradas: ent, salidas: sal, otrosMedios: otros, movimientos: n);
}

/// Texto corto de la diferencia de caja.
String textoDiferencia(double d) {
  if (d.abs() < 0.5) return 'Cuadra exacto';
  return d > 0 ? 'Sobran' : 'Faltan';
}

// ------------------------------------------------------------- descuentos

/// ¿Quien atiende está libre del tope? Solo el dueño (y sin un perfil de
/// otro rol atendiendo). Es lo mismo que exige el servidor.
bool libreDeTope(ContextoEquipo c, Rol? perfil) =>
    c.rol == Rol.dueno && (perfil == null || perfil == Rol.dueno);

/// Descuento máximo en pesos sobre un total, según el tope en porcentaje.
double descuentoMaximo(double total, double topePct) =>
    (total * topePct / 100 * 100).floorToDouble() / 100;

/// Revisa el descuento. Null si sirve; si no, el motivo en palabras simples.
String? problemaDescuento(double descuento, double total, {required double topePct, required bool libre}) {
  if (!descuento.isFinite || descuento < 0) return 'El descuento no puede ser negativo';
  if (descuento == 0) return null;
  if (descuento >= total) return 'El descuento no puede ser igual o mayor que el total';
  if (!libre && descuento > descuentoMaximo(total, topePct) + 0.5) {
    return topePct <= 0
        ? 'El dueño no ha permitido descuentos'
        : 'El máximo es el ${_pct(topePct)} % del total';
  }
  return null;
}

String _pct(double p) => p == p.roundToDouble() ? p.toInt().toString() : p.toStringAsFixed(1);
