import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/local_db.dart';
import '../domain/formato.dart';
import '../domain/resumen.dart';
import 'cliente_detalle_page.dart';
import 'clientes_page.dart';
import 'graficas.dart';
import 'herramientas_page.dart';
import 'ilustraciones.dart';
import 'inventario_page.dart';
import 'negocio_page.dart';
import 'tema.dart';
import 'ventas_page.dart';

/// Inicio: la pizarra del día y el resumen del mes. Se calcula 100 % en el
/// celular (funciona sin señal) y se actualiza solo cada vez que cambia un dato.
class TableroPage extends StatefulWidget {
  /// Cambia de pestaña (0 inicio, 1 movimientos, 2 clientes, 3 asistente).
  final ValueChanged<int>? onIr;
  const TableroPage({super.key, this.onIr});
  @override
  State<TableroPage> createState() => _TableroPageState();
}

class _TableroPageState extends State<TableroPage> {
  DatosAsistente? _d;

  @override
  void initState() {
    super.initState();
    LocalDb.instance.cambios.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    LocalDb.instance.cambios.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final d = await LocalDb.instance.datosAsistente();
    if (mounted) setState(() => _d = d);
  }

  void _abrirCliente(String id) => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ClienteDetallePage(clienteId: id)));

  @override
  Widget build(BuildContext context) {
    final d = _d;
    if (d == null) return const Center(child: CircularProgressIndicator());
    final r = d.mes;
    final p = Paleta.of(context);
    final nuevo = r.movimientos == 0 && r.nClientes == 0 && d.nVentasHoy == 0;
    final mes = DateFormat('MMMM', 'es_CO').format(DateTime.now());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: EdgeInsets.zero, children: [
        _PizarraDelDia(d: d),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(children: [
            Expanded(
              child: _AccionRapida(
                etiqueta: 'Venta',
                icono: Icons.add_rounded,
                fondo: p.ventas,
                tinta: Theme.of(context).brightness == Brightness.light
                    ? Colors.white
                    : const Color(0xFF0B2018),
                onTap: () => mostrarFormMovimiento(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AccionRapida(
                etiqueta: 'Gasto',
                icono: Icons.north_east_rounded,
                fondo: p.gastosFondo,
                tinta: p.gastos,
                onTap: () => mostrarFormMovimiento(context, tipoInicial: 'egreso'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AccionRapida(
                etiqueta: 'Abono',
                icono: Icons.payments_outlined,
                fondo: p.fiadoFondo,
                tinta: p.fiado,
                onTap: () => mostrarFormMovimiento(context, tipoInicial: 'abono'),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const TituloSeccion('Herramientas'),
            const HerramientasGrid(),
            if (d.nombreNegocio.isEmpty) ...[
              const SizedBox(height: 16),
              _InvitacionNegocio(onTap: () => mostrarMiNegocio(context)),
            ],
            if (nuevo) ...[
              const SizedBox(height: 16),
              _Bienvenida(onCliente: () => mostrarFormCliente(context)),
            ],
            if (!nuevo) ...[
              if (d.metaMensual > 0) ...[
                TituloSeccion(
                    'Meta de ${mes[0].toUpperCase()}${mes.substring(1)}'),
                _Meta(ventas: r.ingresos, meta: d.metaMensual),
              ],
              const TituloSeccion('Reportes'),
              const ReportesNegocio(),
              if (d.porReponer.isNotEmpty) ...[
                TituloSeccion(
                  'Por reponer',
                  accion: TextButton(
                      onPressed: () => widget.onIr?.call(2),
                      child: const Text('Ver inventario')),
                ),
                Card(
                  child: Column(children: [
                    for (final (i, x) in d.porReponer.take(4).indexed) ...[
                      if (i > 0) const Divider(indent: 16),
                      ListTile(
                        title: Text(x.nombre,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                            'Mínimo ${cantidadTexto(x.minimo)} · ${cop(x.precio)}'),
                        trailing: EtiquetaStock(x: x),
                      ),
                    ],
                  ]),
                ),
              ],
              TituloSeccion(
                'Te deben',
                accion: TextButton(
                    onPressed: () => widget.onIr?.call(3),
                    child: const Text('Ver clientes')),
              ),
              _PorCobrar(d: d, onCliente: _abrirCliente),
              if (d.topClientes.isNotEmpty) ...[
                const TituloSeccion('Tus mejores clientes del mes'),
                Card(
                  child: Column(children: [
                    for (final (i, c) in d.topClientes.indexed) ...[
                      if (i > 0) const Divider(indent: 72),
                      ListTile(
                        leading: AvatarCliente(nombre: c.nombre, clave: c.nombre),
                        title: Text(c.nombre,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Text(cop(c.total),
                            style: cifras(Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(color: p.ventas))),
                      ),
                    ],
                  ]),
                ),
              ],
            ],
          ]),
        ),
      ]),
    );
  }
}

/// El bloque de pizarra: lo vendido hoy en grande y una raya de tiza por venta.
class _PizarraDelDia extends StatelessWidget {
  final DatosAsistente d;
  const _PizarraDelDia({required this.d});

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    final t = Theme.of(context).textTheme;
    final hoy = DateFormat('EEEE d MMM', 'es_CO').format(DateTime.now());
    final n = d.nVentasHoy;
    return Container(
      decoration: BoxDecoration(
        color: p.pizarra,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (d.nombreNegocio.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(d.nombreNegocio,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.titleMedium?.copyWith(color: p.tizaBlanca)),
          ),
        Row(children: [
          Text('Hoy vendiste', style: t.titleSmall?.copyWith(color: p.tizaSuave)),
          const Spacer(),
          Flexible(
            child: Text('${hoy[0].toUpperCase()}${hoy.substring(1)}',
                overflow: TextOverflow.ellipsis,
                style: t.bodyMedium?.copyWith(color: p.tizaSuave)),
          ),
        ]),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(cop(d.ventasHoy),
              style: cifras(t.displaySmall
                  ?.copyWith(color: p.tizaBlanca, fontSize: 46))),
        ),
        const SizedBox(height: 16),
        if (n > 0)
          Palotes(cantidad: n, color: p.ventasTiza)
        else
          Row(children: [
            Container(
              width: 34,
              height: 3,
              decoration: BoxDecoration(
                  color: p.tizaSuave.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Cada venta de hoy suma una raya de tiza.',
                  style: t.bodyMedium?.copyWith(color: p.tizaSuave)),
            ),
          ]),
        const SizedBox(height: 14),
        Text.rich(
          TextSpan(children: [
            TextSpan(
                text: n == 1 ? '1 venta' : '$n ventas',
                style: TextStyle(color: p.tizaBlanca, fontWeight: FontWeight.w700)),
            if (n > 40) const TextSpan(text: ' (se dibujan 40)'),
            const TextSpan(text: '  ·  Esta semana '),
            TextSpan(
                text: cop(d.ventasSemana),
                style: TextStyle(color: p.tizaBlanca, fontWeight: FontWeight.w700)),
          ]),
          style: cifras(t.bodyMedium?.copyWith(color: p.tizaSuave)),
        ),
      ]),
    );
  }
}

