import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/local_db.dart';
import '../data/sync_service.dart';
import '../domain/caja.dart';
import '../domain/codigos.dart';
import '../domain/formato.dart';
import '../domain/pagos.dart';
import '../domain/resumen.dart';
import '../domain/roles.dart';
import 'comun.dart';
import 'escaner.dart';
import 'escritorio.dart';
import 'herramientas_page.dart' show enviarComprobante;
import 'inventario_page.dart' show cantidadTexto;
import 'tema.dart';

/// Caja rápida (punto de venta). Pensada para el mostrador de un
/// supermercado, una ferretería o una tienda:
///
/// - El lector de código de barras USB escribe el código y da Enter: el
///   producto entra al carrito. También las etiquetas de la gramera.
/// - «3*» antes del código o del nombre suma 3 unidades de una vez.
/// - Teclas: F2 buscar, F4 cobrar, F6 fiar, Supr quita el último, Esc limpia.
/// - Con efectivo calcula el cambio; también Nequi, tarjeta y los demás.
///
/// Funciona sin internet: la venta queda en el celular o el PC y se sube al
/// sincronizar.
class PuntoVentaPage extends StatefulWidget {
  /// true cuando va dentro del menú lateral (sin barra propia).
  final bool comoSeccion;
  const PuntoVentaPage({super.key, this.comoSeccion = false});

  @override
  State<PuntoVentaPage> createState() => _PuntoVentaPageState();
}

class _Linea {
  final ProductoStock p;
  double cantidad;
  _Linea(this.p, this.cantidad);

  /// Desde la cantidad de por mayor aplica ese precio.
  double get precio => p.precioPara(cantidad);
  bool get porMayor => p.tienePrecioMayor && cantidad >= p.cantidadMayor;
  double get total => cantidad * precio;
}

/// Billetes colombianos para cobrar rápido en efectivo.
const _billetes = [2000.0, 5000.0, 10000.0, 20000.0, 50000.0, 100000.0];

class _PuntoVentaPageState extends State<PuntoVentaPage> {
  final db = LocalDb.instance;
  final _buscar = TextEditingController();
  final _focoBuscar = FocusNode();
  final _recibido = TextEditingController();
  final _descuento = TextEditingController();
  List<ProductoStock> _productos = const [];
  final List<_Linea> _carrito = [];
  String _medio = 'efectivo';
  bool _guardando = false;
  String? _error;

  /// Lo último que se vendió, para mostrar el cambio y el comprobante.
  ({String id, double total, double cambio})? _ultima;

  @override
  void initState() {
    super.initState();
    db.cambios.addListener(_cargar);
    _buscar.addListener(() => setState(() {}));
    _cargar();
  }

  @override
  void dispose() {
    db.cambios.removeListener(_cargar);
    _buscar.dispose();
    _focoBuscar.dispose();
    _recibido.dispose();
    _descuento.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final l = await db.productos();
    if (!mounted) return;
    setState(() {
      _productos = l;
      // El precio o el stock pudieron cambiar: el carrito toma los nuevos.
      for (final c in _carrito) {
        final n = l.where((p) => p.id == c.p.id).firstOrNull;
        if (n != null) {
          final i = _carrito.indexOf(c);
          _carrito[i] = _Linea(n, c.cantidad);
        }
      }
    });
  }

  // ---------------------------------------------------------------- cálculos

  double get _bruto => _carrito.fold(0.0, (s, l) => s + l.total);
  double get _valorDescuento => parseMonto(_descuento.text) ?? 0;
  double get _total => (_bruto - _valorDescuento).clamp(0, double.infinity);
  bool get _libre => libreDeTope(db.equipo.value, db.perfilActivo.value?.rol);
  bool get _puedeDescontar =>
      db.puede(Permiso.aplicarDescuento) &&
      (_libre || db.equipo.value.descuentoMaxPct > 0);

  double? get _cambio {
    if (_medio != 'efectivo') return null;
    final r = parseMonto(_recibido.text);
    if (r == null) return null;
    return r - _total;
  }

  /// «3*algo» → (3, «algo»).
  (double, String) _separarCantidad(String texto) {
    final m =
        RegExp(r'^\s*(\d+(?:[.,]\d+)?)\s*[*xX]\s*(.+)$').firstMatch(texto);
    if (m == null) return (1, texto.trim());
    return (
      double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 1,
      m.group(2)!.trim()
    );
  }

