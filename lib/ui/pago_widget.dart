import 'package:flutter/material.dart';
import '../data/local_db.dart';
import '../domain/formato.dart';
import '../domain/pagos.dart';
import 'comun.dart';
import 'tema.dart';

const iconosMedio = {
  'efectivo': Icons.payments_outlined,
  'nequi': Icons.phone_android,
  'daviplata': Icons.phone_iphone,
  'bancolombia': Icons.account_balance_outlined,
  'transferencia': Icons.swap_horiz,
  'tarjeta_debito': Icons.credit_card,
  'tarjeta_credito': Icons.credit_score_outlined,
};

/// «¿Cómo pagó?»: un medio con un toque, o el pago dividido (por ejemplo,
/// una parte por Nequi y otra en efectivo). Avisa cada cambio con la lista
/// de pagos; la validación final la hace [problemaPagos].
class SelectorPago extends StatefulWidget {
  final double total;
  final ValueChanged<List<Pago>> onChanged;
  final String titulo;
  final String? error;
  const SelectorPago(
      {super.key,
      required this.total,
      required this.onChanged,
      this.titulo = '¿Cómo pagó?',
      this.error});
  @override
  State<SelectorPago> createState() => _SelectorPagoState();
}

class _Fila {
  String medio;
  final TextEditingController monto;
  _Fila(this.medio, String texto) : monto = TextEditingController(text: texto);
}

class _SelectorPagoState extends State<SelectorPago> {
  String _medio = 'efectivo';
  bool _dividido = false;
  final _filas = <_Fila>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _avisar());
  }

  @override
  void didUpdateWidget(SelectorPago old) {
    super.didUpdateWidget(old);
    if (old.total != widget.total && !_dividido) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _avisar());
    }
  }

  @override
  void dispose() {
    for (final f in _filas) {
      f.monto.dispose();
    }
    super.dispose();
  }

  List<Pago> get _pagos => _dividido
      ? [
          for (final f in _filas)
            if ((parseMonto(f.monto.text) ?? 0) > 0) Pago(f.medio, parseMonto(f.monto.text)!)
        ]
      : (widget.total > 0 ? [Pago(_medio, widget.total)] : const []);

  void _avisar() {
    if (mounted) widget.onChanged(_pagos);
  }

  void _dividir(bool si) {
    setState(() {
      _dividido = si;
      if (si && _filas.isEmpty) {
        final otro = _medio == 'efectivo' ? 'nequi' : 'efectivo';
        _filas.add(_Fila(_medio, ''));
        _filas.add(_Fila(otro, ''));
      }
    });
    _avisar();
  }

  double get _restante =>
      widget.total - _pagos.fold(0.0, (s, p) => s + p.monto);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final pal = Paleta.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text(widget.titulo, style: t.titleSmall)),
        TextButton.icon(
          onPressed: () => _dividir(!_dividido),
          icon: Icon(_dividido ? Icons.close : Icons.call_split, size: 18),
          label: Text(_dividido ? 'Un solo medio' : 'Dividir el pago'),
        ),
      ]),
      const SizedBox(height: 4),
      if (!_dividido)
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in mediosPago)
            ChoiceChip(
              avatar: Icon(iconosMedio[m], size: 18),
              label: Text(nombresMedio[m]!),
              selected: _medio == m,
              onSelected: (_) {
                setState(() => _medio = m);
                _avisar();
              },
            ),
        ])
      else ...[
        for (final (i, f) in _filas.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(
                flex: 5,
                child: DropdownButtonFormField<String>(
                  initialValue: f.medio,
                  isExpanded: true,
                  decoration: const InputDecoration(isDense: true, labelText: 'Medio'),
                  items: [
                    for (final m in mediosPago)
                      DropdownMenuItem(
                          value: m,
                          child: Row(children: [
                            Icon(iconosMedio[m], size: 18),
                            const SizedBox(width: 6),
                            Flexible(child: Text(nombresMedio[m]!, overflow: TextOverflow.ellipsis)),
                          ])),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => f.medio = v);
                    _avisar();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: TextField(
                  controller: f.monto,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'Valor',
                    prefixText: r'$ ',
                    suffixIcon: _restante > 0.5
                        ? IconButton(
                            tooltip: 'Poner lo que falta',
                            icon: const Icon(Icons.auto_fix_high, size: 18),
                            onPressed: () {
                              final actual = parseMonto(f.monto.text) ?? 0;
                              f.monto.text = (actual + _restante).toStringAsFixed(0);
                              setState(() {});
                              _avisar();
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) {
                    setState(() {});
                    _avisar();
                  },
                ),
              ),
              if (_filas.length > 2)
                IconButton(
                  tooltip: 'Quitar',
                  onPressed: () {
                    setState(() => _filas.removeAt(i).monto.dispose());
                    _avisar();
                  },
                  icon: const Icon(Icons.remove_circle_outline),
                ),
            ]),
          ),
        Row(children: [
          if (_filas.length < mediosPago.length)
            TextButton.icon(
              onPressed: () {
                setState(() => _filas.add(_Fila(
                    mediosPago.firstWhere((m) => !_filas.any((f) => f.medio == m),
                        orElse: () => 'efectivo'),
                    '')));
                _avisar();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Otro medio'),
            ),
          const Spacer(),
          Text(
            _restante.abs() <= 0.5
                ? 'Completo'
                : _restante > 0
                    ? 'Faltan ${cop(_restante)}'
                    : 'Sobran ${cop(-_restante)}',
            style: t.labelLarge?.copyWith(
                color: _restante.abs() <= 0.5 ? pal.ventas : esquema.error,
                fontWeight: FontWeight.w700),
          ),
        ]),
      ],
      if (widget.error != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(widget.error!, style: t.bodySmall?.copyWith(color: esquema.error)),
        ),
    ]);
  }
}