class _AccionRapida extends StatelessWidget {
  final String etiqueta;
  final IconData icono;
  final Color fondo, tinta;
  final VoidCallback onTap;
  const _AccionRapida(
      {required this.etiqueta,
      required this.icono,
      required this.fondo,
      required this.tinta,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Registrar $etiqueta',
        excludeSemantics: true,
        child: Material(
          color: fondo,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: SizedBox(
              height: 76,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icono, color: tinta, size: 26),
                const SizedBox(height: 4),
                Text(etiqueta,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: tinta, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      );
}

class _PorCobrar extends StatelessWidget {
  final DatosAsistente d;
  final ValueChanged<String> onCliente;
  const _PorCobrar({required this.d, required this.onCliente});

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final deben = d.deudores;
    if (deben.isEmpty) {
      return Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: p.ventasFondo, borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.verified_outlined, color: p.ventas),
          ),
          title: const Text('Nadie te debe'),
          subtitle: const Text('Cuando vendas fiado, aquí verás a quién cobrarle.'),
        ),
      );
    }
    return Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(cop(d.mes.porCobrar),
                    style: cifras(t.headlineSmall?.copyWith(color: p.fiado))),
              ),
            ),
            Text(
                deben.length == 1 ? '1 cliente' : '${deben.length} clientes',
                style: t.bodyMedium?.copyWith(color: esquema.onSurfaceVariant)),
          ]),
        ),
        for (final (i, c) in deben.take(5).indexed) ...[
          Divider(indent: i == 0 ? 0 : 72),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: AvatarCliente(nombre: c.nombre, clave: c.nombre),
            title: Text(c.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(cop(c.saldo),
                  style: cifras(t.titleSmall?.copyWith(color: p.fiado))),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: esquema.onSurfaceVariant),
            ]),
            onTap: () => onCliente(c.id),
          ),
        ],
        const SizedBox(height: 6),
      ]),
    );
  }
}

