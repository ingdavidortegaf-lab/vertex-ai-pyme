import 'package:flutter/material.dart';
import '../domain/codigos.dart';
import '../domain/resumen.dart';
import 'package:intl/intl.dart';
import '../data/local_db.dart';
import '../data/sync_service.dart';
import '../domain/caja.dart';
import '../domain/formato.dart';
import '../domain/roles.dart';
import 'comun.dart';
import 'perfil_gate.dart' show autorizarSupervisor;
import 'tema.dart';

/// Turno de caja en la parte de arriba de la Caja: abrirlo con la base o
/// ver el efectivo esperado y cerrarlo contando.
class TarjetaTurno extends StatefulWidget {
  const TarjetaTurno({super.key});
  @override
  State<TarjetaTurno> createState() => _TarjetaTurnoState();
}

class _TarjetaTurnoState extends State<TarjetaTurno> {
  final db = LocalDb.instance;
  EfectivoTurno? _ef;

  @override
  void initState() {
    super.initState();
    db.cambios.addListener(_cargar);
    db.turnoAbierto.addListener(_cargar);
    _cargar();
  }

  @override
  void dispose() {
    db.cambios.removeListener(_cargar);
    db.turnoAbierto.removeListener(_cargar);
    super.dispose();
  }

  Future<void> _cargar() async {
    final e = await db.efectivoTurnoAbierto();
    if (mounted) setState(() => _ef = e);
  }

  Future<void> _abrir() async {
    final base = await pedirValor(context,
        titulo: 'Abrir turno de caja',
        texto: '¿Con cuánto efectivo empieza el cajón? (la base para dar vueltas)',
        etiqueta: 'Base en efectivo',
        boton: 'Abrir turno',
        permiteCero: true);
    if (base == null) return;
    await db.abrirTurno(base);
    avisar('Turno abierto con ${cop(base)} de base');
  }

  Future<void> _cerrar() async {
    final ef = await db.efectivoTurnoAbierto();
    if (ef == null || !mounted) return;
    final r = await showDialog<(double, String)>(context: context, builder: (_) => _CerrarTurno(ef: ef));
    if (r == null) return;
    final t = await db.cerrarTurno(r.$1, nota: r.$2);
    SyncService.instance.sync();
    final d = t.diferencia ?? 0;
    avisar(d.abs() < 0.5 ? 'Turno cerrado: la caja cuadra' : 'Turno cerrado: ${textoDiferencia(d).toLowerCase()} ${cop(d.abs())}');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Paleta.of(context);
    final turno = db.turnoAbierto.value;
    if (turno == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
        child: OutlinedButton.icon(
          key: const ValueKey('abrir_turno'),
          onPressed: _abrir,
          icon: const Icon(Icons.lock_open_outlined),
          label: const Text('Abrir turno de caja'),
        ),
      );
    }
    final hora = DateFormat('h:mm a', 'es_CO').format(turno.abre);
    final quien = turno.perfil.isEmpty ? '' : ' de ${turno.perfil}';
    return Card(
      margin: const EdgeInsets.fromLTRB(4, 12, 4, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Turno$quien desde las $hora', style: t.titleSmall),
              const SizedBox(height: 2),
              Text(
                _ef == null ? 'Calculando…' : 'Efectivo esperado: ${cop(_ef!.esperado)}',
                key: const ValueKey('efectivo_esperado'),
                style: cifras(t.bodyMedium?.copyWith(color: p.ventas)),
              ),
            ]),
          ),
          FilledButton.tonal(
            key: const ValueKey('cerrar_turno'),
            onPressed: _cerrar,
            child: const Text('Cerrar turno'),
          ),
        ]),
      ),
    );
  }
}

class _CerrarTurno extends StatefulWidget {
  final EfectivoTurno ef;
  const _CerrarTurno({required this.ef});
  @override
  State<_CerrarTurno> createState() => _CerrarTurnoState();
}

class _CerrarTurnoState extends State<_CerrarTurno> {
  final _contado = TextEditingController();
  final _nota = TextEditingController();

