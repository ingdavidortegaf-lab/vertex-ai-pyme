import 'package:flutter/material.dart';
import '../data/local_db.dart';
import '../data/sync_service.dart';
import '../domain/ejemplos.dart';
import '../domain/formato.dart';
import '../domain/obligaciones.dart';
import '../domain/pagos.dart';
import 'comun.dart';
import 'pago_widget.dart';
import 'tema.dart';
import 'terceros_page.dart';

/// Pagos fijos del mes: arriendo, luz, agua, internet y los propios de cada
/// negocio. Avisa qué se pasó y qué vence pronto; al pagar queda el gasto.
class PagosFijosPage extends StatefulWidget {
  const PagosFijosPage({super.key});
  @override
  State<PagosFijosPage> createState() => _PagosFijosPageState();
}

class _PagosFijosPageState extends State<PagosFijosPage> {
  List<PagoFijo> _items = [];
  bool _cargado = false;

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
    final l = await LocalDb.instance.pagosFijos();
    if (mounted) {
      setState(() {
        _items = l;
        _cargado = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Paleta.of(context);
    final hoy = DateTime.now();
    final lista = ordenarFijos(_items, hoy);
    final falta = faltaEsteMes(_items, hoy);
    final usados = _items.map((x) => x.nombre.toLowerCase()).toSet();
    final sugeridos = fijosSugeridos(LocalDb.instance.tipoNegocio.value)
        .where((s) => !usados.contains(s.toLowerCase()))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Pagos fijos del mes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => mostrarFormFijo(context),
        icon: const Icon(Icons.add),
        label: const Text('Agregar pago fijo'),
      ),
      body: !_cargado
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 96), children: [
              Card(
                color: p.gastosFondo,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Te falta pagar este mes', style: t.labelLarge?.copyWith(color: p.gastos)),
                    Text(cop(falta), style: cifras(t.headlineMedium?.copyWith(color: p.gastos))),
                    Text('Arriendo, servicios y demás compromisos de cada mes. '
                        'Te avisamos 5 días antes de que venzan.',
                        style: t.bodySmall),
                  ]),
                ),
              ),
              if (sugeridos.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_items.isEmpty ? 'Empieza con uno de estos' : 'Agregar rápido', style: t.titleSmall),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  for (final s in sugeridos)
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: Text(s),
                      onPressed: () => mostrarFormFijo(context, nombreInicial: s),
                    ),
                ]),
              ],
              const SizedBox(height: 12),
              if (lista.isNotEmpty)
                Card(
                  child: Column(children: [
                    for (final (i, f) in lista.indexed) ...[
                      if (i > 0) const Divider(indent: 16),
                      FilaFijo(f: f, hoy: hoy),
                    ],
                  ]),
                ),
            ]),
    );
  }
}

/// Fila de un pago fijo con su estado y el botón para pagarlo.
class FilaFijo extends StatelessWidget {
  final PagoFijo f;
  final DateTime hoy;
  const FilaFijo({super.key, required this.f, required this.hoy});

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    final t = Theme.of(context).textTheme;
    final e = estadoFijo(f, hoy);
    final color = switch (e) {
      EstadoFijo.vencido => Theme.of(context).colorScheme.error,
      EstadoFijo.pronto => p.fiado,
      EstadoFijo.pagado => p.ventas,
      EstadoFijo.pendiente => Theme.of(context).colorScheme.onSurfaceVariant,
    };
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      leading: Icon(
          e == EstadoFijo.pagado ? Icons.check_circle : Icons.event_repeat_outlined,
          color: color),
      title: Text(f.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
          [
            textoEstadoFijo(f, hoy),
            if (f.terceroNombre != null) f.terceroNombre!,
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.bodySmall?.copyWith(color: color)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(cop(e == EstadoFijo.pagado ? f.pagadoEsteMes : f.monto),
            style: cifras(t.titleSmall)),
        if (e != EstadoFijo.pagado) ...[
          const SizedBox(width: 6),
          FilledButton.tonal(
            onPressed: () => pagarFijo(context, f),
            child: const Text('Pagar'),
          ),
        ],
      ]),
      onTap: () => mostrarFormFijo(context, fijo: f),
    );
  }
}

/// Pagar un pago fijo: confirma el valor (la luz cambia cada mes) y el medio.
Future<void> pagarFijo(BuildContext context, PagoFijo f) async {
  final monto = TextEditingController(text: f.monto > 0 ? f.monto.toStringAsFixed(0) : '');
  var pagos = <Pago>[];
  String? error;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (c) => StatefulBuilder(builder: (c, set) {
      final t = Theme.of(c).textTheme;
      final valor = parseMonto(monto.text) ?? 0;
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(c).bottom),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Pagar ${f.nombre}', style: t.headlineSmall),
            const SizedBox(height: 12),
            TextField(
              controller: monto,
              autofocus: f.monto <= 0,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: cifras(t.headlineSmall),
              decoration: const InputDecoration(
                  labelText: 'Valor de este mes',
                  helperText: 'Si el recibo llegó por otro valor, cámbialo aquí.',
                  prefixText: r'$ '),
              onChanged: (_) => set(() {}),
            ),
            const SizedBox(height: 12),
            SelectorPago(
                titulo: '¿Con qué pagaste?',
                total: valor,
                error: error,
                onChanged: (l) => pagos = l),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                final v = parseMonto(monto.text);
                final l = normalizarPagos(pagos);
                final err = v == null || v <= 0 ? 'Escribe el valor' : problemaPagos(l, v);
                if (err != null) {
                  set(() => error = err);
                  return;
                }
                Navigator.pop(c, true);
              },
              child: const Text('Guardar pago'),
            ),
          ]),
        ),
      );
    }),
  );
  final v = parseMonto(monto.text);
  monto.dispose();
  if (ok != true || v == null) return;
  await LocalDb.instance.pagarFijo(f.id, v, normalizarPagos(pagos));
  SyncService.instance.sync();
  avisar('${f.nombre} pagado. Quedó como gasto.');
}