class _Bienvenida extends StatelessWidget {
  final VoidCallback onCliente;
  const _Bienvenida({required this.onCliente});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(children: [
          const SizedBox(width: 180, height: 150, child: IlustracionPizarra()),
          const SizedBox(height: 16),
          Text('Tu pizarra está limpia', style: t.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Anota tu primera venta con el botón verde. Si vendes fiado, '
            'primero agrega al cliente para saber quién te debe.',
            textAlign: TextAlign.center,
            style: t.bodyLarge?.copyWith(color: esquema.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onCliente,
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Agregar cliente'),
          ),
        ]),
      ),
    );
  }
}

class _InvitacionNegocio extends StatelessWidget {
  final VoidCallback onTap;
  const _InvitacionNegocio({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    final t = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: p.ventasFondo, borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.storefront_outlined, color: p.ventas),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Cuéntanos de tu negocio', style: t.titleMedium),
                const SizedBox(height: 2),
                Text('Nombre, tipo y meta de ventas: 3 preguntas, 30 segundos.',
                    style: t.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
            ),
            const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final double ventas, meta;
  const _Meta({required this.ventas, required this.meta});
  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final f = (ventas / meta).clamp(0.0, 1.0);
    final falta = meta - ventas;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${(ventas / meta * 100).round()} %',
                style: cifras(t.headlineMedium?.copyWith(color: p.ventas))),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${cop(ventas)} de ${cop(meta)}',
                    style: cifras(t.bodyMedium?.copyWith(color: esquema.onSurfaceVariant))),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: f,
              minHeight: 12,
              color: p.ventas,
              backgroundColor: esquema.surfaceContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(falta > 0 ? 'Te faltan ${cop(falta)} para cumplirla.' : '¡Meta cumplida!',
              style: t.bodyMedium),
        ]),
      ),
    );
  }
}

enum Periodo { hoy, semana, mes, mesPasado }

/// Tablero de reportes: periodo, indicadores con comparación y gráficas.
class ReportesNegocio extends StatefulWidget {
  const ReportesNegocio({super.key});
  @override
  State<ReportesNegocio> createState() => _ReportesNegocioState();
}

class _ReportesNegocioState extends State<ReportesNegocio> {
  Periodo _p = Periodo.mes;
  ResumenPeriodo? _act, _ant;
  List<GrupoBarras> _grupos = const [];
  List<TopProducto> _top = const [];
  int _pedido = 0;

  @override
  void initState() {
    super.initState();
    LocalDb.instance.cambios.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    LocalDb.instance.cambios.removeListener(_load);
    super.dispose();
  }

