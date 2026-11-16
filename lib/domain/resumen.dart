/// Totales del mes. Se calculan en el celular, sin conexión.
class Resumen {
  /// Ventas del mes (de contado y fiadas).
  final double ingresos;

  /// Gastos del mes.
  final double egresos;
  final int nIngresos;
  final int nEgresos;

  /// Lo que deben los clientes hoy (ventas fiadas menos abonos).
  final double porCobrar;
  final int nDeudores;
  final int nClientes;

  const Resumen({
    this.ingresos = 0,
    this.egresos = 0,
    this.nIngresos = 0,
    this.nEgresos = 0,
    this.porCobrar = 0,
    this.nDeudores = 0,
    this.nClientes = 0,
  });

  double get utilidad => ingresos - egresos;
  int get movimientos => nIngresos + nEgresos;
  double get margen => ingresos > 0 ? utilidad / ingresos : 0;
  double get ticketPromedio => nIngresos > 0 ? ingresos / nIngresos : 0;
}

/// Un cliente con su saldo pendiente (positivo = nos debe).
class ClienteSaldo {
  final String id;
  final String nombre;
  final String telefono;
  final double saldo;
  const ClienteSaldo({
    required this.id,
    required this.nombre,
    this.telefono = '',
    this.saldo = 0,
  });
}

class TopCliente {
  final String nombre;
  final double total;
  const TopCliente(this.nombre, this.total);
}

/// Todo lo que el asistente necesita para responder sin conexión.
class DatosAsistente {
  final Resumen mes;
  final double ventasHoy;
  final int nVentasHoy;
  final double ventasSemana;
  final int nVentasSemana;

  /// Todos los clientes activos con su saldo.
  final List<ClienteSaldo> clientes;

  /// Mejores clientes del mes (por ventas).
  final List<TopCliente> topClientes;

  const DatosAsistente({
    this.mes = const Resumen(),
    this.ventasHoy = 0,
    this.nVentasHoy = 0,
    this.ventasSemana = 0,
    this.nVentasSemana = 0,
    this.clientes = const [],
    this.topClientes = const [],
  });

  /// Clientes que deben, de mayor a menor saldo.
  List<ClienteSaldo> get deudores {
    final l = clientes.where((c) => c.saldo > 0).toList()
      ..sort((a, b) => b.saldo.compareTo(a.saldo));
    return l;
  }
}
