import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/local_db.dart';
import '../data/sync_service.dart';
import '../domain/documentos.dart';
import '../domain/formato.dart';
import '../domain/resumen.dart';
import 'comun.dart';
import 'inventario_page.dart';
import 'tema.dart';
import 'ventas_page.dart';

// Herramientas para que el tendero maneje casi todo desde la app y por
// WhatsApp: comprobantes de venta, cotizaciones, pedidos al proveedor (con
// ingreso de la mercancía) y promociones.

// ------------------------------------------------------------ comprobante
/// Muestra el comprobante de una venta y lo envía por WhatsApp (al cliente
/// si tiene celular; si no, WhatsApp deja elegir el contacto).
Future<void> enviarComprobante(BuildContext context, String ventaId) async {
  final db = LocalDb.instance;
  final v = await db.movimiento(ventaId);
  if (v == null || !context.mounted) return;
  final lineas = await db.lineasDeVenta(ventaId);
  final negocio = await db.perfilNegocio();
  final clienteId = v['cliente_id'] as String?;
  var saldo = 0.0;
  if (clienteId != null) {
    final c = await db.cliente(clienteId);
    saldo = (c?['saldo'] as num?)?.toDouble() ?? 0;
  }
  final texto = textoComprobante(
    negocio: negocio,
    ventaId: ventaId,
    fecha: DateTime.parse(v['fecha'] as String).toLocal(),
    lineas: lineas,
    total: (v['monto'] as num).toDouble(),
    cliente: v['cliente_nombre'] as String?,
    fiado: v['credito'] == 1,
    saldoCliente: saldo,
  );
  if (!context.mounted) return;
  await mostrarDocumento(context,
      titulo: 'Comprobante de venta',
      texto: texto,
      telefono: (v['cliente_telefono'] as String?) ?? '',
      nota: negocio.nombre.isEmpty
          ? 'Consejo: en el menú ⋮ → «Mi negocio» pon el nombre, NIT y '
              'dirección para que salgan en el comprobante.'
          : null);
}

/// Vista previa de un documento con el botón para enviarlo por WhatsApp.
Future<void> mostrarDocumento(BuildContext context,
    {required String titulo,
    required String texto,
    String telefono = '',
    String? nota,
    String boton = 'Enviar por WhatsApp'}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (c) {
      final t = Theme.of(c).textTheme;
      final esquema = Theme.of(c).colorScheme;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.85),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(titulo, style: t.headlineSmall),
            const SizedBox(height: 12),
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: esquema.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: esquema.outlineVariant),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(texto.replaceAll('*', '').replaceAll('_', ''),
                      style: cifras(t.bodyMedium)),
                ),
              ),
            ),
            if (nota != null) ...[
              const SizedBox(height: 10),
              Text(nota, style: t.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1C7A43), foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(c);
                enviarWhatsApp(texto, telefono: telefono);
              },
              icon: const Icon(Icons.chat_outlined),
              label: Text(telefono.isEmpty ? '$boton (elegir contacto)' : boton),
            ),
          ]),
        ),
      );
    },
  );
}

// ------------------------------------------------------------- inicio
/// Accesos a las herramientas, para el Inicio.
class HerramientasGrid extends StatelessWidget {
  const HerramientasGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    void ir(Widget w) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    final items = [
      (Icons.receipt_outlined, 'Comprobantes', 'Envía la venta por WhatsApp',
          p.ventasFondo, p.ventas, () => ir(const ComprobantesPage())),
      (Icons.request_quote_outlined, 'Cotizaciones', 'Arma y envía precios',
          p.asistenteFondo, p.asistente, () => ir(const CotizacionesPage())),
      (Icons.local_shipping_outlined, 'Pedir mercancía', 'Pedido sugerido al proveedor',
          p.fiadoFondo, p.fiado, () => ir(const PedidoProveedorPage())),
      (Icons.campaign_outlined, 'Promociones', 'Ofertas para tu WhatsApp',
          p.gastosFondo, p.gastos, () => ir(const PromocionPage())),
    ];
    return LayoutBuilder(builder: (context, box) {
      final ancho = (box.maxWidth - 10) / 2;
      return Wrap(spacing: 10, runSpacing: 10, children: [
        for (final (icono, titulo, sub, fondo, tinta, onTap) in items)
          SizedBox(
            width: ancho,
            child: Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: fondo, borderRadius: BorderRadius.circular(12)),
                      child: Icon(icono, color: tinta, size: 22),
                    ),
                    const SizedBox(height: 10),
                    Text(titulo, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: 34,
                      child: Text(sub,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
      ]);
    });
  }
}

