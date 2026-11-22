part of 'herramientas_page.dart';

// Cotizaciones: lista, creación y conversión en venta.

class CotizacionesPage extends StatefulWidget {
  const CotizacionesPage({super.key});
  @override
  State<CotizacionesPage> createState() => _CotizacionesPageState();
}

class _CotizacionesPageState extends State<CotizacionesPage> {
  List<Map<String, Object?>>? _l;

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
    final l = await LocalDb.instance.cotizaciones();
    if (mounted) setState(() => _l = l);
  }

  Future<void> _enviar(Map<String, Object?> c) async {
    final db = LocalDb.instance;
    final negocio = await db.perfilNegocio();
    var tel = '';
    final cid = c['cliente_id'] as String?;
    if (cid != null) {
      tel = ((await db.cliente(cid))?['telefono'] as String?) ?? '';
    }
    final lineas = [
      for (final i in LocalDb.itemsCotizacion(c))
        LineaDoc(i.nombre, i.cantidad, i.precio, i.unidad)
    ];
    final fecha = DateTime.parse(c['creado'] as String).toLocal();
    final texto = textoCotizacion(
      negocio: negocio,
      cotizacionId: c['id'] as String,
      fecha: fecha,
      lineas: lineas,
      cliente: c['cliente_nombre'] as String?,
    );
    final documento = await db.emitirDocumento('cotizacion',
        refId: c['id'] as String,
        clienteId: cid,
        clienteNombre: c['cliente_nombre'] as String?,
        total: (c['total'] as num).toDouble(),
        resumen: lineas.map((l) => l.nombre).join(', '),
        reutilizar: true);
    final numero = documento['numero'] as String;
    final formas = (await db.datosPago()).lineas();
    final pdf = pdfListo(DocImprimible(
      titulo: 'Cotización',
      numero: numero,
      fecha: fecha,
      negocio: negocio,
      cliente: c['cliente_nombre'] as String?,
      lineas: lineas,
      total: (c['total'] as num).toDouble(),
      notas: [
        'Precios válidos por 8 días o hasta agotar existencias.',
        if (formas.isNotEmpty)
          'Puede pagar por transferencia: ${formas.join(' · ')}',
      ],
    ));
    await archivarDocumento(documento, pdf);
    if (!mounted) return;
    await mostrarDocumento(context,
        titulo: 'Cotización N.º $numero',
        texto: texto.replaceFirst(numeroDoc(c['id'] as String), numero),
        telefono: tel,
        pdf: pdf);
  }

  Future<void> _acciones(Map<String, Object?> c) async {
    final vendida = c['estado'] == 'vendida';
    final accion = await showModalBottomSheet<String>(
      context: context,
      builder: (s) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            title: Text('Cotización N.º ${numeroDoc(c['id'] as String)}',
                style: Theme.of(s).textTheme.titleLarge),
            subtitle: Text(cop((c['total'] as num).toDouble())),
          ),
          const Divider(),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: const Icon(Icons.chat_outlined),
            title: const Text('Enviar por WhatsApp'),
            onTap: () => Navigator.pop(s, 'enviar'),
          ),
          if (!vendida) ...[
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.point_of_sale),
              title: const Text('Convertir en venta de contado'),
              subtitle: const Text('Descuenta el inventario'),
              onTap: () => Navigator.pop(s, 'contado'),
            ),
            if (c['cliente_id'] != null)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: const Icon(Icons.schedule),
                title: const Text('Convertir en venta fiada'),
                onTap: () => Navigator.pop(s, 'fiado'),
              ),
          ],
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: Icon(Icons.delete_outline,
                color: Theme.of(s).colorScheme.error),
            title: Text('Eliminar',
                style: TextStyle(color: Theme.of(s).colorScheme.error)),
            onTap: () => Navigator.pop(s, 'eliminar'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (accion == null || !mounted) return;
    final id = c['id'] as String;
    switch (accion) {
      case 'enviar':
        await _enviar(c);
      case 'eliminar':
        await LocalDb.instance.deleteCotizacion(id);
        avisar('Cotización eliminada');
      default:
        final fiado = accion == 'fiado';
        final pagos = fiado
            ? null
            : await pedirPagos(context, (c['total'] as num).toDouble());
        if (!fiado && pagos == null) return;
        final ventaId = await LocalDb.instance
            .venderCotizacion(id, fiado: fiado, pagos: pagos);
        SyncService.instance.sync();
        if (!mounted) return;
        final ctx = context;
        avisarConAccion('Venta registrada', 'Enviar comprobante', () {
          if (ctx.mounted) enviarComprobante(ctx, ventaId);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _l;
    final t = Theme.of(context).textTheme;
    final p = Paleta.of(context);
    final fmt = DateFormat('d MMM, h:mm a', 'es_CO');
    return Scaffold(
      appBar: AppBar(title: const Text('Cotizaciones')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NuevaCotizacionPage())),
        icon: const Icon(Icons.add),
        label: const Text('Cotización'),
      ),
      body: l == null
          ? const Center(child: CircularProgressIndicator())
          : l.isEmpty
              ? const Center(
                  child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                      'Arma una cotización con tus productos, envíala por '
                      'WhatsApp y conviértela en venta cuando el cliente confirme.',
                      textAlign: TextAlign.center),
                ))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                  children: [
                      Card(
                        child: Column(children: [
                          for (final (i, c) in l.indexed) ...[
                            if (i > 0) const Divider(indent: 16),
                            ListTile(
                              title: Text(
                                  '${c['cliente_nombre'] ?? 'Sin cliente'} · N.º ${numeroDoc(c['id'] as String)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              subtitle: Text(fmt.format(
                                  DateTime.parse(c['creado'] as String)
                                      .toLocal())),
                              trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(cop((c['total'] as num).toDouble()),
                                        style: cifras(t.titleSmall)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: c['estado'] == 'vendida'
                                            ? p.ventasFondo
                                            : p.asistenteFondo,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                          c['estado'] == 'vendida'
                                              ? 'Vendida'
                                              : 'Abierta',
                                          style: t.labelMedium?.copyWith(
                                              color: c['estado'] == 'vendida'
                                                  ? p.ventas
                                                  : p.asistente)),
                                    ),
                                  ]),
                              onTap: () => _acciones(c),
                            ),
                          ],
                        ]),
                      ),
                    ]),
    );
  }
}