  List<ProductoStock> get _resultados {
    final (_, q) = _separarCantidad(_buscar.text);
    final b = q.toLowerCase();
    if (b.isEmpty) return _productos;
    return [
      for (final p in _productos)
        if (p.nombre.toLowerCase().contains(b) ||
            (p.codigo.isNotEmpty && p.codigo.contains(b)))
          p
    ];
  }

  // ---------------------------------------------------------------- acciones

  Future<void> _agregar(ProductoStock p, {double? cantidad}) async {
    var c = cantidad;
    if (c == null && esFraccionable(p.unidad)) {
      c = await _pedirCantidad(p);
      if (c == null) return;
    }
    c ??= 1;
    setState(() {
      _ultima = null;
      _error = null;
      final l = _carrito.where((l) => l.p.id == p.id).firstOrNull;
      if (l != null) {
        l.cantidad += c!;
        // Lo último tocado queda arriba, a la vista.
        _carrito
          ..remove(l)
          ..insert(0, l);
      } else {
        _carrito.insert(0, _Linea(p, c!));
      }
      _buscar.clear();
    });
    if (p.agotado) {
      avisar('${p.nombre}: el inventario dice que no hay. Revisa el stock.');
    }
    _focoBuscar.requestFocus();
  }

  /// Enter en el buscador: primero el código exacto (lector o gramera),
  /// luego si hay un solo resultado por nombre.
  Future<void> _enter() async {
    final (n, q) = _separarCantidad(_buscar.text);
    if (q.isEmpty) {
      if (_carrito.isNotEmpty) await _cobrar();
      return;
    }
    final r = buscarPorCodigo(_productos, q);
    if (r != null) {
      // Por metro, litro o kilo sin etiqueta de gramera: pregunta cuánto.
      await _agregar(r.producto,
          cantidad: r.cantidad ??
              (n == 1 && esFraccionable(r.producto.unidad) ? null : n));
      return;
    }
    final l = _resultados;
    if (l.length == 1) {
      await _agregar(l.single,
          cantidad: n == 1 && esFraccionable(l.single.unidad) ? null : n);
      return;
    }
    if (l.isEmpty) {
      avisar(RegExp(r'^\d{4,}$').hasMatch(q)
          ? 'No hay un producto con el código $q. Agrégalo en el inventario.'
          : 'No encontré «$q».');
    }
    _focoBuscar.requestFocus();
  }

  Future<void> _escanear() async {
    final c = await escanearCodigo(context);
    if (c == null || !mounted) return;
    final r = buscarPorCodigo(_productos, c);
    if (r == null) {
      avisar('No hay un producto con el código $c. Agrégalo en el inventario.');
      return;
    }
    await _agregar(r.producto, cantidad: r.cantidad);
  }

