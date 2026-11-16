import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/local_db.dart';
import '../data/sync_service.dart';
import '../domain/formato.dart';
import '../domain/resumen.dart';
import 'comun.dart';

/// Movimientos: ventas (de contado o fiadas), gastos y abonos.
class VentasPage extends StatefulWidget {
  const VentasPage({super.key});
  @override
  State<VentasPage> createState() => _VentasPageState();
}

class _VentasPageState extends State<VentasPage> {
  List<Map<String, Object?>> _items = [];
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
    final r = await LocalDb.instance.movimientos();
    if (mounted) {
      setState(() {
        _items = r;
        _cargado = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM y, h:mm a', 'es_CO');
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => mostrarFormMovimiento(context),
        icon: const Icon(Icons.add),
        label: const Text('Registrar'),
      ),
      body: !_cargado
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(
                  child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                      'Aún no hay movimientos. Toca «Registrar» para anotar una '
                      'venta, un gasto o un abono.',
                      textAlign: TextAlign.center),
                ))
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => filaMovimiento(_items[i], fmt),
                ),
    );
  }
}

Widget filaMovimiento(Map<String, Object?> v, DateFormat fmt,
    {bool mostrarCliente = true}) {
  final tipo = v['tipo'];
  final fiado = v['credito'] == 1;
  final (IconData icono, Color color, String etiqueta) = switch (tipo) {
    'egreso' => (Icons.arrow_upward, Colors.red, 'Gasto'),
    'abono' => (Icons.payments_outlined, Colors.teal, 'Abono'),
    _ => (Icons.arrow_downward, Colors.green, fiado ? 'Venta fiada' : 'Venta'),
  };
  final cliente = v['cliente_nombre'] as String?;
  final fecha = fmt.format(DateTime.parse(v['fecha'] as String).toLocal());
  final partes = [
    etiqueta,
    if (mostrarCliente && cliente != null) cliente,
    fecha,
  ];
  return ListTile(
    leading: Icon(icono, color: color),
    title: Text(v['concepto'] as String),
    subtitle: Text(partes.join(' · ')),
    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(cop((v['monto'] as num).toDouble()),
          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      const SizedBox(width: 6),
      iconoSync(v['sync']),
    ]),
  );
}

/// Registrar venta, venta fiada, gasto o abono.
Future<void> mostrarFormMovimiento(BuildContext context,
    {String? clienteId, String tipoInicial = 'ingreso'}) async {
  final clientes = await LocalDb.instance.clientesConSaldo();
  if (!context.mounted) return;
  final r = await showDialog<_Movimiento>(
    context: context,
    builder: (_) => _FormMovimiento(
        clientes: clientes, clienteId: clienteId, tipoInicial: tipoInicial),
  );
  if (r == null) return;
  await LocalDb.instance.saveMovimiento(r.concepto, r.monto,
      tipo: r.tipo, credito: r.fiado, clienteId: r.clienteId);
  SyncService.instance.sync();
  avisar(switch (r.tipo) {
    'egreso' => 'Gasto guardado',
    'abono' => 'Abono guardado',
    _ => r.fiado ? 'Venta fiada guardada' : 'Venta guardada',
  });
}

class _Movimiento {
  final String concepto;
  final double monto;
  final String tipo;
  final bool fiado;
  final String? clienteId;
  const _Movimiento(this.concepto, this.monto, this.tipo, this.fiado, this.clienteId);
}

class _FormMovimiento extends StatefulWidget {
  final List<ClienteSaldo> clientes;
  final String? clienteId;
  final String tipoInicial;
  const _FormMovimiento(
      {required this.clientes, this.clienteId, required this.tipoInicial});
  @override
  State<_FormMovimiento> createState() => _FormMovimientoState();
}

class _FormMovimientoState extends State<_FormMovimiento> {
  final _form = GlobalKey<FormState>();
  final _concepto = TextEditingController();
  final _monto = TextEditingController();
  late String _tipo = widget.tipoInicial;
  bool _fiado = false;
  late String? _clienteId = widget.clienteId;
  String? _errorCliente;

  @override
  void dispose() {
    _concepto.dispose();
    _monto.dispose();
    super.dispose();
  }