/// Pregunta cómo se pagó un valor ya conocido (vender una cotización,
/// pagar un pedido). Devuelve null si se cancela.
Future<List<Pago>?> pedirPagos(BuildContext context, double total,
    {String titulo = '¿Cómo pagó?'}) {
  var pagos = <Pago>[Pago('efectivo', total)];
  String? error;
  return showModalBottomSheet<List<Pago>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(c).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Total ${cop(total)}', style: cifras(Theme.of(c).textTheme.headlineSmall)),
          const SizedBox(height: 12),
          SelectorPago(total: total, titulo: titulo, error: error, onChanged: (l) => pagos = l),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final l = normalizarPagos(pagos);
              final e = problemaPagos(l, total);
              if (e != null) {
                set(() => error = e);
                return;
              }
              Navigator.pop(c, l);
            },
            child: const Text('Guardar'),
          ),
        ]),
      ),
    ),
  );
}

/// Formulario de las cuentas del negocio para recibir transferencias.
Future<void> mostrarDatosPago(BuildContext context) async {
  final db = LocalDb.instance;
  final d = await db.datosPago();
  if (!context.mounted) return;
  final nequi = TextEditingController(text: d.nequi);
  final davi = TextEditingController(text: d.daviplata);
  final banco = TextEditingController(text: d.bancolombia);
  final llave = TextEditingController(text: d.llave);
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(c).bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Datos para recibir pagos', style: Theme.of(c).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('Salen en la cuenta de cobro y en las cotizaciones para que el cliente te pague por transferencia. Todo es opcional.',
              style: Theme.of(c).textTheme.bodySmall),
          const SizedBox(height: 14),
          TextField(controller: nequi, keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Nequi (celular)', prefixIcon: Icon(Icons.phone_android))),
          const SizedBox(height: 10),
          TextField(controller: davi, keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Daviplata (celular)', prefixIcon: Icon(Icons.phone_iphone))),
          const SizedBox(height: 10),
          TextField(controller: banco,
              decoration: const InputDecoration(labelText: 'Bancolombia: tipo y número de cuenta',
                  hintText: 'Ahorros 123-456789-01', prefixIcon: Icon(Icons.account_balance_outlined))),
          const SizedBox(height: 10),
          TextField(controller: llave,
              decoration: const InputDecoration(labelText: 'Llave Bre-B (opcional)',
                  hintText: 'Celular, cédula, correo o @alias', prefixIcon: Icon(Icons.key_outlined))),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Guardar')),
        ]),
      ),
    ),
  );
  final datos = DatosPago(nequi: nequi.text, daviplata: davi.text, bancolombia: banco.text, llave: llave.text);
  for (final x in [nequi, davi, banco, llave]) {
    x.dispose();
  }
  if (ok != true) return;
  for (final cel in [datos.nequi, datos.daviplata]) {
    if (cel.trim().isNotEmpty && normalizarTelefono(cel) == null) {
      avisar('Nequi y Daviplata: celular de 10 dígitos que empiece por 3');
      return;
    }
  }
  await db.guardarDatosPago(DatosPago(
    nequi: normalizarTelefono(datos.nequi) ?? '',
    daviplata: normalizarTelefono(datos.daviplata) ?? '',
    bancolombia: datos.bancolombia,
    llave: datos.llave,
  ));
  avisar('Datos de pago guardados');
}