// ------------------------------------------------------- comprobantes
class ComprobantesPage extends StatefulWidget {
  const ComprobantesPage({super.key});
  @override
  State<ComprobantesPage> createState() => _ComprobantesPageState();
}

class _ComprobantesPageState extends State<ComprobantesPage> {
  List<Map<String, Object?>>? _ventas;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await LocalDb.instance.movimientos(limite: 100);
    if (mounted) setState(() => _ventas = m.where((x) => x['tipo'] == 'ingreso').toList());
  }

  @override
  Widget build(BuildContext context) {
    final v = _ventas;
    final fmt = DateFormat('d MMM, h:mm a', 'es_CO');
    return Scaffold(
      appBar: AppBar(title: const Text('Comprobantes de venta')),
      body: v == null
          ? const Center(child: CircularProgressIndicator())
          : v.isEmpty
              ? const Center(
                  child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Aún no hay ventas. Registra una y aquí podrás '
                          'enviar su comprobante.',
                          textAlign: TextAlign.center)))
              : ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 24), children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                    child: Text(
                        'Toca una venta para ver su comprobante y enviarlo por '
                        'WhatsApp. Trae número, productos y total, listo para '
                        'conectar después con facturación electrónica.',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                  Card(
                    child: Column(children: [
                      for (final (i, x) in v.indexed) ...[
                        if (i > 0) const Divider(indent: 72),
                        InkWell(
                          onTap: () => enviarComprobante(context, x['id'] as String),
                          child: IgnorePointer(child: FilaMovimiento(v: x, fmt: fmt)),
                        ),
                      ],
                    ]),
                  ),
                ]),
    );
  }
}

// ------------------------------------------------------- carrito
/// Lista editable de productos con cantidad (+/−) y total.
class _Carrito extends StatelessWidget {
  final List<ProductoStock> productos;
  final Map<String, double> cantidades;
  final bool usarCosto;
  final VoidCallback onCambio;
  const _Carrito(
      {required this.productos,
      required this.cantidades,
      required this.onCambio,
      this.usarCosto = false});

  ProductoStock? _p(String id) {
    for (final x in productos) {
      if (x.id == id) return x;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final filas = [
      for (final e in cantidades.entries)
        if (_p(e.key) case final p?) (p, e.value)
    ];
    if (filas.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('Todavía no hay productos.',
            style: t.bodyMedium?.copyWith(color: esquema.onSurfaceVariant)),
      );
    }
    return Column(children: [
      for (final (p, c) in filas)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall),
                Text(
                    '${cop(usarCosto ? p.costo : p.precio)} c/u · hay ${cantidadTexto(p.stock)}',
                    style: t.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
              ]),
            ),
            IconButton(
              tooltip: 'Quitar uno',
              onPressed: () {
                final n = c - 1;
                if (n <= 0) {
                  cantidades.remove(p.id);
                } else {
                  cantidades[p.id] = n;
                }
                onCambio();
              },
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
                width: 32,
                child: Text(cantidadDoc(c),
                    textAlign: TextAlign.center, style: cifras(t.titleMedium))),
            IconButton(
              tooltip: 'Agregar uno',
              onPressed: () {
                cantidades[p.id] = c + 1;
                onCambio();
              },
              icon: const Icon(Icons.add_circle_outline),
            ),
          ]),
        ),
    ]);
  }
}

Future<ProductoStock?> _elegirProducto(BuildContext context, List<ProductoStock> l) {
  if (l.isEmpty) {
    avisar('Primero agrega productos en la pestaña Inventario');
    return Future.value(null);
  }
  return showModalBottomSheet<ProductoStock>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ElegirProducto(productos: l),
  );
}