  static DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);

  String get _contra => switch (_p) {
        Periodo.hoy => 'vs. ayer',
        Periodo.semana => 'vs. 7 días antes',
        Periodo.mes => 'vs. mismo tramo del mes pasado',
        Periodo.mesPasado => 'vs. el mes anterior',
      };

  Future<void> _load() async {
    final pedido = ++_pedido;
    final db = LocalDb.instance;
    final hoy = _dia(DateTime.now());
    final manana = hoy.add(const Duration(days: 1));
    final ini = DateTime(hoy.year, hoy.month);
    final iniAnt = DateTime(hoy.year, hoy.month - 1);
    final (a, b, pa, pb) = switch (_p) {
      Periodo.hoy => (hoy, manana, hoy.subtract(const Duration(days: 1)), hoy),
      Periodo.semana => (
          hoy.subtract(const Duration(days: 6)),
          manana,
          hoy.subtract(const Duration(days: 13)),
          hoy.subtract(const Duration(days: 6)),
        ),
      Periodo.mes => (
          ini,
          manana,
          iniAnt,
          DateTime(iniAnt.year, iniAnt.month, hoy.day + 1),
        ),
      Periodo.mesPasado => (iniAnt, ini, DateTime(hoy.year, hoy.month - 2), iniAnt),
    };
    final act = await db.resumenPeriodo(a, b);
    final ant = await db.resumenPeriodo(pa, pb);
    final top = await db.topProductos(a, b);
    // Gráfica: hoy y 7 días, los últimos 7 días; meses, por día o por semana.
    final (ga, gb) = _p == Periodo.hoy || _p == Periodo.semana
        ? (hoy.subtract(const Duration(days: 6)), manana)
        : (a, b);
    final serie = await db.seriePorDia(ga, gb);
    final grupos = <GrupoBarras>[];
    final largo = DateFormat("EEEE d 'de' MMMM", 'es_CO');
    final corto = DateFormat('d MMM', 'es_CO');
    if (serie.length <= 14) {
      for (final s in serie) {
        final l = _p == Periodo.mes || _p == Periodo.mesPasado
            ? '${s.dia.day}'
            : DateFormat('EEE', 'es_CO').format(s.dia).replaceAll('.', '');
        final dl = largo.format(s.dia);
        grupos.add((
          etiqueta: l,
          detalle: '${dl[0].toUpperCase()}${dl.substring(1)}',
          ventas: s.ventas,
          gastos: s.gastos,
        ));
      }
    } else {
      for (var i = 0; i < serie.length; i += 7) {
        final sem = serie.sublist(i, (i + 7).clamp(0, serie.length));
        grupos.add((
          etiqueta: 'Sem ${i ~/ 7 + 1}',
          detalle: 'Del ${corto.format(sem.first.dia)} al ${corto.format(sem.last.dia)}',
          ventas: sem.fold(0.0, (s, x) => s + x.ventas),
          gastos: sem.fold(0.0, (s, x) => s + x.gastos),
        ));
      }
    }
    if (!mounted || pedido != _pedido) return;
    setState(() {
      _act = act;
      _ant = ant;
      _top = top;
      _grupos = grupos;
    });
  }

  @override
  Widget build(BuildContext context) {
    final act = _act, ant = _ant;
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SegmentedButton<Periodo>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: Periodo.hoy, label: Text('Hoy')),
          ButtonSegment(value: Periodo.semana, label: Text('7 días')),
          ButtonSegment(value: Periodo.mes, label: Text('Mes')),
          ButtonSegment(value: Periodo.mesPasado, label: Text('Mes ant.')),
        ],
        selected: {_p},
        onSelectionChanged: (s) {
          setState(() => _p = s.first);
          _load();
        },
      ),
      const SizedBox(height: 12),
      if (act == null || ant == null)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        )
      else ...[
        Row(children: [
          Expanded(
              child: _Kpi(
                  titulo: 'Ventas', valor: act.ventas, antes: ant.ventas,
                  subeBien: true, contra: _contra)),
          const SizedBox(width: 10),
          Expanded(
              child: _Kpi(
                  titulo: 'Gastos', valor: act.gastos, antes: ant.gastos,
                  subeBien: false, contra: _contra)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _Kpi(
                  titulo: 'Te queda', valor: act.utilidad, antes: ant.utilidad,
                  subeBien: true, contra: _contra)),
          const SizedBox(width: 10),
          Expanded(
              child: act.gananciaProductos > 0 || ant.gananciaProductos > 0
                  ? _Kpi(
                      titulo: 'Ganancia en productos',
                      valor: act.gananciaProductos,
                      antes: ant.gananciaProductos,
                      subeBien: true,
                      contra: _contra)
                  : _Kpi(
                      titulo: 'Venta promedio',
                      valor: act.ticketPromedio,
                      antes: ant.ticketPromedio,
                      subeBien: true,
                      contra: _contra)),
        ]),
        const SizedBox(height: 10),
        _Panel(
          titulo: 'Ventas y gastos',
          child: BarrasVentasGastos(grupos: _grupos),
        ),
        const SizedBox(height: 10),
        _Panel(
          titulo: '¿Cómo te pagaron?',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            BarraContadoFiado(contado: act.contado, fiado: act.fiado),
            if (act.abonos > 0) ...[
              const SizedBox(height: 10),
              Text('Además recibiste ${cop(act.abonos)} en abonos de fiados.',
                  style: t.bodyMedium?.copyWith(color: esquema.onSurfaceVariant)),
            ],
          ]),
        ),
        const SizedBox(height: 10),
        _Panel(
          titulo: 'Lo más vendido',
          child: _top.isEmpty
              ? Text(
                  'Cuando vendas eligiendo productos del inventario, aquí verás '
                  'cuáles se venden más.',
                  style: t.bodyMedium?.copyWith(color: esquema.onSurfaceVariant))
              : BarrasRanking(filas: [
                  for (final x in _top)
                    (
                      nombre: x.nombre,
                      detalle: '${cantidadTexto(x.cantidad)} und.',
                      valor: x.total
                    )
                ]),
        ),
      ],
    ]);
  }
}

