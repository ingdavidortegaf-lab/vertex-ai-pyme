import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/local_db.dart';
import '../domain/formato.dart';
import '../domain/resumen.dart';
import 'cliente_detalle_page.dart';
import 'clientes_page.dart';
import 'ilustraciones.dart';
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
                tinta: Colors.white,
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
            if (nuevo) ...[
              const SizedBox(height: 16),
              _Bienvenida(onCliente: () => mostrarFormCliente(context)),
            ],
            if (!nuevo) ...[
              TituloSeccion('Este mes · ${mes[0].toUpperCase()}${mes.substring(1)}'),
              _ResumenMes(r: r),
              TituloSeccion(
                'Te deben',
                accion: TextButton(
                    onPressed: () => widget.onIr?.call(2),
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
    final hoy = DateFormat("EEEE d 'de' MMMM", 'es_CO').format(DateTime.now());
    final n = d.nVentasHoy;
    return Container(
      decoration: BoxDecoration(
        color: p.pizarra,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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

/// Utilidad del mes y dos barras cuyo largo es el monto exacto.
class _ResumenMes extends StatelessWidget {
  final Resumen r;
  const _ResumenMes({required this.r});

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final tope = r.ingresos > r.egresos ? r.ingresos : r.egresos;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Te queda (ventas menos gastos)',
              style: t.bodyMedium?.copyWith(color: esquema.onSurfaceVariant)),
          const SizedBox(height: 2),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(cop(r.utilidad),
                    style: cifras(t.headlineMedium?.copyWith(
                        color: r.utilidad < 0 ? p.gastos : esquema.onSurface))),
              ),
            ),
            if (r.ingresos > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: r.utilidad < 0 ? p.gastosFondo : p.ventasFondo,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Margen ${(r.margen * 100).round()} %',
                    style: t.labelLarge?.copyWith(
                        color: r.utilidad < 0 ? p.gastos : p.ventas)),
              ),
          ]),
          const SizedBox(height: 18),
          _BarraExacta(
              etiqueta: 'Ventas',
              detalle: r.nIngresos == 1 ? '1 venta' : '${r.nIngresos} ventas',
              monto: r.ingresos,
              tope: tope,
              color: p.ventas),
          const SizedBox(height: 14),
          _BarraExacta(
              etiqueta: 'Gastos',
              detalle: r.nEgresos == 1 ? '1 gasto' : '${r.nEgresos} gastos',
              monto: r.egresos,
              tope: tope,
              color: p.gastos),
        ]),
      ),
    );
  }
}

class _BarraExacta extends StatelessWidget {
  final String etiqueta, detalle;
  final double monto, tope;
  final Color color;
  const _BarraExacta(
      {required this.etiqueta,
      required this.detalle,
      required this.monto,
      required this.tope,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final f = tope > 0 ? (monto / tope).clamp(0.0, 1.0) : 0.0;
    final quieto = MediaQuery.disableAnimationsOf(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(etiqueta, style: t.titleSmall),
        const SizedBox(width: 8),
        Expanded(
          child: Text(detalle,
              style: t.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
        ),
        Text(cop(monto), style: cifras(t.titleSmall?.copyWith(color: color))),
      ]),
      const SizedBox(height: 8),
      LayoutBuilder(
        builder: (context, box) => Stack(children: [
          Container(
            height: 12,
            decoration: BoxDecoration(
                color: esquema.surfaceContainer,
                borderRadius: BorderRadius.circular(6)),
          ),
          AnimatedContainer(
            duration: quieto ? Duration.zero : const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            height: 12,
            width: box.maxWidth * f,
            decoration:
                BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
          ),
        ]),
      ),
    ]);
  }
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
        for (final c in deben.take(5)) ...[
          const Divider(indent: 72),
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
