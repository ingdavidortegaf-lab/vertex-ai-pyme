import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/local_db.dart';
import '../data/sync_service.dart';
import '../domain/formato.dart';
import '../domain/resumen.dart';
import 'comun.dart';
import 'pago_widget.dart';
import '../domain/pagos.dart';
import 'escaner.dart';
import 'herramientas_page.dart';
import '../domain/codigos.dart';
import 'ilustraciones.dart';
import 'inventario_page.dart';
import 'tema.dart';

/// Movimientos: ventas (de contado o fiadas), gastos y abonos, por día.
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

  static String _dia(DateTime d) {
    final hoy = DateTime.now();
    final h = DateTime(hoy.year, hoy.month, hoy.day);
    final x = DateTime(d.year, d.month, d.day);
    final dif = h.difference(x).inDays;
    if (dif == 0) return 'Hoy';
    if (dif == 1) return 'Ayer';
    final s = DateFormat("EEEE d 'de' MMMM", 'es_CO').format(d);
    return '${s[0].toUpperCase()}${s.substring(1)}';
  }

  /// Movimientos agrupados por día, con lo vendido ese día.
  List<(String, double, List<Map<String, Object?>>)> _dias() {
    final out = <(String, double, List<Map<String, Object?>>)>[];
    for (final v in _items) {
      final dia = _dia(DateTime.parse(v['fecha'] as String).toLocal());
      if (out.isEmpty || out.last.$1 != dia) out.add((dia, 0, []));
      final (d, vendido, lista) = out.removeLast();
      lista.add(v);
      final suma =
          v['tipo'] == 'ingreso' ? (v['monto'] as num).toDouble() : 0.0;
      out.add((d, vendido + suma, lista));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final hora = DateFormat('h:mm a', 'es_CO');
    final t = Theme.of(context).textTheme;
    final p = Paleta.of(context);
    final dias = _cargado
        ? _dias()
        : const <(String, double, List<Map<String, Object?>>)>[];
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => mostrarFormMovimiento(context),
        icon: const Icon(Icons.add),
        label: const Text('Registrar'),
      ),
      body: !_cargado
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const EstadoVacio(
                  ilustracion: IlustracionPizarra(),
                  titulo: 'Aún no hay movimientos',
                  texto: 'Toca «Registrar» para anotar una venta, un gasto o '
                      'un abono. Funciona aunque no haya señal.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                  itemCount: dias.length,
                  itemBuilder: (_, i) {
                    final (dia, vendido, lista) = dias[i];
                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
                            child: Row(children: [
                              Expanded(child: Text(dia, style: t.titleSmall)),
                              if (vendido > 0)
                                Text('Vendido ${cop(vendido)}',
                                    style: cifras(t.labelLarge
                                        ?.copyWith(color: p.ventas))),
                            ]),
                          ),
                          Card(
                            child: Column(children: [
                              for (final (j, v) in lista.indexed) ...[
                                if (j > 0) const Divider(indent: 72),
                                FilaMovimiento(v: v, fmt: hora),
                              ],
                            ]),
                          ),
                        ]);
                  },
                ),
    );
  }
}

/// Compatibilidad: fila de un movimiento.
Widget filaMovimiento(Map<String, Object?> v, DateFormat fmt,
        {bool mostrarCliente = true}) =>
    FilaMovimiento(v: v, fmt: fmt, mostrarCliente: mostrarCliente);

class FilaMovimiento extends StatelessWidget {
  final Map<String, Object?> v;
  final DateFormat fmt;
  final bool mostrarCliente;
  const FilaMovimiento(
      {super.key,
      required this.v,
      required this.fmt,
      this.mostrarCliente = true});

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    final t = Theme.of(context).textTheme;
    final tipo = v['tipo'] as String? ?? 'ingreso';
    final fiado = v['credito'] == 1;
    final (Color color, String etiqueta, String signo) = switch (tipo) {
      'egreso' => (p.gastos, 'Gasto', '−'),
      'abono' => (p.fiado, 'Abono', '+'),
      _ => fiado ? (p.fiado, 'Venta fiada', '+') : (p.ventas, 'Venta', '+'),
    };
    final cliente = v['cliente_nombre'] as String?;
    final fecha = fmt.format(DateTime.parse(v['fecha'] as String).toLocal());
    final pagos = leerPagos(v['pagos'],
        monto: (v['monto'] as num).toDouble(), tipo: tipo, credito: fiado);
    final partes = [
      if (etiqueta != v['concepto']) etiqueta,
      if (mostrarCliente && cliente != null) cliente,
      if (pagos.isNotEmpty) textoPagos(pagos, conValor: false),
      fecha,
    ];
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: IconoTipo(tipo: tipo, fiado: fiado),
      title: Text(v['concepto'] as String,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(partes.join(' · '),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$signo${cop((v['monto'] as num).toDouble())}',
            style: cifras(t.titleSmall?.copyWith(color: color))),
        const SizedBox(width: 6),
        iconoSync(v['sync']),
      ]),
      // Tocar una venta abre su comprobante para enviarlo por WhatsApp.
      onTap: tipo == 'ingreso'
          ? () => enviarComprobante(context, v['id'] as String)
          : null,
    );
  }
}