class _Panel extends StatelessWidget {
  final String titulo;
  final Widget child;
  const _Panel({required this.titulo, required this.child});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ]),
        ),
      );
}

/// Indicador con su cambio frente al periodo anterior (flecha + texto, no
/// solo color).
class _Kpi extends StatelessWidget {
  final String titulo, contra;
  final double valor, antes;
  final bool subeBien;
  const _Kpi(
      {required this.titulo,
      required this.valor,
      required this.antes,
      required this.subeBien,
      required this.contra});

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    Widget cambio;
    if (antes.abs() < 1) {
      cambio = Text('Sin datos para comparar',
          maxLines: 2,
          style: t.bodySmall?.copyWith(color: esquema.onSurfaceVariant));
    } else {
      final pct = ((valor - antes) / antes.abs() * 100).round();
      final sube = pct > 0;
      final bien = pct == 0 ? null : (sube == subeBien);
      final color = bien == null
          ? esquema.onSurfaceVariant
          : (bien ? p.ventas : p.gastos);
      cambio = Text.rich(
        TextSpan(children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Icon(
                pct == 0
                    ? Icons.remove
                    : (sube ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded),
                size: 15,
                color: color),
          ),
          TextSpan(
              text: ' ${pct > 0 ? '+' : ''}$pct % ',
              style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          TextSpan(text: contra, style: TextStyle(color: esquema.onSurfaceVariant)),
        ]),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: cifras(t.bodySmall),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.bodyMedium?.copyWith(color: esquema.onSurfaceVariant)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(cop(valor),
                style: cifras(t.titleLarge?.copyWith(
                    color: valor < 0 ? p.gastos : esquema.onSurface))),
          ),
          const SizedBox(height: 6),
          SizedBox(height: 34, child: cambio),
        ]),
      ),
    );
  }
}