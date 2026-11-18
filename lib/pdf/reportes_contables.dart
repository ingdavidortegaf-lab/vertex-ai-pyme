import 'package:intl/intl.dart';
import '../data/local_db.dart';
import '../domain/contabilidad.dart';
import '../domain/documentos.dart';
import '../domain/formato.dart';
import '../domain/pagos.dart';
import '../domain/resumen.dart';
import 'pdf_reportes.dart';

/// Arma los documentos contables a partir de la base del celular:
/// la cuenta de cobro de un cliente y los informes por periodo.

final _dia = DateFormat('d/MM/y', 'es_CO');
final _diaHora = DateFormat('d/MM/y h:mm a', 'es_CO');
final _diaCorto = DateFormat('EEE d', 'es_CO');

String _cant(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

/// Cuenta de cobro (estado de cuenta) de un cliente, con trazabilidad.
Reporte reporteCuentaCobro({
  required PerfilNegocio negocio,
  required String numero,
  required DateTime fecha,
  required String cliente,
  required String telefono,
  required EstadoCuenta estado,
  List<String> formasDePago = const [],
}) {
  final e = estado;
  return Reporte(
    titulo: 'Cuenta de cobro',
    numero: numero,
    fecha: fecha,
    negocio: negocio,
    subtitulo: [
      'Cliente: $cliente',
      if (telefono.isNotEmpty) 'Cel. ${mostrarTelefono(telefono)}',
    ],
    bloques: [
      Indicadores([
        Indicador('Saldo pendiente', cop(e.saldo)),
        Indicador('Debe desde',
            e.debeDesde == null ? 'Al día' : _dia.format(e.debeDesde!)),
        Indicador('Días de mora', '${e.diasMora}', 'del fiado más antiguo'),
        Indicador('Total fiado', cop(e.totalFiado),
            'Abonado: ${cop(e.totalAbonado)}'),
      ]),
      Parrafo(
          e.saldo > 0.5
              ? 'Por medio de la presente, ${negocio.nombreVisible} cobra a $cliente '
                  'la suma de ${cop(e.saldo)} por concepto de compras a crédito '
                  'detalladas a continuación.'
              : '$cliente se encuentra a paz y salvo a la fecha.',
          destacado: true),
      const Seccion('Saldo por antigüedad'),
      Tabla(
        [
          '0 a 30 días',
          '31 a 60 días',
          '61 a 90 días',
          'Más de 90 días',
          'Total'
        ],
        [
          [for (final r in rangosEdad) cop(e.edades[r] ?? 0), cop(e.saldo)]
        ],
        derecha: {0, 1, 2, 3, 4},
      ),
      const Seccion('Compras pendientes de pago'),
      Tabla(
        ['Fecha', 'Concepto', 'Valor', 'Pendiente', 'Días'],
        [
          for (final p in e.abiertas)
            [
              _dia.format(p.fecha),
              p.concepto.isEmpty ? 'Compra' : p.concepto,
              cop(p.original),
              cop(p.pendiente),
              '${p.dias}'
            ]
        ],
        derecha: {2, 3, 4},
        vacia: 'No hay compras pendientes.',
      ),
      const Seccion('Extracto (todos los movimientos)'),
      Tabla(
        ['Fecha', 'Concepto', 'Fiado', 'Abono', 'Saldo'],
        [
          for (final l in e.lineas)
            [
              _diaHora.format(l.fecha),
              l.concepto,
              l.cargo > 0 ? cop(l.cargo) : '',
              l.abono > 0 ? cop(l.abono) : '',
              cop(l.saldo)
            ]
        ],
        derecha: {2, 3, 4},
        pie: [
          '',
          'Totales',
          cop(e.totalFiado),
          cop(e.totalAbonado),
          cop(e.saldo)
        ],
        vacia: 'Sin movimientos a crédito.',
      ),
      if (formasDePago.isNotEmpty && e.saldo > 0.5)
        Parrafo('Puede pagar por transferencia:  ${formasDePago.join('   ·   ')}', destacado: true),
      const Parrafo('Los abonos se aplican primero a las compras más antiguas. '
          'Si encuentra alguna diferencia, por favor avísenos para revisarla juntos.'),
    ],
  );
}

/// Datos de un informe por periodo (se usan en la pantalla y en el PDF).
class DatosInforme {
  final Periodo periodo;
  final DateTime desde, hasta; // hasta excluido
  final ResumenPeriodo actual, anterior;
  final List<DiaSerie> dias;
  final List<TopProducto> top;
  final List<(String, double)> gastos;
  final List<Map<String, Object?>> movimientos;
  final Map<String, double> cartera;
  final List<(String nombre, EstadoCuenta estado)> deudores;
  final List<ProductoStock> productos;
  const DatosInforme({
    required this.periodo,
    required this.desde,
    required this.hasta,
    required this.actual,
    required this.anterior,
    required this.dias,
    required this.top,
    required this.gastos,
    required this.movimientos,
    required this.cartera,
    required this.deudores,
    required this.productos,
  });

  double get cajaNeta => actual.contado + actual.abonos - actual.gastos;
  double get carteraTotal => cartera.values.fold(0.0, (s, x) => s + x);
  List<ProductoStock> get inventariables => [
        for (final p in productos)
          if (p.unidad != 'serv') p
      ];
  double get valorCosto => inventariables.fold(
      0.0, (s, p) => s + (p.stock > 0 ? p.stock * p.costo : 0));
  double get valorVenta => inventariables.fold(
      0.0, (s, p) => s + (p.stock > 0 ? p.stock * p.precio : 0));
  List<ProductoStock> get porReponer => [
        for (final p in inventariables)
          if (p.agotado || p.bajo) p
      ];
  String get textoPeriodo =>
      '${_dia.format(desde)} al ${_dia.format(hasta.subtract(const Duration(days: 1)))}';
}

Future<DatosInforme> cargarInforme(Periodo periodo, DateTime ahora) async {
  final db = LocalDb.instance;
  final r = rangoPeriodo(periodo, ahora);
  final movs = await db.movimientosEntre(r.desde, r.hasta);
  final credito = await db.creditoPorCliente();
  final clientes = {
    for (final c in await db.clientes())
      c['id'] as String: c['nombre'] as String
  };
  final deudores = <(String, EstadoCuenta)>[
    for (final e in credito.entries)
      if (clientes.containsKey(e.key))
        (clientes[e.key]!, estadoDeCuenta(e.value, ahora))
  ]
    ..removeWhere((x) => x.$2.saldo <= 0.5)
    ..sort((a, b) => b.$2.diasMora.compareTo(a.$2.diasMora));
  return DatosInforme(
    periodo: periodo,
    desde: r.desde,
    hasta: r.hasta,
    actual: await db.resumenPeriodo(r.desde, r.hasta),
    anterior: await db.resumenPeriodo(r.antDesde, r.antHasta),
    dias: await db.seriePorDia(r.desde, r.hasta),
    top: await db.topProductos(r.desde, r.hasta, limite: 10),
    gastos: gastosPorConcepto(movs),
    movimientos: movs,
    cartera: carteraPorEdades(deudores.map((x) => x.$2)),
    deudores: deudores,
    productos: await db.productos(),
  );
}

const _tipos = {'ingreso': 'Venta', 'egreso': 'Gasto', 'abono': 'Abono'};

/// Informe semanal, quincenal o mensual para el dueño y el contador.
Reporte reporteInforme({
  required PerfilNegocio negocio,
  required String numero,
  required DateTime fecha,
  required DatosInforme d,
}) {
  final a = d.actual, b = d.anterior;
  List<String> fila(String c, double x, double y) =>
      [c, cop(x), cop(y), variacion(x, y)];
  return Reporte(
    titulo: tituloInforme(d.periodo),
    numero: numero,
    fecha: fecha,
    negocio: negocio,
    subtitulo: ['Periodo: ${d.textoPeriodo}'],
    bloques: [
      Indicadores([
        Indicador('Ventas', cop(a.ventas),
            '${variacion(a.ventas, b.ventas)} vs. anterior'),
        Indicador('Gastos', cop(a.gastos),
            '${variacion(a.gastos, b.gastos)} vs. anterior'),
        Indicador('Utilidad (ventas - gastos)', cop(a.utilidad)),
        Indicador('Caja neta', cop(d.cajaNeta), 'contado + abonos - gastos'),
        Indicador('N.º de ventas', '${a.nVentas}',
            'Ticket promedio ${cop(a.ticketPromedio)}'),
        Indicador('Ganancia en productos', cop(a.gananciaProductos),
            'precio - costo'),
        Indicador(
            'Por cobrar (cartera)',
            cop(d.carteraTotal),
            d.deudores.length == 1
                ? '1 cliente'
                : '${d.deudores.length} clientes'),
        Indicador('Inventario al costo', cop(d.valorCosto),
            'a precio: ${cop(d.valorVenta)}'),
      ]),
      const Seccion('Estado de resultados simplificado'),
      Tabla(
        ['Concepto', 'Este periodo', 'Periodo anterior', 'Variación'],
        [
          fila('Ventas de contado', a.contado, b.contado),
          fila('Ventas a crédito (fiado)', a.fiado, b.fiado),
          fila('Total ventas', a.ventas, b.ventas),
          fila('(-) Gastos', a.gastos, b.gastos),
          fila('= Utilidad operativa aprox.', a.utilidad, b.utilidad),
          fila('Ganancia bruta en productos', a.gananciaProductos,
              b.gananciaProductos),
        ],
        derecha: {1, 2, 3},
      ),
      const Seccion('Flujo de caja (lo que de verdad entró y salió)'),
      Tabla(
        ['Concepto', 'Valor'],
        [
          ['(+) Ventas de contado', cop(a.contado)],
          ['(+) Abonos de clientes', cop(a.abonos)],
          ['(-) Gastos pagados', cop(a.gastos)],
        ],
        derecha: {1},
        pie: ['= Caja neta del periodo', cop(d.cajaNeta)],
      ),
      const Seccion('Ingresos y pagos por medio de pago'),
      Tabla(
        ['Medio', 'Entró', 'Salió', 'Neto'],
        [
          for (final m in a.medios.medios)
            [nombresMedio[m]!, cop(a.medios.entrada(m)), cop(a.medios.salida(m)), cop(a.medios.neto(m))]
        ],
        derecha: {1, 2, 3},
        pie: a.medios.medios.isEmpty
            ? null
            : [
                'Total',
                cop(a.medios.totalEntradas),
                cop(a.medios.salidas.values.fold(0.0, (x, y) => x + y)),
                cop(a.medios.totalEntradas - a.medios.salidas.values.fold(0.0, (x, y) => x + y)),
              ],
        vacia: 'Sin pagos registrados en este periodo.',
      ),
      if (a.medios.medios.isNotEmpty)
        Parrafo('Efectivo neto: ${cop(a.medios.neto('efectivo'))} (debe cuadrar con la caja). '
            'Pagos digitales recibidos (Nequi, Daviplata, bancos y tarjetas): '
            '${cop(a.medios.totalDigital)}; concílielos con los extractos.'),
      const Seccion('Ventas por día'),
      if (d.dias.every((x) => x.ventas <= 0))
        const Parrafo('Sin ventas en este periodo.')
      else
        // En periodos largos solo se listan los días con ventas.
        Barras([
          for (final x in d.dias)
            if (d.dias.length <= 16 || x.ventas > 0)
              (_diaCorto.format(x.dia), x.ventas, cop(x.ventas))
        ]),
      const Seccion('Productos más vendidos'),
      Tabla(
        ['Producto', 'Cantidad', 'Total vendido'],
        [
          for (final t in d.top) [t.nombre, _cant(t.cantidad), cop(t.total)]
        ],
        derecha: {1, 2},
        vacia: 'Sin ventas con productos del inventario en este periodo.',
      ),
      const Seccion('Gastos por concepto'),
      Tabla(
        ['Concepto', 'Valor', '% del gasto'],
        [
          for (final (c, v) in d.gastos)
            [c, cop(v), a.gastos > 0 ? '${(v / a.gastos * 100).round()} %' : '']
        ],
        derecha: {1, 2},
        pie: d.gastos.isEmpty ? null : ['Total', cop(a.gastos), '100 %'],
        vacia: 'Sin gastos registrados en este periodo.',
      ),
      const Seccion('Cartera (cuentas por cobrar) por antigüedad'),
      Tabla(
        [
          '0 a 30 días',
          '31 a 60 días',
          '61 a 90 días',
          'Más de 90 días',
          'Total'
        ],
        [
          [
            for (final r in rangosEdad) cop(d.cartera[r] ?? 0),
            cop(d.carteraTotal)
          ]
        ],
        derecha: {0, 1, 2, 3, 4},
      ),
      Tabla(
        ['Cliente', 'Saldo', 'Debe desde', 'Días de mora'],
        [
          for (final (n, e) in d.deudores)
            [n, cop(e.saldo), _dia.format(e.debeDesde!), '${e.diasMora}']
        ],
        derecha: {1, 3},
        vacia: 'Nadie debe a la fecha.',
      ),
      const Seccion('Inventario por reponer'),
      Tabla(
        ['Producto', 'Quedan', 'Mínimo', 'Estado'],
        [
          for (final p in d.porReponer)
            [
              p.nombre,
              '${_cant(p.stock)} ${p.unidad}',
              _cant(p.minimo),
              p.agotado ? 'AGOTADO' : 'Bajo'
            ]
        ],
        derecha: {1, 2},
        vacia: 'Todo el inventario está por encima del mínimo.',
      ),
      const Seccion('Libro de movimientos del periodo'),
      Tabla(
        ['Fecha', 'Tipo', 'Concepto', 'Cliente', 'Forma', 'Valor'],
        [
          for (final m in d.movimientos)
            [
              _diaHora.format(DateTime.parse(m['fecha'] as String).toLocal()),
              _tipos[m['tipo']] ?? '${m['tipo']}',
              (m['concepto'] as String?) ?? '',
              (m['cliente_nombre'] as String?) ?? '',
              m['tipo'] == 'ingreso' && m['credito'] == 1
                  ? 'Crédito'
                  : textoPagos(
                      leerPagos(m['pagos'],
                          monto: (m['monto'] as num).toDouble(),
                          tipo: m['tipo'] as String),
                      conValor: false),
              cop((m['monto'] as num).toDouble()),
            ]
        ],
        derecha: {5},
        vacia: 'Sin movimientos en este periodo.',
      ),
      const Parrafo(
          'Cifras tomadas de los registros hechos en la app. Son un apoyo para la '
          'contabilidad: el contador debe validarlas con los soportes antes de '
          'declarar impuestos.'),
    ],
  );
}

/// Resumen corto del informe para WhatsApp.
String textoInforme(PerfilNegocio n, String numero, DatosInforme d) {
  final a = d.actual, b = d.anterior;
  return '*${n.nombreVisible}*\n'
      '*${tituloInforme(d.periodo)} N.º $numero*\n'
      'Periodo: ${d.textoPeriodo}\n\n'
      'Ventas: ${cop(a.ventas)} (${variacion(a.ventas, b.ventas)})\n'
      'Gastos: ${cop(a.gastos)} (${variacion(a.gastos, b.gastos)})\n'
      'Utilidad: ${cop(a.utilidad)}\n'
      'Caja neta: ${cop(d.cajaNeta)}\n'
      'Recibido por Nequi, bancos y tarjetas: ${cop(a.medios.totalDigital)}\n'
      'Por cobrar: ${cop(d.carteraTotal)}\n'
      'Inventario al costo: ${cop(d.valorCosto)}\n\n'
      '_El detalle completo va en el PDF adjunto._';
}