// --------------------------------------------------- pedido proveedor
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
    final nombre = TextEditingController();
    final tel = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Nuevo proveedor'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: nombre,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre o empresa')),
          const SizedBox(height: 12),
          TextField(
              controller: tel,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Celular (WhatsApp)', hintText: '300 123 4567')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Guardar')),
        ],
      ),
    );
    final n = nombre.text.trim();
    final t = normalizarTelefono(tel.text);
    nombre.dispose();
    tel.dispose();
    if (ok != true) return;
    if (n.length < 2) {
      avisar('Escribe el nombre del proveedor');
      return;
    }
    if (t == null) {
      avisar('Celular colombiano de 10 dígitos que empiece por 3');
      return;
    }
    final id = await LocalDb.instance.saveProveedor(n, t);
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
    if (!mounted) return;
    await mostrarDocumento(context,
        titulo: 'Pedido al proveedor',
        texto: texto,
        telefono: (pv?['telefono'] as String?) ?? '');
  }

  Future<void> _llego() async {
    final items = _items;
    if (items.isEmpty) {
      avisar('Agrega al menos un producto al pedido');
      return;
    }
    final total = items.fold(0.0, (s, x) => s + x.$2 * x.$1.costo);
    var gasto = total > 0;
    final pv = _proveedor;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('¿Llegó el pedido?'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Se sumarán ${items.length == 1 ? '1 producto' : '${items.length} productos'} '
                'al inventario con las cantidades del pedido.'),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: gasto,
              onChanged: total > 0 ? (v) => set(() => gasto = v) : null,
              title: const Text('Registrar la compra como gasto'),
              subtitle: Text(total > 0
                  ? 'Total a precio de costo: ${cop(total)}'
                  : 'Los productos no tienen costo registrado'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sí, ingresar')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await LocalDb.instance.recibirPedido(
        [for (final (p, c) in items) (p.id, c, p.costo)],
        conceptoGasto: gasto
            ? 'Compra de mercancía${pv == null ? '' : ' a ${pv['nombre']}'}'
            : null);
    SyncService.instance.sync();
    avisar('Mercancía ingresada al inventario');
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
          : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
              Text(
                  'Te sugerimos lo que se está agotando para quedar en el doble del '
                  'mínimo. Ajusta las cantidades y envíalo a tu proveedor.',
                  style: t.bodyMedium?.copyWith(color: esquema.onSurfaceVariant)),
              const TituloSeccion('Proveedor'),
              Row(children: [
                Expanded(
                  child: _proveedores.isEmpty
                      ? Text('Sin proveedores guardados', style: t.bodyMedium)
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
                          onChanged: (v) => setState(() => _proveedorId = v),
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
              OutlinedButton.icon(
                onPressed: () async {
                  final p = await _elegirProducto(context, _productos);
                  if (p != null) setState(() => _cant[p.id] = (_cant[p.id] ?? 0) + 1);
                },
                icon: const Icon(Icons.add),
                label: const Text('Agregar producto'),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1C7A43), foregroundColor: Colors.white),
                onPressed: _enviar,
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Enviar pedido por WhatsApp'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _llego,
                icon: const Icon(Icons.inventory_outlined),
                label: const Text('Llegó el pedido: ingresar al inventario'),
              ),
            ]),
    );
  }
}

// ------------------------------------------------------- cotizaciones
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
    if (cid != null) tel = ((await db.cliente(cid))?['telefono'] as String?) ?? '';
    final texto = textoCotizacion(
      negocio: negocio,
      cotizacionId: c['id'] as String,
      fecha: DateTime.parse(c['creado'] as String).toLocal(),
      lineas: [
        for (final i in LocalDb.itemsCotizacion(c)) LineaDoc(i.nombre, i.cantidad, i.precio)
      ],
      cliente: c['cliente_nombre'] as String?,
    );
    if (!mounted) return;
    await mostrarDocumento(context, titulo: 'Cotización', texto: texto, telefono: tel);
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
            leading: Icon(Icons.delete_outline, color: Theme.of(s).colorScheme.error),
            title: Text('Eliminar', style: TextStyle(color: Theme.of(s).colorScheme.error)),
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
        final ventaId =
            await LocalDb.instance.venderCotizacion(id, fiado: accion == 'fiado');
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
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const NuevaCotizacionPage())),
        icon: const Icon(Icons.add),
        label: const Text('Cotización'),
      ),
      body: l == null
          ? const Center(child: CircularProgressIndicator())
          : l.isEmpty
              ? const Center(
                  child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Arma una cotización con tus productos, envíala por '
                      'WhatsApp y conviértela en venta cuando el cliente confirme.',
                      textAlign: TextAlign.center),
                ))
              : ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 96), children: [
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
                              DateTime.parse(c['creado'] as String).toLocal())),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(cop((c['total'] as num).toDouble()),
                                style: cifras(t.titleSmall)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: c['estado'] == 'vendida' ? p.ventasFondo : p.asistenteFondo,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(c['estado'] == 'vendida' ? 'Vendida' : 'Abierta',
                                  style: t.labelMedium?.copyWith(
                                      color: c['estado'] == 'vendida' ? p.ventas : p.asistente)),
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

  double get _total => _productos.fold(0.0, (s, p) => s + (_cant[p.id] ?? 0) * p.precio);

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
              costo: p.costo)
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
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
        Card(
          child: ListTile(
            leading: _cliente == null
                ? const Icon(Icons.person_outline)
                : AvatarCliente(nombre: _cliente!.nombre, clave: _cliente!.nombre, tam: 36),
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
                productos: _productos, cantidades: _cant, onCambio: () => setState(() {})),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () async {
            final x = await _elegirProducto(context, _productos);
            if (x != null) setState(() => _cant[x.id] = (_cant[x.id] ?? 0) + 1);
          },
          icon: const Icon(Icons.add),
          label: const Text('Agregar producto'),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
              color: p.asistenteFondo, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Text('Total', style: t.titleMedium?.copyWith(color: p.asistente)),
            const Spacer(),
            Text(cop(_total), style: cifras(t.headlineSmall?.copyWith(color: p.asistente))),
          ]),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1C7A43), foregroundColor: Colors.white),
          onPressed: _guardar,
          icon: const Icon(Icons.chat_outlined),
          label: const Text('Guardar y enviar por WhatsApp'),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------- promociones