  ClienteSaldo? get _cliente {
    for (final c in widget.clientes) {
      if (c.id == _clienteId) return c;
    }
    return null;
  }

  bool get _requiereCliente => _tipo == 'abono' || (_tipo == 'ingreso' && _fiado);

  Future<void> _elegirCliente() async {
    final lista = _tipo == 'abono'
        ? widget.clientes.where((c) => c.saldo > 0).toList()
        : widget.clientes;
    final elegido = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Elegir cliente'),
        children: [
          if (lista.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_tipo == 'abono'
                  ? 'Ningún cliente tiene saldo pendiente.'
                  : 'Aún no hay clientes. Agrégalos en la pestaña Clientes.'),
            ),
          if (!_requiereCliente)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, ''),
              child: const Text('Sin cliente'),
            ),
          for (final cl in lista)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, cl.id),
              child: Text(cl.saldo > 0
                  ? '${cl.nombre} (debe ${cop(cl.saldo)})'
                  : cl.nombre),
            ),
        ],
      ),
    );
    if (elegido == null) return;
    setState(() {
      _clienteId = elegido.isEmpty ? null : elegido;
      _errorCliente = null;
    });
  }

  void _guardar() {
    final okForm = _form.currentState!.validate();
    final cliente = _cliente;
    String? errCliente;
    if (_requiereCliente && cliente == null) {
      errCliente = _tipo == 'abono'
          ? 'Elige el cliente que abona'
          : 'Para fiar, elige el cliente';
    }
    final monto = parseMonto(_monto.text);
    if (_tipo == 'abono' && cliente != null && monto != null &&
        monto > cliente.saldo + 0.5) {
      errCliente = 'El abono supera lo que debe (${cop(cliente.saldo)})';
    }
    setState(() => _errorCliente = errCliente);
    if (!okForm || errCliente != null || monto == null) return;
    var concepto = _concepto.text.trim();
    if (concepto.isEmpty) concepto = _tipo == 'abono' ? 'Abono' : 'Venta';
    Navigator.pop(
        context,
        _Movimiento(concepto, monto, _tipo, _tipo == 'ingreso' && _fiado,
            _tipo == 'egreso' ? null : _clienteId));
  }

  @override
  Widget build(BuildContext context) {
    final cliente = _cliente;
    return AlertDialog(
      title: const Text('Registrar movimiento'),
      scrollable: true,
      content: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'ingreso', label: Text('Venta')),
              ButtonSegment(value: 'egreso', label: Text('Gasto')),
              ButtonSegment(value: 'abono', label: Text('Abono')),
            ],
            selected: {_tipo},
            onSelectionChanged: (s) => setState(() {
              _tipo = s.first;
              _errorCliente = null;
              if (_tipo == 'abono' && (cliente == null || cliente.saldo <= 0)) {
                _clienteId = null;
              }
            }),
          ),
          if (_tipo == 'ingreso')
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _fiado,
              onChanged: (v) => setState(() => _fiado = v),
              title: const Text('Fiado (queda por cobrar)'),
            ),
          TextFormField(
            controller: _concepto,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 80,
            decoration: InputDecoration(
              labelText: _tipo == 'egreso' ? 'Concepto *' : 'Concepto',
              hintText: switch (_tipo) {
                'egreso' => 'Ej.: arriendo, mercancía',
                'abono' => 'Abono',
                _ => 'Ej.: 2 bultos de concentrado',
              },
            ),
            validator: (v) => _tipo == 'egreso' && (v ?? '').trim().isEmpty
                ? 'Escribe en qué fue el gasto'
                : null,
          ),
          TextFormField(
            controller: _monto,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Monto (COP) *', hintText: '25.000'),
            validator: (v) =>
                parseMonto(v ?? '') == null ? 'Escribe un monto mayor a cero' : null,
          ),
          if (_tipo != 'egreso') ...[
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text(cliente?.nombre ??
                  (_requiereCliente ? 'Elegir cliente *' : 'Sin cliente (opcional)')),
              subtitle: _errorCliente != null
                  ? Text(_errorCliente!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error))
                  : (cliente != null && cliente.saldo > 0
                      ? Text('Debe ${cop(cliente.saldo)}')
                      : null),
              trailing: const Icon(Icons.arrow_drop_down),
              onTap: _elegirCliente,
            ),
          ],
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