/// Registrar venta, venta fiada, gasto o abono (hoja inferior).
Future<void> mostrarFormMovimiento(BuildContext context,
    {String? clienteId, String tipoInicial = 'ingreso'}) async {
  final clientes = await LocalDb.instance.clientesConSaldo();
  final productos = await LocalDb.instance.productos();
  if (!context.mounted) return;
  final r = await showModalBottomSheet<_Movimiento>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FormMovimiento(
        clientes: clientes,
        productos: productos,
        clienteId: clienteId,
        tipoInicial: tipoInicial),
  );
  if (r == null) return;
  final String id;
  if (r.items.isNotEmpty) {
    id = await LocalDb.instance.saveVentaProductos(r.items,
        fiado: r.fiado, clienteId: r.clienteId, concepto: r.concepto, pagos: r.pagos);
  } else {
    var concepto = r.concepto.trim();
    if (concepto.isEmpty) concepto = r.tipo == 'abono' ? 'Abono' : 'Venta';
    id = await LocalDb.instance.saveMovimiento(concepto, r.monto,
        tipo: r.tipo, credito: r.fiado, clienteId: r.clienteId, pagos: r.pagos);
  }
  SyncService.instance.sync();
  if (r.tipo == 'ingreso') {
    // Ofrece enviar el comprobante por WhatsApp enseguida.
    avisarConAccion(r.fiado ? 'Venta fiada guardada' : 'Venta guardada',
        'Enviar comprobante', () {
      if (context.mounted) enviarComprobante(context, id);
    });
  } else {
    avisar(r.tipo == 'egreso' ? 'Gasto guardado' : 'Abono guardado');
  }
}

class _Movimiento {
  final String concepto;
  final double monto;
  final String tipo;
  final bool fiado;
  final String? clienteId;
  final List<ItemVenta> items;

  /// Cómo se pagó (vacío si es fiado).
  final List<Pago> pagos;
  const _Movimiento(
      this.concepto, this.monto, this.tipo, this.fiado, this.clienteId,
      [this.items = const [], this.pagos = const []]);
}

class _FormMovimiento extends StatefulWidget {
  final List<ClienteSaldo> clientes;
  final List<ProductoStock> productos;
  final String? clienteId;
  final String tipoInicial;
  const _FormMovimiento(
      {required this.clientes,
      this.productos = const [],
      this.clienteId,
      required this.tipoInicial});
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
  List<Pago> _pagos = const [];
  String? _errorPago;

  /// ¿Este movimiento lleva medio de pago? (todo menos la venta fiada)
  bool get _llevaPago => !(_tipo == 'ingreso' && _fiado);

  /// Productos de la venta: id -> cantidad (en el orden en que se agregaron).
  final _carrito = <String, double>{};