  Future<double?> _pedirCantidad(ProductoStock p, {double? actual}) =>
      dialogoConTexto<double>(
        context,
        texto: actual == null ? '' : cantidadTexto(actual),
        builder: (c, ctrl) {
          void listo() {
            final x = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
            if (x != null && x > 0) Navigator.pop(c, x);
          }

          return AlertDialog(
            title: Text(p.nombre),
            content: TextField(
              key: const ValueKey('pv_cantidad'),
              controller: ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: esPorPeso(p.unidad) ? 'Peso' : 'Cantidad',
                suffixText: esFraccionable(p.unidad) ? p.unidad : null,
                helperText: precioConUnidad(p.precio, p.unidad),
              ),
              onSubmitted: (_) => listo(),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('Cancelar')),
              FilledButton(onPressed: listo, child: const Text('Listo')),
            ],
          );
        },
      );

  Future<void> _editarCantidad(_Linea l) async {
    final c = await _pedirCantidad(l.p, actual: l.cantidad);
    if (c != null) setState(() => l.cantidad = c);
    _focoBuscar.requestFocus();
  }

  void _quitarUltimo() {
    if (_carrito.isEmpty) return;
    setState(() => _carrito.removeAt(0));
  }

  Future<void> _vaciar() async {
    if (_buscar.text.isNotEmpty) {
      _buscar.clear();
      return;
    }
    if (_carrito.isEmpty) return;
    if (await confirmar(context, '¿Vaciar el carrito?',
        'Se quitan todos los productos de esta venta.',
        si: 'Vaciar')) {
      setState(_limpiar);
    }
    _focoBuscar.requestFocus();
  }

  void _limpiar() {
    _carrito.clear();
    _recibido.clear();
    _descuento.clear();
    _medio = 'efectivo';
    _error = null;
  }

  String? _validar() {
    if (_carrito.isEmpty) return 'Agrega al menos un producto';
    final d = _valorDescuento;
    if (d > 0) {
      final e = problemaDescuento(d, _bruto,
          topePct: db.equipo.value.descuentoMaxPct, libre: _libre);
      if (e != null) return e;
    }
    final cambio = _cambio;
    if (cambio != null && cambio < -0.5) {
      return 'Falta dinero: recibiste menos del total';
    }
    return null;
  }

  List<ItemVenta> get _items => [
        for (final l in _carrito.reversed)
          ItemVenta(
              productoId: l.p.id,
              nombre: l.p.nombre,
              cantidad: l.cantidad,
              precio: l.precio,
              costo: l.p.costo,
              unidad: l.p.unidad),
      ];

  Future<void> _cobrar() async {
    if (_guardando) return;
    final e = _validar();
    if (e != null) {
      setState(() => _error = e);
      return;
    }
    setState(() => _guardando = true);
    try {
      final total = _total;
      final id = await db.saveVentaProductos(_items,
          pagos: [Pago(_medio, total)], descuento: _valorDescuento);
      final cambio = (_cambio ?? 0).clamp(0, double.infinity).toDouble();
      SyncService.instance.sync();
      setState(() {
        _ultima = (id: id, total: total, cambio: cambio);
        _limpiar();
      });
    } on ArgumentError catch (_) {
      setState(() => _error = 'Revisa los datos de la venta');
    } finally {
      if (mounted) setState(() => _guardando = false);
      _focoBuscar.requestFocus();
    }
  }

  Future<void> _fiar() async {
    if (!db.puede(Permiso.venderFiado)) return;
    final e = _validar();
    if (e != null && _carrito.isEmpty) {
      setState(() => _error = e);
      return;
    }
    final clientes = await db.clientesConSaldo();
    if (!mounted) return;
    final cliente = await showDialog<ClienteSaldo>(
      context: context,
      builder: (c) => _ElegirCliente(clientes: clientes),
    );
    if (cliente == null) return;
    setState(() => _guardando = true);
    try {
      final total = _total;
      final id = await db.saveVentaProductos(_items,
          fiado: true, clienteId: cliente.id, descuento: _valorDescuento);
      SyncService.instance.sync();
      setState(() {
        _ultima = (id: id, total: total, cambio: 0);
        _limpiar();
      });
      avisar('Venta fiada a ${cliente.nombre}');
    } finally {
      if (mounted) setState(() => _guardando = false);
      _focoBuscar.requestFocus();
    }
  }

  // ---------------------------------------------------------------- pantalla

  @override
  Widget build(BuildContext context) {
    final atajos = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.f2): () =>
          _focoBuscar.requestFocus(),
      const SingleActivator(LogicalKeyboardKey.f4): _cobrar,
      const SingleActivator(LogicalKeyboardKey.f6): _fiar,
      const SingleActivator(LogicalKeyboardKey.escape): _vaciar,
      const SingleActivator(LogicalKeyboardKey.delete): _quitarUltimo,
    };
    final cuerpo = LayoutBuilder(builder: (context, box) {
      final ancho = box.maxWidth >= 820;
      return ancho ? _vistaAncha(box.maxWidth) : _vistaAngosta();
    });
    final contenido = CallbackShortcuts(
      bindings: atajos,
      child: FocusScope(autofocus: true, child: cuerpo),
    );
    if (widget.comoSeccion) return contenido;
    return Scaffold(
        appBar: AppBar(title: const Text('Caja rápida')), body: contenido);
  }

  Widget _vistaAncha(double ancho) {
    final panel = ancho >= 1250 ? 440.0 : 380.0;
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: _campoBuscar()),
          Expanded(child: _grilla()),
          _ayudaTeclas(),
        ]),
      ),
      SizedBox(
        width: panel,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 16, 16),
          child: Card(margin: EdgeInsets.zero, child: _panelCarrito()),
        ),
      ),
    ]);
  }

  Widget _vistaAngosta() {
    final buscando = _buscar.text.trim().isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: _campoBuscar()),
      Expanded(child: buscando || _carrito.isEmpty ? _lista() : _lineas()),
      Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        shape: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: _cobro(compacto: true),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _campoBuscar() => TextField(
        key: const ValueKey('pv_buscar'),
        controller: _buscar,
        focusNode: _focoBuscar,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _enter(),
        decoration: InputDecoration(
          hintText: 'Código de barras o nombre del producto',
          prefixIcon: const Icon(Icons.qr_code_scanner),
          suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
            if (_buscar.text.isNotEmpty)
              IconButton(
                  tooltip: 'Borrar',
                  onPressed: _buscar.clear,
                  icon: const Icon(Icons.close)),
            if (!esEscritorio(context))
              IconButton(
                  tooltip: 'Escanear con la cámara',
                  onPressed: _escanear,
                  icon: const Icon(Icons.photo_camera_outlined)),
          ]),
        ),
      );

  Widget _grilla() {
    final l = _resultados;
    if (_productos.isEmpty) {
      return const _Vacio('Aún no hay productos',
          'Agrégalos en el inventario para venderlos aquí.');
    }
    if (l.isEmpty) {
      return const _Vacio(
          'Sin resultados', 'Prueba con otra palabra o con el código.');
    }
    return LayoutBuilder(builder: (context, box) {
      final cols = columnasPara(box.maxWidth - 32, minimo: 190, max: 6);
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 12, 16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 132,
        ),
        itemCount: l.length,
        itemBuilder: (_, i) =>
            _TarjetaProducto(p: l[i], onTap: () => _agregar(l[i])),
      );
    });
  }

  Widget _lista() {
    final l = _resultados;
    if (_productos.isEmpty) {
      return const _Vacio('Aún no hay productos',
          'Agrégalos en el inventario para venderlos aquí.');
    }
    if (l.isEmpty) {
      return const _Vacio(
          'Sin resultados', 'Prueba con otra palabra o con el código.');
    }
    final t = Theme.of(context).textTheme;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: l.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final p = l[i];
        return ListTile(
          key: ValueKey('pv_prod_${p.nombre}'),
          title: Text(p.nombre),
          subtitle: Text(_stockTexto(p)),
          trailing: Text(precioConUnidad(p.precio, p.unidad),
              style: cifras(t.titleSmall)),
          onTap: () => _agregar(p),
        );
      },
    );
  }

  Widget _panelCarrito() {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
        child: Row(children: [
          Expanded(child: Text('Venta actual', style: t.titleMedium)),
          if (_carrito.isNotEmpty)
            TextButton.icon(
                onPressed: _vaciar,
                icon: const Icon(Icons.remove_shopping_cart_outlined, size: 18),
                label: const Text('Vaciar')),
        ]),
      ),
      Expanded(child: _lineas()),
      const Divider(height: 1),
      LayoutBuilder(builder: (context, _) {
        final alto = MediaQuery.sizeOf(context).height;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: alto * 0.62),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: _cobro(),
          ),
        );
      }),
    ]);
  }

  Widget _lineas() {
    final t = Theme.of(context).textTheme;
    final ultima = _ultima;
    if (_carrito.isEmpty) {
      if (ultima != null) {
        return _VentaLista(ultima: ultima, alComprobante: _comprobante);
      }
      return const _Vacio('Carrito vacío',
          'Pasa el lector por el código de barras o escribe el nombre y da Enter.');
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _carrito.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (_, i) {
        final l = _carrito[i];
        return Padding(
          key: ValueKey('pv_linea_${l.p.nombre}'),
          padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.p.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyLarge),
                    Text(
                        l.porMayor
                            ? '${precioConUnidad(l.precio, l.p.unidad)} · por mayor'
                            : l.p.tienePrecioMayor
                                ? '${precioConUnidad(l.precio, l.p.unidad)} · desde ${cantidadConUnidad(l.p.cantidadMayor, l.p.unidad)} a ${cop(l.p.precioMayor)}'
                                : precioConUnidad(l.precio, l.p.unidad),
                        style: t.bodySmall?.copyWith(
                            color:
                                l.porMayor ? Paleta.of(context).ventas : null,
                            fontWeight: l.porMayor ? FontWeight.w700 : null)),
                  ]),
            ),
            IconButton(
              tooltip: 'Uno menos',
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() {
                if (l.cantidad > 1) {
                  l.cantidad -= 1;
                } else {
                  _carrito.remove(l);
                }
              }),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _editarCantidad(l),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Text(cantidadConUnidad(l.cantidad, l.p.unidad),
                    style: cifras(t.titleSmall)),
              ),
            ),
            IconButton(
              tooltip: 'Uno más',
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(
                  () => l.cantidad += esFraccionable(l.p.unidad) ? 0.5 : 1),
              icon: const Icon(Icons.add_circle_outline),
            ),
            SizedBox(
              width: 92,
              child: Text(cop(l.total),
                  textAlign: TextAlign.right, style: cifras(t.titleSmall)),
            ),
          ]),
        );
      },
    );
  }

  Widget _cobro({bool compacto = false}) {
    final t = Theme.of(context).textTheme;
    final p = Paleta.of(context);
    final cambio = _cambio;
    final total = Row(children: [
      Expanded(
        child: Text(
            _carrito.isEmpty
                ? 'Total'
                : 'Total · ${_carrito.length} ${_carrito.length == 1 ? 'producto' : 'productos'}',
            style: t.titleMedium),
      ),
      Text(cop(_total),
          key: const ValueKey('pv_total'),
          style: cifras(t.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800, color: p.ventas))),
    ]);
    final botonCobrar = SizedBox(
      height: 56,
      child: FilledButton.icon(
        key: const ValueKey('pv_cobrar'),
        onPressed: _carrito.isEmpty || _guardando ? null : _cobrar,
        icon: const Icon(Icons.point_of_sale),
        label: Text(compacto ? 'Cobrar ${cop(_total)}' : 'Cobrar  (F4)'),
      ),
    );
    if (compacto && _carrito.isEmpty) {
      final ultima = _ultima;
      return ultima == null
          ? Text('Busca o escanea un producto para empezar.',
              style: t.bodyMedium)
          : _VentaLista(
              ultima: ultima, alComprobante: _comprobante, compacta: true);
    }
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_puedeDescontar && !compacto) ...[
            TextField(
              key: const ValueKey('pv_descuento'),
              controller: _descuento,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() => _error = null),
              decoration: const InputDecoration(
                  labelText: 'Descuento', prefixText: r'$ ', isDense: true),
            ),
            const SizedBox(height: 10),
          ],
          total,
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final m in const [
                'efectivo',
                'nequi',
                'daviplata',
                'tarjeta_debito',
                'tarjeta_credito',
                'transferencia'
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    key: ValueKey('pv_medio_$m'),
                    label: Text(nombresMedio[m]!),
                    selected: _medio == m,
                    onSelected: (_) => setState(() {
                      _medio = m;
                      _error = null;
                    }),
                  ),
                ),
            ]),
          ),
          if (_medio == 'efectivo') ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('pv_recibido'),
                  controller: _recibido,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _cobrar(),
                  decoration: const InputDecoration(
                      labelText: 'Recibido', prefixText: r'$ ', isDense: true),
                ),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('Cambio', style: t.labelMedium),
                Text(cambio == null ? '—' : cop(cambio < 0 ? 0 : cambio),
                    key: const ValueKey('pv_cambio'),
                    style: cifras(t.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cambio != null && cambio < -0.5
                            ? p.gastos
                            : null))),
              ]),
            ]),
            if (!compacto) const SizedBox(height: 8),
            if (!compacto)
              Wrap(spacing: 6, runSpacing: 6, children: [
                ActionChip(
                  label: const Text('Exacto'),
                  onPressed: () => setState(
                      () => _recibido.text = _total.round().toString()),
                ),
                for (final b in _billetes)
                  if (b >= _total * 0.5 || b == _billetes.last)
                    ActionChip(
                      label: Text(cop(b)),
                      onPressed: () =>
                          setState(() => _recibido.text = b.round().toString()),
                    ),
              ]),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                key: const ValueKey('pv_error'),
                style: t.bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 12),
          botonCobrar,
          if (db.puede(Permiso.venderFiado)) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('pv_fiar'),
              onPressed: _carrito.isEmpty || _guardando ? null : _fiar,
              icon: const Icon(Icons.person_add_alt_outlined),
              label: Text(compacto ? 'Fiar' : 'Fiar a un cliente  (F6)'),
            ),
          ],
        ]);
  }

  Widget _ayudaTeclas() {
    final t = Theme.of(context).textTheme;
    Widget tecla(String k, String que) => Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(k, style: t.labelSmall),
            ),
            const SizedBox(width: 5),
            Text(que, style: t.bodySmall),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
      child: Wrap(runSpacing: 6, children: [
        tecla('F2', 'Buscar'),
        tecla('Enter', 'Agregar'),
        tecla('3*', 'Varias unidades'),
        tecla('F4', 'Cobrar'),
        if (db.puede(Permiso.venderFiado)) tecla('F6', 'Fiar'),
        tecla('Supr', 'Quitar el último'),
        tecla('Esc', 'Limpiar'),
      ]),
    );
  }

  void _comprobante() {
    final u = _ultima;
    if (u != null) enviarComprobante(context, u.id);
  }
}