class NuevaCotizacionPage extends StatefulWidget {
  const NuevaCotizacionPage({super.key});
  @override
  State<NuevaCotizacionPage> createState() => _NuevaCotizacionPageState();
}

class _NuevaCotizacionPageState extends State<NuevaCotizacionPage> {
  List<ProductoStock> _productos = const [];
  List<ClienteSaldo> _clientes = const [];
  final _cant = <String, double>{};
  ClienteSaldo? _cliente;

  @override
  void initState() {
    super.initState();
    () async {
      final ps = await LocalDb.instance.productos();
      final cs = await LocalDb.instance.clientesConSaldo();
      if (mounted) {
        setState(() {
          _productos = ps;
          _clientes = cs;
        });
      }
    }();
  }

  double get _total =>
      _productos.fold(0.0, (s, p) => s + (_cant[p.id] ?? 0) * p.precio);

  Future<void> _elegirCliente() async {
    final r = await showModalBottomSheet<ClienteSaldo?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => ListView(shrinkWrap: true, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text('Para quién es', style: Theme.of(c).textTheme.titleLarge),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          leading: const Icon(Icons.person_off_outlined),
          title: const Text('Sin cliente'),
          onTap: () => Navigator.pop(c, null),
        ),
        for (final x in _clientes)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: AvatarCliente(nombre: x.nombre, clave: x.nombre),
            title: Text(x.nombre),
            onTap: () => Navigator.pop(c, x),
          ),
      ]),
    );
    if (mounted) setState(() => _cliente = r);
  }

  Future<void> _guardar() async {
    final items = [
      for (final p in _productos)
        if ((_cant[p.id] ?? 0) > 0)
          ItemVenta(
              productoId: p.id,
              nombre: p.nombre,
              cantidad: _cant[p.id]!,
              precio: p.precio,
              costo: p.costo,
              unidad: p.unidad)
    ];
    if (items.isEmpty) {
      avisar('Agrega al menos un producto');
      return;
    }
    final db = LocalDb.instance;
    final id = await db.saveCotizacion(items,
        clienteId: _cliente?.id, clienteNombre: _cliente?.nombre);
    final negocio = await db.perfilNegocio();
    final texto = textoCotizacion(
      negocio: negocio,
      cotizacionId: id,
      fecha: DateTime.now(),
      lineas: [for (final i in items) LineaDoc(i.nombre, i.cantidad, i.precio)],
      cliente: _cliente?.nombre,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    avisar('Cotización guardada');
    await enviarWhatsApp(texto, telefono: _cliente?.telefono);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Paleta.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva cotización')),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Card(
              child: ListTile(
                leading: _cliente == null
                    ? const Icon(Icons.person_outline)
                    : AvatarCliente(
                        nombre: _cliente!.nombre,
                        clave: _cliente!.nombre,
                        tam: 36),
                title: Text(_cliente?.nombre ?? 'Cliente (opcional)'),
                trailing: const Icon(Icons.expand_more),
                onTap: _elegirCliente,
              ),
            ),
            const TituloSeccion('Productos'),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                child: _Carrito(
                    productos: _productos,
                    cantidades: _cant,
                    onCambio: () => setState(() {})),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final x = await _elegirProducto(context, _productos);
                    if (x != null) {
                      setState(() => _cant[x.id] = (_cant[x.id] ?? 0) + 1);
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
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                  color: p.asistenteFondo,
                  borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Text('Total',
                    style: t.titleMedium?.copyWith(color: p.asistente)),
                const Spacer(),
                Text(cop(_total),
                    style:
                        cifras(t.headlineSmall?.copyWith(color: p.asistente))),
              ]),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1C7A43),
                  foregroundColor: Colors.white),
              onPressed: _guardar,
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Guardar y enviar por WhatsApp'),
            ),
          ]),
    );
  }
}
