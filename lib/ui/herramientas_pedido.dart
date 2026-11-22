part of 'herramientas_page.dart';

// Pedido de mercancía al proveedor: sugerido, envío por WhatsApp y llegada con pago total, parcial o fiado.

class PedidoProveedorPage extends StatefulWidget {
  const PedidoProveedorPage({super.key});
  @override
  State<PedidoProveedorPage> createState() => _PedidoProveedorPageState();
}

class _PedidoProveedorPageState extends State<PedidoProveedorPage> {
  List<ProductoStock> _productos = const [];
  List<Map<String, Object?>> _proveedores = const [];
  final _cant = <String, double>{};
  String? _proveedorId;
  bool _cargado = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = LocalDb.instance;
    final ps = await db.productos();
    final pv = await db.proveedores();
    if (!mounted) return;
    setState(() {
      _productos = ps;
      _proveedores = pv;
      if (!_cargado) {
        for (final (p, c) in pedidoSugerido(ps)) {
          _cant[p.id] = c;
        }
        if (pv.isNotEmpty) _proveedorId = pv.first['id'] as String;
      }
      _cargado = true;
    });
  }

  Map<String, Object?>? get _proveedor {
    for (final x in _proveedores) {
      if (x['id'] == _proveedorId) return x;
    }
    return null;
  }

  List<(ProductoStock, double)> get _items => [
        for (final p in _productos)
          if ((_cant[p.id] ?? 0) > 0) (p, _cant[p.id]!)
      ];

  Future<void> _nuevoProveedor() async {
    final id = await mostrarFormTercero(context, claseInicial: 'proveedor');
    if (id == null) return;
    _proveedorId = id;
    await _load();
  }

  Future<void> _enviar() async {
    final items = _items;
    if (items.isEmpty) {
      avisar('Agrega al menos un producto al pedido');
      return;
    }
    final negocio = await LocalDb.instance.perfilNegocio();
    final pv = _proveedor;
    final texto = textoPedido(
      negocio: negocio,
      fecha: DateTime.now(),
      items: [for (final (p, c) in items) (p.nombre, c)],
      proveedor: pv?['nombre'] as String?,
    );
    final total = items.fold(0.0, (s, x) => s + x.$2 * x.$1.costo);
    final documento = await LocalDb.instance.emitirDocumento('pedido',
        clienteNombre: pv?['nombre'] as String?,
        total: total,
        resumen: items.map((x) => x.$1.nombre).join(', '));
    final numero = documento['numero'] as String;
    final pdf = pdfListo(
        DocImprimible(
          titulo: 'Pedido de mercancía',
          numero: numero,
          fecha: DateTime.now(),
          negocio: negocio,
          cliente: pv?['nombre'] as String?,
          etiquetaCliente: 'Proveedor',
          etiquetaPrecio: 'Costo aprox.',
          lineas: [
            for (final (p, c) in items)
              LineaDoc(
                  p.nombre, c, p.costo, p.unidad == 'serv' ? 'und' : p.unidad)
          ],
          total: total,
          notas: [
            'Total aproximado según el último costo registrado.',
            'Por favor confirmar precios y fecha de entrega.',
          ],
        ),
        tirilla: false);
    await archivarDocumento(documento, pdf);
    if (!mounted) return;
    await mostrarDocumento(context,
        titulo: 'Pedido N.º $numero',
        texto: '$texto\n\nPedido N.º $numero',
        telefono: (pv?['telefono'] as String?) ?? '',
        pdf: pdf);
  }

  Future<void> _llego() async {
    final items = _items;
    if (items.isEmpty) {
      avisar('Agrega al menos un producto al pedido');
      return;
    }
    final total = items.fold(0.0, (s, x) => s + x.$2 * x.$1.costo);
    final pv = _proveedor;
    // Cómo se le paga al proveedor: todo, una parte (lo más común en la
    // tienda de barrio: la mitad y la otra mitad fiada) o todo fiado.
    var modo = total > 0 ? 'parte' : 'nada';
    final parte = TextEditingController(text: (total / 2).toStringAsFixed(0));
    var vence = DateTime.now().add(const Duration(days: 15));
    final fmt = DateFormat('d MMM y', 'es_CO');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) {
          final t = Theme.of(c).textTheme;
          final pagado = switch (modo) {
            'todo' => total,
            'parte' => (parseMonto(parte.text) ?? 0).clamp(0.0, total),
            _ => 0.0,
          };
          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 0, 20, 20 + MediaQuery.viewInsetsOf(c).bottom),
            child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('¿Llegó el pedido?', style: t.headlineSmall),
                    const SizedBox(height: 4),
                    Text(
                        'Se suman ${items.length == 1 ? '1 producto' : '${items.length} productos'} al inventario. '
                        'Total a precio de costo: ${cop(total)}.'),
                    if (total > 0) ...[
                      const SizedBox(height: 14),
                      Text(
                          '¿Cuánto le pagaste${pv == null ? '' : ' a ${pv['nombre']}'}?',
                          style: t.titleSmall),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: 'todo', label: Text('Todo')),
                          ButtonSegment(
                              value: 'parte', label: Text('Una parte')),
                          ButtonSegment(
                              value: 'nada', label: Text('Todo fiado')),
                        ],
                        selected: {modo},
                        onSelectionChanged: (v) => set(() => modo = v.first),
                      ),
                      if (modo == 'parte') ...[
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: parte,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Le pagué ahora',
                                  prefixText: r'$ '),
                              onChanged: (_) => set(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          for (final pct in const [30, 50, 70])
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: ActionChip(
                                label: Text('$pct %'),
                                onPressed: () => set(() => parte.text =
                                    (total * pct / 100).toStringAsFixed(0)),
                              ),
                            ),
                        ]),
                      ],
                      if (modo != 'todo') ...[
                        const SizedBox(height: 10),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event_outlined),
                          title: Text('Queda debiendo ${cop(total - pagado)}'),
                          subtitle: Text(
                              'Pagar a más tardar el ${fmt.format(vence)} (toca para cambiar)'),
                          onTap: () async {
                            final f = await showDatePicker(
                                context: c,
                                initialDate: vence,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 180)));
                            if (f != null) set(() => vence = f);
                          },
                        ),
                      ],
                    ],
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () {
                        if (modo == 'parte' &&
                            (pagado <= 0 || pagado >= total)) {
                          avisar(
                              'Escribe cuánto pagaste (más de 0 y menos del total)');
                          return;
                        }
                        Navigator.pop(c, true);
                      },
                      child: const Text('Ingresar al inventario'),
                    ),
                  ]),
            ),
          );
        },
      ),
    );
    final pagado = switch (modo) {
      'todo' => total,
      'parte' => (parseMonto(parte.text) ?? 0).clamp(0.0, total),
      _ => 0.0,
    };
    parte.dispose();
    if (ok != true || !mounted) return;
    final pagosGasto = pagado > 0
        ? await pedirPagos(context, pagado,
            titulo: '¿Con qué le pagaste al proveedor?')
        : null;
    if (pagado > 0 && pagosGasto == null) return;
    await LocalDb.instance.recibirPedido(
        [for (final (p, c) in items) (p.id, c, p.costo)],
        conceptoGasto: total > 0
            ? 'Compra de mercancía${pv == null ? '' : ' a ${pv['nombre']}'}'
            : null,
        pagosGasto: pagosGasto,
        pagadoAhora: pagado,
        proveedorId: pv?['id'] as String?,
        proveedorNombre: pv?['nombre'] as String?,
        venceSaldo: vence);
    SyncService.instance.sync();
    avisar(total - pagado > 0.5
        ? 'Mercancía ingresada. Le debes ${cop(total - pagado)} al proveedor'
        : 'Mercancía ingresada al inventario');
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Pedir mercancía')),
      body: !_cargado
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                  Text(
                      'Te sugerimos lo que se está agotando para quedar en el doble del '
                      'mínimo. Ajusta las cantidades y envíalo a tu proveedor.',
                      style: t.bodyMedium
                          ?.copyWith(color: esquema.onSurfaceVariant)),
                  const TituloSeccion('Proveedor'),
                  Row(children: [
                    Expanded(
                      child: _proveedores.isEmpty
                          ? Text('Sin proveedores guardados',
                              style: t.bodyMedium)
                          : DropdownButtonFormField<String>(
                              initialValue: _proveedorId,
                              isExpanded: true,
                              items: [
                                for (final x in _proveedores)
                                  DropdownMenuItem(
                                      value: x['id'] as String,
                                      child: Text(x['nombre'] as String,
                                          overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (v) =>
                                  setState(() => _proveedorId = v),
                            ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                        tooltip: 'Nuevo proveedor',
                        onPressed: _nuevoProveedor,
                        icon: const Icon(Icons.person_add_alt)),
                  ]),
                  const TituloSeccion('Productos del pedido'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                      child: _Carrito(
                          productos: _productos,
                          cantidades: _cant,
                          usarCosto: true,
                          onCambio: () => setState(() {})),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final p = await _elegirProducto(context, _productos);
                          if (p != null) {
                            setState(
                                () => _cant[p.id] = (_cant[p.id] ?? 0) + 1);
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => agregarPorCodigo(
                            context, _productos, _cant, () => setState(() {})),
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Escanear'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1C7A43),
                        foregroundColor: Colors.white),
                    onPressed: _enviar,
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('Enviar pedido por WhatsApp'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _llego,
                    icon: const Icon(Icons.inventory_outlined),
                    label:
                        const Text('Llegó el pedido: ingresar al inventario'),
                  ),
                ]),
    );
  }
}
