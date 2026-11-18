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

/// Producto con su stock actual (suma de movimientos de inventario).
class ProductoStock {
  final String id;
  final String nombre;
  final double precio;
  final double costo;
  final double minimo;
  final double stock;
  final String sync;

  /// Código de barras (o código interno / PLU de gramera).
  final String codigo;

  /// Unidad de venta: 'und', 'kg' o 'lb' (por peso, con gramera).
  final String unidad;
  const ProductoStock({
    required this.id,
    required this.nombre,
    this.precio = 0,
    this.costo = 0,
    this.minimo = 0,
    this.stock = 0,
    this.sync = 'pendiente',
    this.codigo = '',
    this.unidad = 'und',
  });

  /// Los servicios no llevan inventario: nunca se agotan.
  bool get esServicio => unidad == 'serv';
  bool get agotado => !esServicio && stock <= 0;
  bool get bajo => !esServicio && !agotado && minimo > 0 && stock <= minimo;
  double get margen => precio > 0 ? (precio - costo) / precio : 0;
}

/// Una línea de una venta con productos.
class ItemVenta {
  final String productoId;
  final String nombre;
  final double cantidad;
  final double precio;
  final double costo;

  /// 'und', 'kg' o 'lb'.
  final String unidad;
  const ItemVenta({
    required this.productoId,
    required this.nombre,
    required this.cantidad,
    required this.precio,
    this.costo = 0,
    this.unidad = 'und',
  });
  double get total => cantidad * precio;
}

/// Lo más vendido en un periodo (por valor).
class TopProducto {
  final String nombre;
  final double cantidad;
  final double total;
  const TopProducto(this.nombre, this.cantidad, this.total);
}

/// Ventas y gastos de un día (para las gráficas).
class DiaSerie {
  final DateTime dia;
  final double ventas;
  final double gastos;
  const DiaSerie(this.dia, this.ventas, this.gastos);
}

/// Totales de un periodo cualquiera (reportes).
class ResumenPeriodo {
  final double ventas;
  final int nVentas;
  final double gastos;
  final double contado;
  final double fiado;
  final double abonos;

  /// Ganancia de los productos vendidos (precio − costo). Solo cuenta
  /// ventas hechas con productos del inventario.
  final double gananciaProductos;
  const ResumenPeriodo({
    this.ventas = 0,
    this.nVentas = 0,
    this.gastos = 0,
    this.contado = 0,
    this.fiado = 0,
    this.abonos = 0,
    this.gananciaProductos = 0,
  });
  double get utilidad => ventas - gastos;
  double get ticketPromedio => nVentas > 0 ? ventas / nVentas : 0;
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

  /// Inventario: productos con stock, lo más vendido del mes y ganancia.
  final List<ProductoStock> productos;
  final List<TopProducto> topProductos;
  final double gananciaProductosMes;

  /// Perfil del negocio (lo que el dueño contó al empezar).
  final String nombreNegocio;
  final double metaMensual;

  const DatosAsistente({
    this.mes = const Resumen(),
    this.ventasHoy = 0,
    this.nVentasHoy = 0,
    this.ventasSemana = 0,
    this.nVentasSemana = 0,
    this.clientes = const [],
    this.topClientes = const [],
    this.productos = const [],
    this.topProductos = const [],
    this.gananciaProductosMes = 0,
    this.nombreNegocio = '',
    this.metaMensual = 0,
  });

  /// Productos agotados o por debajo del mínimo, primero los agotados.
  List<ProductoStock> get porReponer {
    final l = productos.where((p) => p.agotado || p.bajo).toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));
    return l;
  }

  /// Valor del inventario a precio de costo.
  double get valorInventario => productos.fold(
      0.0, (s, p) => s + (p.stock > 0 ? p.stock * p.costo : 0));

  /// Clientes que deben, de mayor a menor saldo.
  List<ClienteSaldo> get deudores {
    final l = clientes.where((c) => c.saldo > 0).toList()
      ..sort((a, b) => b.saldo.compareTo(a.saldo));
    return l;
  }
}