/// Crear o editar un pago fijo.
Future<void> mostrarFormFijo(BuildContext context, {PagoFijo? fijo, String nombreInicial = ''}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FormFijo(fijo: fijo, nombreInicial: nombreInicial),
  );
}

class _FormFijo extends StatefulWidget {
  final PagoFijo? fijo;
  final String nombreInicial;
  const _FormFijo({this.fijo, this.nombreInicial = ''});
  @override
  State<_FormFijo> createState() => _FormFijoState();
}

class _FormFijoState extends State<_FormFijo> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.fijo?.nombre ?? widget.nombreInicial);
  late final _monto = TextEditingController(
      text: (widget.fijo?.monto ?? 0) > 0 ? widget.fijo!.monto.toStringAsFixed(0) : '');
  late int _dia = widget.fijo?.dia ?? 5;
  late String? _terceroId = widget.fijo?.terceroId;
  late String? _terceroNombre = widget.fijo?.terceroNombre;

  @override
  void dispose() {
    _nombre.dispose();
    _monto.dispose();
    super.dispose();
  }

  String get _claseTercero {
    final n = _nombre.text.toLowerCase();
    if (n.contains('arriendo')) return 'arriendo';
    if (n.contains('pago a') || n.contains('pago al')) return 'empleado';
    if (['luz', 'agua', 'internet', 'gas', 'cable', 'datos'].any(n.contains)) return 'servicios';
    return 'otro';
  }

  Future<void> _elegirTercero() async {
    final id = await elegirTercero(context, actual: _terceroId, claseNuevo: _claseTercero);
    if (id == null || !mounted) return;
    final x = id.isEmpty ? null : await LocalDb.instance.proveedor(id);
    setState(() {
      _terceroId = x == null ? null : id;
      _terceroNombre = x?['nombre'] as String?;
    });
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    await LocalDb.instance.saveFijo(_nombre.text, parseMonto(_monto.text) ?? 0, _dia,
        id: widget.fijo?.id, terceroId: _terceroId);
    if (mounted) Navigator.pop(context);
    avisar(widget.fijo == null ? 'Pago fijo agregado' : 'Pago fijo actualizado');
  }

  Future<void> _borrar() async {
    if (!await confirmar(context, '¿Quitar ${widget.fijo!.nombre}?',
        'Ya no aparecerá en los pagos del mes. Los pagos hechos se conservan.')) {
      return;
    }
    await LocalDb.instance.deleteFijo(widget.fijo!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ej = fijosSugeridos(LocalDb.instance.tipoNegocio.value);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Text(widget.fijo == null ? 'Nuevo pago fijo' : 'Editar pago fijo',
                    style: t.headlineSmall),
              ),
              if (widget.fijo != null)
                IconButton(
                    tooltip: 'Quitar', onPressed: _borrar, icon: const Icon(Icons.delete_outline)),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nombre,
              autofocus: widget.fijo == null && widget.nombreInicial.isEmpty,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 80,
              decoration: InputDecoration(
                  labelText: '¿Qué pagas cada mes?',
                  hintText: 'Ej.: ${ej.length > 4 ? ej[4] : 'Arriendo del local'}',
                  counterText: ''),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe qué pagas' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _monto,
              autofocus: widget.nombreInicial.isNotEmpty,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Valor aproximado',
                  hintText: 'Ej.: 85.000',
                  helperText: 'Si cambia cada mes (como la luz), pon un promedio.',
                  prefixText: r'$ '),
              validator: (v) =>
                  (v ?? '').trim().isNotEmpty && parseMonto(v!) == null ? 'Revisa el valor' : null,
            ),
            const SizedBox(height: 12),
            Text('Día del mes en que se paga: $_dia', style: t.titleSmall),
            Slider(
              value: _dia.toDouble(),
              min: 1,
              max: 31,
              divisions: 30,
              label: '$_dia',
              onChanged: (v) => setState(() => _dia = v.round()),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.storefront_outlined),
              title: Text(_terceroNombre ?? '¿A quién se le paga? (opcional)'),
              subtitle: const Text('Arrendador, empresa de servicios, empleado…'),
              trailing: const Icon(Icons.expand_more),
              onTap: _elegirTercero,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _guardar, child: const Text('Guardar')),
          ]),
        ),
      ),
    );
  }
}