  @override
  void dispose() {
    _contado.dispose();
    _nota.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ef = widget.ef;
    final contado = parseMonto(_contado.text) ?? (_contado.text.trim() == '0' ? 0 : null);
    final d = contado == null ? null : contado - ef.esperado;
    Widget linea(String a, double v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [Expanded(child: Text(a)), Text(cop(v), style: cifras(t.bodyMedium))]),
        );
    return AlertDialog(
      title: const Text('Cerrar turno'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          linea('Base', ef.base),
          linea('Entró en efectivo', ef.entradas),
          linea('Salió en efectivo', -ef.salidas),
          const Divider(),
          linea('Debería haber', ef.esperado),
          if (ef.otrosMedios != 0)
            Text('Además entraron ${cop(ef.otrosMedios)} por Nequi, tarjeta u otros (no van al cajón).',
                style: t.bodySmall),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('campo_contado'),
            controller: _contado,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '¿Cuánto efectivo hay?', prefixText: r'$ '),
            onChanged: (_) => setState(() {}),
          ),
          if (d != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                d.abs() < 0.5 ? 'Cuadra exacto' : '${textoDiferencia(d)} ${cop(d.abs())}',
                key: const ValueKey('diferencia_turno'),
                style: t.titleSmall?.copyWith(
                    color: d.abs() < 0.5
                        ? Paleta.of(context).ventas
                        : (d < 0 ? Theme.of(context).colorScheme.error : Paleta.of(context).fiado)),
              ),
            ),
          TextField(
            controller: _nota,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Nota (opcional)', hintText: 'Ej.: billete roto'),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          key: const ValueKey('confirmar_cierre'),
          onPressed: contado == null ? null : () => Navigator.pop(context, (contado, _nota.text)),
          child: const Text('Cerrar turno'),
        ),
      ],
    );
  }
}

/// Pide un valor en pesos. Null si se cancela.
Future<double?> pedirValor(BuildContext context,
    {required String titulo,
    required String texto,
    required String etiqueta,
    required String boton,
    bool permiteCero = false}) async {
  final r = await dialogoConTexto<double>(
    context,
    builder: (c, ctrl) => AlertDialog(
      title: Text(titulo),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(texto),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('campo_valor'),
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: etiqueta, prefixText: r'$ '),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
        FilledButton(
          key: const ValueKey('confirmar_valor'),
          onPressed: () {
            final v = parseMonto(ctrl.text) ?? (permiteCero && ctrl.text.trim().replaceAll('0', '').isEmpty ? 0.0 : null);
            if (v != null) Navigator.pop(c, v);
          },
          child: Text(boton),
        ),
      ],
    ),
  );
  return r;
}

/// ¿Se puede anular este movimiento desde la caja? (lo decide la cuenta: el
/// perfil sin permiso necesita que un supervisor autorice).
bool sePuedeAnular(Map<String, Object?> v) =>
    LocalDb.instance.equipo.value.puede(Permiso.anularMovimiento) &&
    v['tipo'] != 'anulacion' &&
    (v['anulada'] as num? ?? 0) == 0;