  ProductoStock? _producto(String id) {
    for (final p in widget.productos) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// ¿Se está vendiendo más de lo que hay? (los servicios no cuentan).
  bool _falta(ItemVenta i) {
    final p = _producto(i.productoId);
    return p != null && !p.esServicio && p.stock < i.cantidad;
  }

  List<ItemVenta> get _items => [
        for (final e in _carrito.entries)
          if (_producto(e.key) case final p?)
            ItemVenta(
                productoId: p.id,
                nombre: p.nombre,
                cantidad: e.value,
                precio: p.precio,
                costo: p.costo,
                unidad: p.unidad),
      ];

  double get _totalCarrito => _items.fold(0.0, (s, i) => s + i.total);

  /// Peso que marca la gramera, en la unidad del producto.
  Future<double?> _pedirPeso(ProductoStock p, {double? actual}) async {
    final ctrl = TextEditingController(
        text: actual == null ? '' : actual.toString().replaceAll('.', ','));
    final r = await showDialog<double>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(p.nombre),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
              labelText: 'Peso en ${p.unidad == 'kg' ? 'kilos' : 'libras'}',
              helperText: 'Lo que marca la gramera. Ej.: 0,750',
              suffixText: p.unidad),
          onSubmitted: (v) =>
              Navigator.pop(c, double.tryParse(v.replaceAll(',', '.'))),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(
                  c, double.tryParse(ctrl.text.trim().replaceAll(',', '.'))),
              child: const Text('Agregar')),
        ],
      ),
    );
    ctrl.dispose();
    return r == null || r <= 0 ? null : r;
  }

  Future<void> _sumar(ProductoStock p, {double? cantidad}) async {
    var c = cantidad;
    if (c == null && esPorPeso(p.unidad)) c = await _pedirPeso(p);
    if (c == null && esPorPeso(p.unidad)) return;
    setState(() => _carrito[p.id] = (_carrito[p.id] ?? 0) + (c ?? 1));
  }

  Future<void> _agregarProducto() async {
    final p = await showModalBottomSheet<ProductoStock>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ElegirProducto(productos: widget.productos),
    );
    if (p == null) return;
    await _sumar(p);
  }

  Future<void> _escanear() async {
    final c = await escanearCodigo(context);
    if (c == null || !mounted) return;
    final r = buscarPorCodigo(widget.productos, c);
    if (r == null) {
      avisar('No hay un producto con el código $c. Agrégalo en Inventario.');
      return;
    }
    await _sumar(r.producto, cantidad: r.cantidad);
  }

  void _cambiarCantidad(String id, double delta) => setState(() {
        final n = (_carrito[id] ?? 0) + delta;
        if (n <= 0) {
          _carrito.remove(id);
        } else {
          _carrito[id] = n;
        }
      });

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

  bool get _requiereCliente =>
      _tipo == 'abono' || (_tipo == 'ingreso' && _fiado);

  Future<void> _elegirCliente() async {
    final lista = _tipo == 'abono'
        ? widget.clientes.where((c) => c.saldo > 0).toList()
        : widget.clientes;
    final p = Paleta.of(context);
    final elegido = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.7),
        child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                    _tipo == 'abono' ? '¿Quién abona?' : 'Elegir cliente',
                    style: Theme.of(c).textTheme.titleLarge),
              ),
              if (lista.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_tipo == 'abono'
                      ? 'Ningún cliente tiene saldo pendiente.'
                      : 'Aún no hay clientes. Agrégalos en la pestaña Clientes.'),
                ),
              if (!_requiereCliente)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  leading: const Icon(Icons.person_off_outlined),
                  title: const Text('Sin cliente'),
                  onTap: () => Navigator.pop(c, ''),
                ),
              for (final cl in lista)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  leading: AvatarCliente(nombre: cl.nombre, clave: cl.nombre),
                  title: Text(cl.nombre),
                  trailing: cl.saldo > 0
                      ? Text('Debe ${cop(cl.saldo)}',
                          style: cifras(Theme.of(c)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: p.fiado)))
                      : null,
                  selected: cl.id == _clienteId,
                  onTap: () => Navigator.pop(c, cl.id),
                ),
            ]),
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
    final conProductos = _tipo == 'ingreso' && _carrito.isNotEmpty;
    final monto = conProductos ? _totalCarrito : parseMonto(_monto.text);
    if (_tipo == 'abono' &&
        cliente != null &&
        monto != null &&
        monto > cliente.saldo + 0.5) {
      errCliente = 'El abono supera lo que debe (${cop(cliente.saldo)})';
    }
    final pagos = _llevaPago ? normalizarPagos(_pagos) : const <Pago>[];
    final errPago = _llevaPago && monto != null && monto > 0
        ? problemaPagos(pagos, monto)
        : null;
    setState(() {
      _errorCliente = errCliente;
      _errorPago = errPago;
    });
    if (!okForm || errCliente != null || errPago != null || monto == null || monto <= 0) {
      return;
    }
    Navigator.pop(
        context,
        _Movimiento(
            _concepto.text.trim(),
            monto,
            _tipo,
            _tipo == 'ingreso' && _fiado,
            _tipo == 'egreso' ? null : _clienteId,
            conProductos ? _items : const [],
            pagos));
  }

  @override
  Widget build(BuildContext context) {
    final cliente = _cliente;
    final p = Paleta.of(context);
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final (Color tinta, Color fondo) = switch (_tipo) {
      'egreso' => (p.gastos, p.gastosFondo),
      'abono' => (p.fiado, p.fiadoFondo),
      _ => _fiado ? (p.fiado, p.fiadoFondo) : (p.ventas, p.ventasFondo),
    };
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Form(
          key: _form,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Registrar', style: t.headlineSmall),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              showSelectedIcon: false,
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith(
                    (s) => s.contains(WidgetState.selected) ? fondo : null),
                foregroundColor: WidgetStateProperty.resolveWith(
                    (s) => s.contains(WidgetState.selected) ? tinta : null),
              ),
              segments: const [
                ButtonSegment(
                    value: 'ingreso',
                    icon: Icon(Icons.south_west_rounded),
                    label: Text('Venta')),
                ButtonSegment(
                    value: 'egreso',
                    icon: Icon(Icons.north_east_rounded),
                    label: Text('Gasto')),
                ButtonSegment(
                    value: 'abono',
                    icon: Icon(Icons.payments_outlined),
                    label: Text('Abono')),
              ],
              selected: {_tipo},
              onSelectionChanged: (s) => setState(() {
                _tipo = s.first;
                _errorCliente = null;
                if (_tipo == 'abono' &&
                    (cliente == null || cliente.saldo <= 0)) {
                  _clienteId = null;
                }
              }),
            ),
            if (_tipo == 'ingreso' && widget.productos.isNotEmpty) ...[
              const SizedBox(height: 16),
              for (final i in _items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(i.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.titleSmall),
                            Text(
                                '${precioConUnidad(i.precio, i.unidad)}'
                                '${_falta(i) ? ' · solo hay ${cantidadConUnidad(_producto(i.productoId)?.stock ?? 0, i.unidad)}' : ''}',
                                style: t.bodySmall?.copyWith(
                                    color: _falta(i)
                                        ? p.gastos
                                        : esquema.onSurfaceVariant)),
                          ]),
                    ),
                    IconButton(
                      tooltip: 'Quitar',
                      onPressed: () => _cambiarCantidad(
                          i.productoId, esPorPeso(i.unidad) ? -0.25 : -1),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    InkWell(
                      onTap:
                          esPorPeso(i.unidad) && _producto(i.productoId) != null
                              ? () async {
                                  final v = await _pedirPeso(
                                      _producto(i.productoId)!,
                                      actual: i.cantidad);
                                  if (v != null) {
                                    setState(() => _carrito[i.productoId] = v);
                                  }
                                }
                              : null,
                      child: Text(cantidadConUnidad(i.cantidad, i.unidad),
                          style: cifras(esPorPeso(i.unidad)
                              ? t.titleSmall
                              : t.titleMedium)),
                    ),
                    IconButton(
                      tooltip: 'Agregar',
                      onPressed: () => _cambiarCantidad(
                          i.productoId, esPorPeso(i.unidad) ? 0.25 : 1),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    SizedBox(
                      width: 84,
                      child: Text(cop(i.total),
                          textAlign: TextAlign.right,
                          style: cifras(t.titleSmall?.copyWith(color: tinta))),
                    ),
                  ]),
                ),
              OutlinedButton.icon(
                onPressed: _agregarProducto,
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(_carrito.isEmpty
                    ? (LocalDb.instance.modo.value.vendeServicios
                        ? 'Elegir productos o servicios'
                        : 'Elegir productos del inventario')
                    : 'Agregar otro producto'),
              ),
              if (LocalDb.instance.modo.value.codigos) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _escanear,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Escanear código de barras'),
                ),
              ],
            ],
            if (_tipo == 'ingreso' && _carrito.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                    color: fondo, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Text('Total', style: t.titleMedium?.copyWith(color: tinta)),
                  const Spacer(),
                  Text(cop(_totalCarrito),
                      style: cifras(t.headlineMedium?.copyWith(color: tinta))),
                ]),
              ),
            ] else ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _monto,
                autofocus: _tipo != 'ingreso' || widget.productos.isEmpty,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: cifras(t.headlineMedium?.copyWith(color: tinta)),
                decoration: InputDecoration(
                  labelText: 'Monto en pesos',
                  hintText: '25.000',
                  prefixText: r'$ ',
                  prefixStyle: t.headlineMedium?.copyWith(color: tinta),
                ),
                validator: (v) => parseMonto(v ?? '') == null
                    ? 'Escribe un monto mayor a cero'
                    : null,
                onChanged: (_) => setState(() {}),
              ),
            ],
            if (_tipo == 'ingreso' &&
                (LocalDb.instance.modo.value.fia || _fiado)) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                value: _fiado,
                activeTrackColor: p.fiado,
                onChanged: (v) => setState(() => _fiado = v),
                title: const Text('Venta fiada'),
                subtitle: const Text('Queda por cobrar a un cliente'),
              ),
            ],
            if (_llevaPago) ...[
              const SizedBox(height: 12),
              SelectorPago(
                key: ValueKey('pago_$_tipo'),
                titulo: _tipo == 'egreso' ? '¿Con qué pagó el gasto?' : '¿Cómo pagó?',
                total: (_tipo == 'ingreso' && _carrito.isNotEmpty)
                    ? _totalCarrito
                    : (parseMonto(_monto.text) ?? 0),
                error: _errorPago,
                onChanged: (l) => _pagos = l,
              ),
            ],
            if (_tipo != 'egreso') ...[
              const SizedBox(height: 8),
              Material(
                color: esquema.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                      color: _errorCliente != null
                          ? esquema.error
                          : esquema.outlineVariant),
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  leading: cliente == null
                      ? const Icon(Icons.person_outline)
                      : AvatarCliente(
                          nombre: cliente.nombre,
                          clave: cliente.nombre,
                          tam: 36),
                  title: Text(cliente?.nombre ??
                      (_requiereCliente
                          ? 'Elegir cliente'
                          : 'Cliente (opcional)')),
                  subtitle: _errorCliente != null
                      ? Text(_errorCliente!,
                          style: TextStyle(color: esquema.error))
                      : (cliente != null && cliente.saldo > 0
                          ? Text('Debe ${cop(cliente.saldo)}')
                          : null),
                  trailing: const Icon(Icons.expand_more),
                  onTap: _elegirCliente,
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _concepto,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: _tipo == 'egreso'
                    ? 'En qué fue el gasto'
                    : 'Concepto (opcional)',
                counterText: '',
                hintText: switch (_tipo) {
                  'egreso' => 'Ej.: arriendo, mercancía',
                  'abono' => 'Abono',
                  _ => 'Ej.: 2 bultos de concentrado',
                },
              ),
              validator: (v) => _tipo == 'egreso' && (v ?? '').trim().isEmpty
                  ? 'Escribe en qué fue el gasto'
                  : null,
              onFieldSubmitted: (_) => _guardar(),
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: tinta,
                foregroundColor:
                    Theme.of(context).brightness == Brightness.light
                        ? Colors.white
                        : const Color(0xFF0B2018),
              ),
              onPressed: _guardar,
              child: Text(switch (_tipo) {
                'egreso' => 'Guardar gasto',
                'abono' => 'Guardar abono',
                _ => _fiado ? 'Guardar venta fiada' : 'Guardar venta',
              }),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Lista de productos para agregar a una venta (con buscador).
class ElegirProducto extends StatefulWidget {
  final List<ProductoStock> productos;
  const ElegirProducto({super.key, required this.productos});
  @override
  State<ElegirProducto> createState() => _ElegirProductoState();
}

class _ElegirProductoState extends State<ElegirProducto> {
  String _f = '';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final f = _f.trim().toLowerCase();
    final lista = widget.productos
        .where((x) =>
            f.isEmpty ||
            x.nombre.toLowerCase().contains(f) ||
            x.codigo.contains(f.trim()))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Elegir producto', style: t.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) => setState(() => _f = v),
                    decoration: const InputDecoration(
                        hintText: 'Buscar producto',
                        prefixIcon: Icon(Icons.search)),
                  ),
                ]),
          ),
          Flexible(
            child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  if (lista.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Ningún producto coincide.',
                          textAlign: TextAlign.center),
                    ),
                  for (final x in lista)
                    ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      title: Text(x.nombre,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(cop(x.precio)),
                      trailing: EtiquetaStock(x: x),
                      onTap: () => Navigator.pop(context, x),
                    ),
                ]),
          ),
        ]),
      ),
    );
  }
}