String _stockTexto(ProductoStock p) {
  if (p.esServicio) return 'Servicio';
  if (p.agotado) return 'Agotado';
  return 'Hay ${cantidadConUnidad(p.stock, p.unidad)}';
}

class _TarjetaProducto extends StatelessWidget {
  final ProductoStock p;
  final VoidCallback onTap;
  const _TarjetaProducto({required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pal = Paleta.of(context);
    final cs = Theme.of(context).colorScheme;
    return Card(
      key: ValueKey('pv_prod_${p.nombre}'),
      margin: EdgeInsets.zero,
      color: p.agotado ? pal.gastosFondo : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Text(p.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSmall),
            ),
            Text(precioConUnidad(p.precio, p.unidad),
                style: cifras(t.titleMedium?.copyWith(
                    color: pal.ventas, fontWeight: FontWeight.w800))),
            Row(children: [
              Expanded(
                child: Text(_stockTexto(p),
                    style: t.bodySmall?.copyWith(
                        color: p.agotado
                            ? pal.gastos
                            : (p.bajo ? pal.fiado : cs.onSurfaceVariant))),
              ),
              if (p.codigo.isNotEmpty)
                Flexible(
                  child: Text(p.codigo,
                      overflow: TextOverflow.ellipsis,
                      style: t.labelSmall?.copyWith(color: cs.outline)),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _VentaLista extends StatelessWidget {
  final ({String id, double total, double cambio}) ultima;
  final VoidCallback alComprobante;
  final bool compacta;
  const _VentaLista(
      {required this.ultima,
      required this.alComprobante,
      this.compacta = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Paleta.of(context);
    final texto = Column(
      crossAxisAlignment:
          compacta ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Venta guardada · ${cop(ultima.total)}',
            key: const ValueKey('pv_venta_lista'), style: t.titleMedium),
        if (ultima.cambio > 0)
          Text('Cambio: ${cop(ultima.cambio)}',
              style: cifras((compacta ? t.titleLarge : t.headlineMedium)
                  ?.copyWith(color: p.ventas, fontWeight: FontWeight.w800))),
        TextButton.icon(
          onPressed: alComprobante,
          icon: const Icon(Icons.receipt_outlined),
          label: const Text('Enviar o imprimir comprobante'),
        ),
      ],
    );
    if (compacta) return texto;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle_outline, size: 48, color: p.ventas),
          const SizedBox(height: 8),
          Center(child: texto),
        ]),
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  final String titulo, texto;
  const _Vacio(this.titulo, this.texto);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(titulo, style: t.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(texto, style: t.bodyMedium, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

/// Elegir a quién se le fía, con buscador.
class _ElegirCliente extends StatefulWidget {
  final List<ClienteSaldo> clientes;
  const _ElegirCliente({required this.clientes});
  @override
  State<_ElegirCliente> createState() => _ElegirClienteState();
}

class _ElegirClienteState extends State<_ElegirCliente> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l = [
      for (final c in widget.clientes)
        if (c.nombre.toLowerCase().contains(_q.toLowerCase())) c
    ];
    return AlertDialog(
      title: const Text('¿A quién le fías?'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(children: [
          TextField(
            key: const ValueKey('pv_buscar_cliente'),
            autofocus: true,
            decoration: const InputDecoration(
                hintText: 'Buscar cliente', prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => _q = v.trim()),
            onSubmitted: (_) {
              if (l.length == 1) Navigator.pop(context, l.single);
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: l.isEmpty
                ? const Center(
                    child: Text(
                        'No hay clientes con ese nombre. Créalo en Clientes.'))
                : ListView(children: [
                    for (final c in l)
                      ListTile(
                        key: ValueKey('pv_cliente_${c.nombre}'),
                        title: Text(c.nombre),
                        subtitle:
                            c.saldo > 0 ? Text('Debe ${cop(c.saldo)}') : null,
                        onTap: () => Navigator.pop(context, c),
                      ),
                  ]),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
      ],
    );
  }
}