/// Al mantener presionada una venta con productos: devolver algunos o anular
/// toda la venta. Sin productos, va directo a anular.
Future<void> anularODevolver(BuildContext context, Map<String, Object?> v) async {
  final db = LocalDb.instance;
  final items = v['tipo'] == 'ingreso' ? await db.productosDeVenta(v['id'] as String) : const <ItemVenta>[];
  if (!context.mounted) return;
  if (items.isEmpty) return anularDesdeCaja(context, v);
  final que = await showModalBottomSheet<String>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          title: Text('${v['concepto']}', maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(cop((v['monto'] as num).toDouble())),
        ),
        const Divider(),
        ListTile(
          key: const ValueKey('opcion_devolver'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          leading: const Icon(Icons.assignment_return_outlined),
          title: const Text('Devolver productos'),
          subtitle: const Text('El cliente regresa uno o varios; el resto queda vendido'),
          onTap: () => Navigator.pop(c, 'devolver'),
        ),
        ListTile(
          key: const ValueKey('opcion_anular'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          leading: Icon(Icons.block, color: Theme.of(c).colorScheme.error),
          title: const Text('Anular toda la venta'),
          onTap: () => Navigator.pop(c, 'anular'),
        ),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (que == null || !context.mounted) return;
  if (que == 'anular') return anularDesdeCaja(context, v);
  final devueltos = await showDialog<Map<String, double>>(
    context: context,
    builder: (_) => _DialogoDevolver(items: items),
  );
  if (devueltos == null || devueltos.isEmpty || !context.mounted) return;
  var autoriza = '';
  if (!db.puede(Permiso.anularMovimiento)) {
    autoriza = await autorizarSupervisor(context, que: 'la devolución') ?? '';
    if (autoriza.isEmpty) return;
  }
  try {
    final r = await db.devolverProductos(v['id'] as String, devueltos, autoriza: autoriza);
    SyncService.instance.sync();
    final fiado = v['credito'] == 1;
    avisar(fiado
        ? 'Devolución guardada: se descuentan ${cop(r.devolver)} de la deuda'
        : 'Devolución guardada: devuelve ${cop(r.devolver)} al cliente');
  } on StateError {
    avisar('No se pudo devolver: la venta ya estaba anulada o tiene factura electrónica.');
  }
}

class _DialogoDevolver extends StatefulWidget {
  final List<ItemVenta> items;
  const _DialogoDevolver({required this.items});
  @override
  State<_DialogoDevolver> createState() => _DialogoDevolverState();
}

class _DialogoDevolverState extends State<_DialogoDevolver> {
  final _dev = <String, double>{};

  double get _valor => widget.items.fold(0.0, (s, i) => s + (_dev[i.productoId] ?? 0) * i.precio);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('¿Qué devuelve?'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final i in widget.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(i.nombre, style: t.bodyLarge),
                      Text('Compró ${cantidadConUnidad(i.cantidad, i.unidad)} · ${precioConUnidad(i.precio, i.unidad)}',
                          style: t.bodySmall),
                    ]),
                  ),
                  IconButton(
                    tooltip: 'Uno menos',
                    onPressed: (_dev[i.productoId] ?? 0) <= 0
                        ? null
                        : () => setState(() => _dev[i.productoId] =
                            ((_dev[i.productoId]! - (esFraccionable(i.unidad) ? 0.5 : 1)).clamp(0, i.cantidad))
                                .toDouble()),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text(cantidadConUnidad(_dev[i.productoId] ?? 0, i.unidad),
                        key: ValueKey('devuelve_${i.nombre}'), textAlign: TextAlign.center),
                  ),
                  IconButton(
                    key: ValueKey('devolver_mas_${i.nombre}'),
                    tooltip: 'Uno más',
                    onPressed: (_dev[i.productoId] ?? 0) >= i.cantidad
                        ? null
                        : () => setState(() => _dev[i.productoId] =
                            (((_dev[i.productoId] ?? 0) + (esFraccionable(i.unidad) ? 0.5 : 1)).clamp(0, i.cantidad))
                                .toDouble()),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ]),
              ),
            const Divider(),
            Align(
              alignment: Alignment.centerRight,
              child: Text('A devolver: ${cop(_valor)}', style: cifras(t.titleMedium)),
            ),
            const SizedBox(height: 6),
            Text('La venta se anula y se registra una nueva con lo que se queda el cliente. '
                'Lo devuelto vuelve al inventario.',
                style: t.bodySmall),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          key: const ValueKey('confirmar_devolucion'),
          onPressed: _valor <= 0
              ? null
              : () => Navigator.pop(context, {
                    for (final e in _dev.entries)
                      if (e.value > 0) e.key: e.value
                  }),
          child: const Text('Devolver'),
        ),
      ],
    );
  }
}

/// Anula un movimiento: pide el motivo, y si quien atiende no puede anular,
/// la autorización de un supervisor con su PIN.
Future<void> anularDesdeCaja(BuildContext context, Map<String, Object?> v) async {
  final db = LocalDb.instance;
  final monto = (v['monto'] as num).toDouble();
  final texto = await dialogoConTexto<String>(
    context,
    builder: (c, motivo) => AlertDialog(
      title: const Text('¿Anular este movimiento?'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('«${v['concepto']}» por ${cop(monto)}.'),
        const SizedBox(height: 8),
        const Text('No se borra: queda un movimiento en contra con la fecha de hoy. '
            'Si tenía productos, vuelven al inventario.'),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('motivo_anulacion'),
          controller: motivo,
          maxLength: 60,
          decoration: const InputDecoration(labelText: 'Motivo', hintText: 'Ej.: se cobró dos veces'),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
        FilledButton(
          key: const ValueKey('confirmar_anulacion'),
          onPressed: () => Navigator.pop(c, motivo.text),
          child: const Text('Anular'),
        ),
      ],
    ),
  );
  if (texto == null || !context.mounted) return;
  var autoriza = '';
  if (!db.puede(Permiso.anularMovimiento)) {
    autoriza = await autorizarSupervisor(context, que: 'la anulación') ?? '';
    if (autoriza.isEmpty) return;
  }
  try {
    await db.anular(v['id'] as String, motivo: texto, autoriza: autoriza);
    SyncService.instance.sync();
    avisar('Movimiento anulado');
  } on StateError {
    avisar('No se pudo anular: ya estaba anulado o no se encontró.');
  }
}