class PromocionPage extends StatefulWidget {
  const PromocionPage({super.key});
  @override
  State<PromocionPage> createState() => _PromocionPageState();
}

class _PromocionPageState extends State<PromocionPage> {
  List<ProductoStock> _productos = const [];
  final _elegidos = <String>{};
  final _precios = <String, TextEditingController>{};
  final _titulo = TextEditingController(text: 'Ofertas de hoy');
  final _nota = TextEditingController();

  @override
  void initState() {
    super.initState();
    () async {
      final ps = (await LocalDb.instance.productos()).where((x) => x.stock > 0).toList();
      if (mounted) setState(() => _productos = ps);
    }();
  }

  @override
  void dispose() {
    for (final c in _precios.values) {
      c.dispose();
    }
    _titulo.dispose();
    _nota.dispose();
    super.dispose();
  }

  TextEditingController _ctrl(ProductoStock p) =>
      _precios.putIfAbsent(p.id, () => TextEditingController(text: cop(p.precio).substring(1)));

  Future<void> _compartir() async {
    final l = [
      for (final p in _productos)
        if (_elegidos.contains(p.id)) (p.nombre, parseMonto(_ctrl(p).text) ?? p.precio)
    ];
    if (l.isEmpty) {
      avisar('Elige al menos un producto');
      return;
    }
    final negocio = await LocalDb.instance.perfilNegocio();
    final texto = textoPromocion(
        negocio: negocio,
        productos: l,
        titulo: _titulo.text.trim().isEmpty ? 'Ofertas de hoy' : _titulo.text.trim(),
        nota: _nota.text);
    if (!mounted) return;
    await mostrarDocumento(context,
        titulo: 'Promoción',
        texto: texto,
        boton: 'Compartir por WhatsApp',
        nota: 'Compártela en tu estado, en grupos del barrio o en una lista de '
            'difusión de WhatsApp para llegar a varios clientes a la vez.');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Promociones')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
        Text('Elige productos con existencias, ajusta el precio de oferta y '
            'compártelo por WhatsApp.',
            style: t.bodyMedium?.copyWith(color: esquema.onSurfaceVariant)),
        const SizedBox(height: 14),
        TextField(
            controller: _titulo,
            decoration: const InputDecoration(labelText: 'Título', hintText: 'Ofertas de hoy')),
        const SizedBox(height: 10),
        TextField(
            controller: _nota,
            maxLines: 2,
            decoration: const InputDecoration(
                labelText: 'Nota (opcional)', hintText: 'Ej.: solo hasta el sábado')),
        const TituloSeccion('Productos'),
        if (_productos.isEmpty)
          Text('No hay productos con existencias. Agrégalos en Inventario.',
              style: t.bodyMedium)
        else
          Card(
            child: Column(children: [
              for (final (i, p) in _productos.indexed) ...[
                if (i > 0) const Divider(indent: 16),
                CheckboxListTile(
                  value: _elegidos.contains(p.id),
                  onChanged: (v) => setState(() =>
                      v == true ? _elegidos.add(p.id) : _elegidos.remove(p.id)),
                  title: Text(p.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: _elegidos.contains(p.id)
                      ? Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: TextField(
                            controller: _ctrl(p),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                                isDense: true, labelText: 'Precio de oferta', prefixText: r'$ '),
                          ),
                        )
                      : Text('${cop(p.precio)} · hay ${cantidadTexto(p.stock)}'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ]),
          ),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1C7A43), foregroundColor: Colors.white),
          onPressed: _compartir,
          icon: const Icon(Icons.campaign_outlined),
          label: const Text('Ver y compartir por WhatsApp'),
        ),
      ]),
    );
  }
}
