import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'escritorio.dart';
import '../pdf/pdf_etiquetas.dart';
import '../pdf/archivo.dart';
import 'exportar_ui.dart';
import '../domain/exportar.dart';
import '../domain/ejemplos.dart';
import '../data/local_db.dart';
import '../domain/roles.dart';
import '../data/sync_service.dart';
import '../domain/formato.dart';
import '../domain/importar.dart';
import '../domain/resumen.dart';
import 'comun.dart';
import 'escaner.dart';
import '../domain/codigos.dart';
import 'ilustraciones.dart';
import 'tema.dart';

String cantidadTexto(double c) =>
    c == c.roundToDouble() ? c.toInt().toString() : c.toStringAsFixed(1);

/// Inventario: productos, cuántos quedan y qué hay que reponer.
class InventarioPage extends StatefulWidget {
  const InventarioPage({super.key});
  @override
  State<InventarioPage> createState() => _InventarioPageState();
}

class _InventarioPageState extends State<InventarioPage> {
  List<ProductoStock> _items = [];
  bool _cargado = false;
  String _filtro = '';
  /// 'todos', 'reponer' o 'vencer'.
  String _vista = 'todos';

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
    final r = await LocalDb.instance.productos();
    if (mounted) {
      setState(() {
        _items = r;
        _cargado = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Paleta.of(context);
    final esquema = Theme.of(context).colorScheme;
    final reponer = _items.where((x) => x.agotado || x.bajo).length;
    final hoy = DateTime.now();
    final vencer = _items.where((x) => x.porVencer(hoy)).length;
    final valor =
        _items.fold(0.0, (s, x) => s + (x.stock > 0 ? x.stock * x.costo : 0));
    final f = _filtro.trim().toLowerCase();
    final lista = _items
        .where((x) => switch (_vista) {
              'reponer' => x.agotado || x.bajo,
              'vencer' => x.porVencer(hoy),
              _ => true,
            })
        .where((x) =>
            f.isEmpty ||
            x.nombre.toLowerCase().contains(f) ||
            x.codigo.contains(f.trim()))
        .toList();

    final db = LocalDb.instance;
    final edita = db.puede(Permiso.editarProductos);
    final veCostos = db.puede(Permiso.verCostos);
    return Scaffold(
      floatingActionButton: edita
          ? FloatingActionButton.extended(
              onPressed: () => mostrarFormProducto(context),
              icon: const Icon(Icons.add_box_outlined),
              label: Text(LocalDb.instance.modo.value.vendeProductos
                  ? 'Producto'
                  : 'Servicio'),
            )
          : null,
      body: !_cargado
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? EstadoVacio(
                  ilustracion: const IlustracionPizarra(),
                  titulo: 'Aún no hay productos',
                  texto: edita
                      ? 'Agrega lo que vendes con su precio, su costo y '
                          'cuántos tienes. Al vender, el stock baja solo.'
                      : 'Todavía no hay productos. El dueño o el '
                          'administrador los agregan.',
                  accion: edita
                      ? Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
                          FilledButton.icon(
                            onPressed: () => mostrarFormProducto(context),
                            icon: const Icon(Icons.add_box_outlined),
                            label: const Text('Agregar el primero'),
                          ),
                          OutlinedButton.icon(
                            key: const ValueKey('importar_excel'),
                            onPressed: () => importarDesdeExcel(context),
                            icon: const Icon(Icons.upload_file_outlined),
                            label: const Text('Traerlos de Excel'),
                          ),
                        ])
                      : null,
                )
              : ListView(
                  padding: esEscritorio(context)
                      ? const EdgeInsets.fromLTRB(24, 16, 24, 96)
                      : const EdgeInsets.fromLTRB(12, 12, 12, 96),
                  children: [
                      Row(children: [
                        if (veCostos) ...[
                          Expanded(
                            child: _Dato(
                                titulo: 'Valor a costo',
                                valor: cop(valor),
                                color: esquema.onSurface),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: _Dato(
                              titulo: 'Por reponer',
                              valor: reponer == 1
                                  ? '1 producto'
                                  : '$reponer productos',
                              color: reponer > 0 ? p.gastos : p.ventas,
                              icono: reponer > 0
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_outline),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            onChanged: (v) => setState(() => _filtro = v),
                            decoration: const InputDecoration(
                                hintText: 'Buscar producto',
                                prefixIcon: Icon(Icons.search)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          key: const ValueKey('imprimir_precios'),
                          tooltip: 'Etiquetas y lista de precios',
                          onPressed: () => imprimirPrecios(context, lista),
                          icon: const Icon(Icons.sell_outlined),
                        ),
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          key: const ValueKey('exportar_inventario'),
                          tooltip: 'Exportar a Excel',
                          onPressed: () => exportarCsv(nombreCsv('inventario', DateTime.now()),
                              csvProductos(_items, conCostos: veCostos)),
                          icon: const Icon(Icons.table_view_outlined),
                        ),
                        if (edita) ...[
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            key: const ValueKey('importar_excel'),
                            tooltip: 'Importar desde Excel',
                            onPressed: () => importarDesdeExcel(context),
                            icon: const Icon(Icons.upload_file_outlined),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        ChoiceChip(
                          label: Text('Todos (${_items.length})'),
                          selected: _vista == 'todos',
                          onSelected: (_) => setState(() => _vista = 'todos'),
                        ),
                        ChoiceChip(
                          label: Text('Por reponer ($reponer)'),
                          selected: _vista == 'reponer',
                          onSelected: (_) => setState(() => _vista = 'reponer'),
                        ),
                        if (vencer > 0 || _vista == 'vencer')
                          ChoiceChip(
                            key: const ValueKey('filtro_vencer'),
                            avatar: Icon(Icons.event_busy_outlined, size: 18, color: p.gastos),
                            label: Text('Por vencer ($vencer)'),
                            selected: _vista == 'vencer',
                            onSelected: (_) => setState(() => _vista = 'vencer'),
                          ),
                      ]),
                      const SizedBox(height: 12),
                      if (lista.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                              switch (_vista) {
                                'reponer' => 'Nada por reponer. ¡Todo está surtido!',
                                'vencer' => 'Nada vence en los próximos 30 días.',
                                _ => 'Ningún producto coincide.',
                              },
                              textAlign: TextAlign.center,
                              style: t.bodyLarge),
                        )
                      else if (esEscritorio(context))
                        _TablaProductos(lista: lista, veCostos: veCostos)
                      else
                        Card(
                          child: Column(children: [
                            for (final (i, x) in lista.indexed) ...[
                              if (i > 0) const Divider(indent: 72),
                              _FilaProducto(x: x),
                            ],
                          ]),
                        ),
                    ]),
    );
  }
}

class _Dato extends StatelessWidget {
  final String titulo, valor;
  final Color color;
  final IconData? icono;
  const _Dato(
      {required this.titulo,
      required this.valor,
      required this.color,
      this.icono});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo,
              style: t.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Row(children: [
            if (icono != null) ...[
              Icon(icono, size: 20, color: color),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(valor,
                    style: cifras(t.titleLarge?.copyWith(color: color))),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// Etiqueta del stock: verde normal, ámbar bajo, coral agotado (con texto).
class EtiquetaStock extends StatelessWidget {
  final ProductoStock x;
  const EtiquetaStock({super.key, required this.x});
  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    final t = Theme.of(context).textTheme;
    final (Color fondo, Color tinta, String texto) = x.esServicio
        ? (p.asistenteFondo, p.asistente, 'Servicio')
        : x.agotado
            ? (p.gastosFondo, p.gastos, 'Agotado')
            : x.bajo
                ? (
                    p.fiadoFondo,
                    p.fiado,
                    'Quedan ${cantidadConUnidad(x.stock, x.unidad)}'
                  )
                : (
                    p.ventasFondo,
                    p.ventas,
                    x.unidad == 'und'
                        ? '${cantidadTexto(x.stock)} und.'
                        : cantidadConUnidad(x.stock, x.unidad)
                  );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(10)),
      child: Text(texto, style: cifras(t.labelLarge?.copyWith(color: tinta))),
    );
  }
}

class _FilaProducto extends StatelessWidget {
  final ProductoStock x;
  const _FilaProducto({required this.x});

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    final (Color fondo, Color tinta) = x.agotado
        ? (p.gastosFondo, p.gastos)
        : x.bajo
            ? (p.fiadoFondo, p.fiado)
            : (p.ventasFondo, p.ventas);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
            color: fondo, borderRadius: BorderRadius.circular(14)),
        child: Icon(Icons.inventory_2_outlined, color: tinta),
      ),
      title: Text(x.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
          '${x.unidad == 'und' ? cop(x.precio) : precioConUnidad(x.precio, x.unidad)}${x.tienePrecioMayor ? ' · por mayor ${cop(x.precioMayor)}' : ''}${x.costo > 0 && LocalDb.instance.puede(Permiso.verUtilidad) ? ' · gana ${(x.margen * 100).round()} %' : ''}${x.codigo.isEmpty ? '' : ' · ${x.codigo}'}${x.porVencer(DateTime.now()) ? ' · ${textoVence(x, DateTime.now())}' : ''}'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        EtiquetaStock(x: x),
        const SizedBox(width: 6),
        iconoSync(x.sync),
      ]),
      onTap: () => _acciones(context, x),
    );
  }
}

/// Las acciones de un producto (para abrirlas desde el buscador global).
Future<void> accionesProducto(BuildContext context, ProductoStock x) => _acciones(context, x);

Future<void> _acciones(BuildContext context, ProductoStock x) async {
  final db = LocalDb.instance;
  final entra = db.puede(Permiso.entradaInventario);
  final ajusta = db.puede(Permiso.ajusteInventario);
  final edita = db.puede(Permiso.editarProductos);
  // El kárdex lo ve quien ve el inventario (también el contador).
  final kardex = !x.esServicio && db.puede(Permiso.verProductos);
  if (!entra && !ajusta && !edita && !kardex) return;
  final accion = await showModalBottomSheet<String>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          title: Text(x.nombre, style: Theme.of(c).textTheme.titleLarge),
          subtitle: Text(x.esServicio
              ? 'Servicio · ${cop(x.precio)}'
              : 'Hay ${cantidadTexto(x.stock)} · mínimo ${cantidadTexto(x.minimo)}'),
          trailing: EtiquetaStock(x: x),
        ),
        const Divider(),
        if (!x.esServicio) ...[
          if (entra)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Llegó mercancía'),
              subtitle: const Text('Suma unidades al stock'),
              onTap: () => Navigator.pop(c, 'entrada'),
            ),
          if (ajusta)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('Corregir por conteo'),
              subtitle: const Text('Ajusta a lo que hay de verdad'),
              onTap: () => Navigator.pop(c, 'ajuste'),
            ),
        ],
        if (kardex)
          ListTile(
            key: const ValueKey('accion_kardex'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: const Icon(Icons.history),
            title: const Text('Historial (kárdex)'),
            subtitle: const Text('Entradas, ventas y ajustes con su saldo'),
            onTap: () => Navigator.pop(c, 'kardex'),
          ),
        if (edita) ...[
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Editar precio, costo o mínimo'),
            onTap: () => Navigator.pop(c, 'editar'),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: Icon(Icons.delete_outline,
                color: Theme.of(c).colorScheme.error),
            title: Text('Eliminar producto',
                style: TextStyle(color: Theme.of(c).colorScheme.error)),
            onTap: () => Navigator.pop(c, 'eliminar'),
          ),
        ],
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (accion == null || !context.mounted) return;
  switch (accion) {
    case 'kardex':
      await Navigator.of(context).push(rutaVertex(KardexPage(producto: x), maxAncho: 960));
    case 'editar':
      await mostrarFormProducto(context, producto: x);
    case 'eliminar':
      final ok = await confirmar(context, 'Eliminar producto',
          '¿Eliminar ${x.nombre}? Sus ventas se conservan en el historial.',
          si: 'Eliminar');
      if (!ok) return;
      await LocalDb.instance.deleteProducto(x.id);
      SyncService.instance.sync();
      avisar('Producto eliminado');
    default:
      final entrada = accion == 'entrada';
      final n = await _pedirCantidad(context,
          titulo: entrada ? 'Llegó mercancía' : 'Corregir por conteo',
          etiqueta: entrada
              ? '¿Cuántas unidades llegaron?'
              : '¿Cuántas hay de verdad?',
          inicial: entrada ? null : cantidadTexto(x.stock < 0 ? 0 : x.stock));
      if (n == null) return;
      final cambio = entrada ? n : n - x.stock;
      if (cambio == 0) {
        avisar('El stock ya estaba en ${cantidadTexto(n)}');
        return;
      }
      await LocalDb.instance.moverStock(x.id, cambio,
          motivo: entrada ? 'entrada' : 'ajuste', costo: x.costo);
      SyncService.instance.sync();
      avisar(entrada
          ? 'Se sumaron ${cantidadTexto(n)} a ${x.nombre}'
          : 'Stock de ${x.nombre} corregido a ${cantidadTexto(n)}');
  }
}

double? _numero(String s) {
  final t = s.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

Future<double?> _pedirCantidad(BuildContext context,
    {required String titulo, required String etiqueta, String? inicial}) async {
  final ctrl = TextEditingController(text: inicial ?? '');
  final r = await showDialog<double>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(titulo),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: etiqueta),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final n = _numero(ctrl.text);
            if (n == null || n < 0) return;
            Navigator.pop(c, n);
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return r;
}

/// Crear (producto == null) o editar un producto.
Future<void> mostrarFormProducto(BuildContext context,
    {ProductoStock? producto}) async {
  final r = await showModalBottomSheet<_DatosProducto>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FormProducto(producto: producto),
  );
  if (r == null) return;
  await LocalDb.instance.saveProducto(r.nombre,
      precio: r.precio,
      costo: r.costo,
      minimo: r.minimo,
      stockInicial: r.stock,
      codigo: r.codigo,
      unidad: r.unidad,
      iva: r.iva,
      precioMayor: r.precioMayor,
      cantidadMayor: r.cantidadMayor,
      vence: r.vence,
      id: producto?.id);
  SyncService.instance.sync();
  avisar(producto == null ? 'Producto guardado' : 'Producto actualizado');
}

class _DatosProducto {
  final String nombre;
  final double precio, costo, minimo, stock;
  final String codigo, unidad;

  /// Porcentaje de IVA (−1 = sin definir).
  final double iva;

  /// Precio por mayor y desde qué cantidad (0 = no hay); vencimiento
  /// «AAAA-MM-DD» ('' = no se lleva).
  final double precioMayor, cantidadMayor;
  final String vence;
  const _DatosProducto(this.nombre, this.precio, this.costo, this.minimo,
      this.stock, this.codigo, this.unidad, this.iva,
      {this.precioMayor = 0, this.cantidadMayor = 0, this.vence = ''});
}

class _FormProducto extends StatefulWidget {
  final ProductoStock? producto;
  const _FormProducto({this.producto});
  @override
  State<_FormProducto> createState() => _FormProductoState();
}

class _FormProductoState extends State<_FormProducto> {
  final _form = GlobalKey<FormState>();
  late final _nombre =
      TextEditingController(text: widget.producto?.nombre ?? '');
  late final _precio = TextEditingController(
      text: widget.producto == null
          ? ''
          : cop(widget.producto!.precio).substring(1));
  late final _costo = TextEditingController(
      text: (widget.producto?.costo ?? 0) > 0
          ? cop(widget.producto!.costo).substring(1)
          : '');
  late final _minimo = TextEditingController(
      text: (widget.producto?.minimo ?? 0) > 0
          ? cantidadTexto(widget.producto!.minimo)
          : '');
  final _stock = TextEditingController();
  late final _iva = TextEditingController(
      text: (widget.producto?.iva ?? -1) >= 0 ? cantidadTexto(widget.producto!.iva) : '');
  late final _codigo =
      TextEditingController(text: widget.producto?.codigo ?? '');
  late String _unidad =
      widget.producto?.unidad ?? LocalDb.instance.modo.value.unidadInicial;
  late final _precioMayor = TextEditingController(
      text: (widget.producto?.precioMayor ?? 0) > 0
          ? cop(widget.producto!.precioMayor).substring(1)
          : '');
  late final _cantidadMayor = TextEditingController(
      text: (widget.producto?.cantidadMayor ?? 0) > 0
          ? cantidadTexto(widget.producto!.cantidadMayor)
          : '');
  late String _vence = widget.producto?.vence ?? '';
  bool get _servicio => _unidad == 'serv';

  @override
  void dispose() {
    for (final c in [_nombre, _precio, _costo, _minimo, _stock, _codigo, _iva, _precioMayor, _cantidadMayor]) {
      c.dispose();
    }
    super.dispose();
  }

  void _guardar() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
        context,
        _DatosProducto(
          _nombre.text.trim().replaceAll(RegExp(r'\s+'), ' '),
          parseMonto(_precio.text) ?? 0,
          _costo.text.trim().isEmpty ? 0 : (parseMonto(_costo.text) ?? 0),
          _numero(_minimo.text) ?? 0,
          _numero(_stock.text) ?? 0,
          _codigo.text.replaceAll(RegExp(r'\s'), ''),
          _unidad,
          _iva.text.trim().isEmpty ? -1 : (_numero(_iva.text) ?? -1),
          precioMayor: parseMonto(_precioMayor.text) ?? 0,
          cantidadMayor: _numero(_cantidadMayor.text) ?? 0,
          vence: _servicio ? '' : _vence,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final nuevo = widget.producto == null;
    final modo = LocalDb.instance.modo.value;
    // Solo se ofrecen las formas de vender que el negocio usa (y la actual).
    final unidades = [
      if (modo.vendeProductos || _unidad == 'und') 'und',
      if ((modo.vendeProductos && modo.gramera) || _unidad == 'kg') 'kg',
      if ((modo.vendeProductos && modo.gramera) || _unidad == 'lb') 'lb',
      if (modo.vendeProductos || _unidad == 'm') 'm',
      if (modo.vendeProductos || _unidad == 'l') 'l',
      if (modo.vendeProductos || _unidad == 'gal') 'gal',
      if (modo.vendeProductos || _unidad == 'caja') 'caja',
      if (modo.vendeProductos || _unidad == 'paq') 'paq',
      if (modo.vendeServicios || _unidad == 'serv') 'serv',
    ];
    final que = _servicio ? 'servicio' : 'producto';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Form(
          key: _form,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(nuevo ? 'Nuevo $que' : 'Editar $que', style: t.headlineSmall),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nombre,
              autofocus: nuevo,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 80,
              decoration: InputDecoration(
                  labelText: 'Nombre',
                  hintText:
                      'Ej.: ${ejemplosPara(LocalDb.instance.tipoNegocio.value).producto}',
                  counterText: ''),
              validator: (v) => (v ?? '').trim().length < 2
                  ? 'Escribe el nombre del producto'
                  : null,
            ),
            const SizedBox(height: 12),
            if (unidades.length > 1) ...[
              DropdownButtonFormField<String>(
                key: const ValueKey('campo_unidad'),
                initialValue: _unidad,
                decoration: const InputDecoration(labelText: 'Se vende por'),
                items: [
                  for (final u in unidades)
                    DropdownMenuItem(
                      value: u,
                      child: Text(switch (u) {
                        'kg' || 'lb' => '${nombresUnidad[u]} (gramera)',
                        'm' || 'l' || 'gal' => '${nombresUnidad[u]} (se vende en fracciones)',
                        _ => nombresUnidad[u]!,
                      }),
                    ),
                ],
                onChanged: (u) => setState(() => _unidad = u ?? _unidad),
              ),
              const SizedBox(height: 12),
            ],
            if (_servicio)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                    'Los servicios no llevan inventario: no se agotan ni piden mínimo.',
                    style: t.bodySmall),
              ),
            if (!_servicio && (modo.codigos || _codigo.text.isNotEmpty)) ...[
              TextFormField(
                controller: _codigo,
                keyboardType: TextInputType.number,
                maxLength: 40,
                decoration: InputDecoration(
                  labelText: _unidad == 'und'
                      ? 'Código de barras (opcional)'
                      : 'Código en la gramera (PLU, opcional)',
                  helperText: _unidad == 'und'
                      ? 'Escanéalo o escríbelo; sirve también con lector USB'
                      : 'El número del producto en la etiqueta de la gramera',
                  counterText: '',
                  suffixIcon: IconButton(
                    tooltip: 'Escanear',
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: () async {
                      final c = await escanearCodigo(context);
                      if (c == null) return;
                      final b = leerEtiquetaBalanza(c);
                      // Si se escanea una etiqueta de gramera, se guarda su PLU.
                      setState(
                          () => _codigo.text = b?.plu ?? normalizarCodigo(c));
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _precio,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: _unidad == 'und' || _servicio
                          ? 'Precio de venta'
                          : 'Precio por ${nombresUnidad[_unidad]!.toLowerCase()}',
                      prefixText: r'$ '),
                  validator: (v) => parseMonto(v ?? '') == null
                      ? 'Precio mayor a cero'
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _costo,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Costo (opcional)', prefixText: r'$ '),
                  validator: (v) =>
                      (v ?? '').trim().isNotEmpty && parseMonto(v!) == null
                          ? 'Costo no válido'
                          : null,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('campo_iva'),
              controller: _iva,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'IVA % (para la factura electrónica)',
                suffixText: '%',
                helperText: 'El que le corresponde a este producto según tu contador. Vacío si aún no lo sabes.',
                helperMaxLines: 2,
              ),
              validator: (v) {
                if ((v ?? '').trim().isEmpty) return null;
                final x = _numero(v!);
                return x == null || x < 0 || x > 100 ? 'Escribe un porcentaje de 0 a 100' : null;
              },
            ),
            if (!_servicio) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    key: const ValueKey('campo_precio_mayor'),
                    controller: _precioMayor,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Precio por mayor (opcional)', prefixText: r'$ '),
                    validator: (v) {
                      final hay = (v ?? '').trim().isNotEmpty;
                      if (!hay) return null;
                      final x = parseMonto(v!);
                      if (x == null || x <= 0) return 'Precio no válido';
                      final normal = parseMonto(_precio.text);
                      if (normal != null && x >= normal) return 'Debe ser menor que el precio normal';
                      if ((_numero(_cantidadMayor.text) ?? 0) <= 0) return 'Di desde cuánto aplica';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    key: const ValueKey('campo_cantidad_mayor'),
                    controller: _cantidadMayor,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText: 'Desde',
                        suffixText: _unidad == 'und' ? 'unidades' : _unidad,
                        hintText: 'Ej.: 12'),
                    validator: (v) => (v ?? '').trim().isNotEmpty && ((_numero(v!) ?? 0) <= 0)
                        ? 'Cantidad no válida'
                        : null,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              _CampoVence(
                valor: _vence,
                onChanged: (v) => setState(() => _vence = v),
              ),
              const SizedBox(height: 12),
              Row(children: [
                if (nuevo) ...[
                  Expanded(
                    child: TextFormField(
                      controller: _stock,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: '¿Cuántos tienes?'),
                      validator: (v) => (v ?? '').trim().isNotEmpty &&
                              ((_numero(v!) ?? -1) < 0)
                          ? 'Cantidad no válida'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: TextFormField(
                    controller: _minimo,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Avisar cuando queden', hintText: 'Ej.: 5'),
                    validator: (v) =>
                        (v ?? '').trim().isNotEmpty && ((_numero(v!) ?? -1) < 0)
                            ? 'Cantidad no válida'
                            : null,
                  ),
                ),
              ]),
            ],
            const SizedBox(height: 20),
            FilledButton(
                onPressed: _guardar,
                child: Text(nuevo ? 'Guardar $que' : 'Guardar cambios')),
          ]),
        ),
      ),
    );
  }
}


/// En el computador el inventario se ve como tabla: código, producto,
/// precio, costo y margen (si el rol los ve), stock e IVA. Un clic abre las
/// mismas acciones que en el celular (entrada, ajuste, editar).
class _TablaProductos extends StatelessWidget {
  final List<ProductoStock> lista;
  final bool veCostos;
  const _TablaProductos({required this.lista, required this.veCostos});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Paleta.of(context);
    final cs = Theme.of(context).colorScheme;
    final cab = t.labelLarge?.copyWith(color: cs.onSurfaceVariant);
    Widget celda(String texto, {int flex = 2, bool derecha = false, TextStyle? estilo}) => Expanded(
          flex: flex,
          child: Text(texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: derecha ? TextAlign.right : TextAlign.left,
              style: estilo),
        );
    Widget fila(List<Widget> hijos) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            for (final (i, h) in hijos.indexed) ...[if (i > 0) const SizedBox(width: 12), h],
          ]),
        );
    return Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        fila([
          celda('Código', estilo: cab),
          celda('Producto', flex: 5, estilo: cab),
          celda('Precio', derecha: true, estilo: cab),
          if (veCostos) ...[
            celda('Costo', derecha: true, estilo: cab),
            celda('Margen', flex: 1, derecha: true, estilo: cab),
          ],
          celda('Stock', derecha: true, estilo: cab),
          celda('IVA', flex: 1, derecha: true, estilo: cab),
          celda('Vence', derecha: true, estilo: cab),
        ]),
        const Divider(height: 1),
        for (final (i, x) in lista.indexed) ...[
          if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
          InkWell(
            key: ValueKey('tabla_${x.nombre}'),
            onTap: () => _acciones(context, x),
            child: fila([
              celda(x.codigo.isEmpty ? '—' : x.codigo,
                  estilo: t.bodyMedium?.copyWith(color: cs.outline)),
              celda(x.nombre, flex: 5, estilo: t.bodyLarge),
              celda(precioConUnidad(x.precio, x.unidad), derecha: true, estilo: cifras(t.bodyLarge)),
              if (veCostos) ...[
                celda(x.costo > 0 ? cop(x.costo) : '—', derecha: true, estilo: cifras(t.bodyMedium)),
                celda(x.costo > 0 && x.precio > 0 ? '${(x.margen * 100).round()} %' : '—',
                    flex: 1,
                    derecha: true,
                    estilo: cifras(t.bodyMedium?.copyWith(color: x.margen < 0 ? p.gastos : null))),
              ],
              Expanded(
                flex: 2,
                child: Align(alignment: Alignment.centerRight, child: EtiquetaStock(x: x)),
              ),
              celda(x.iva < 0 ? '—' : '${cantidadTexto(x.iva)} %',
                  flex: 1, derecha: true, estilo: t.bodyMedium),
              celda(textoVence(x, DateTime.now()) ?? '—',
                  derecha: true,
                  estilo: t.bodyMedium?.copyWith(
                      color: x.porVencer(DateTime.now()) ? p.gastos : null,
                      fontWeight: x.porVencer(DateTime.now()) ? FontWeight.w700 : null)),
            ]),
          ),
        ],
      ]),
    );
  }
}

/// Fecha de vencimiento (opcional): alimentos, droguería, agro. Se elige en
/// el calendario; la app avisa 30 días antes.
class _CampoVence extends StatelessWidget {
  final String valor;
  final ValueChanged<String> onChanged;
  const _CampoVence({required this.valor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final f = DateTime.tryParse(valor);
    String iso(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Vence (opcional)',
        helperText: 'Para alimentos o medicamentos: la app avisa 30 días antes.',
      ),
      child: Row(children: [
        Expanded(
          child: Text(f == null ? 'Sin fecha' : DateFormat('d MMM y', 'es_CO').format(f)),
        ),
        TextButton(
          key: const ValueKey('campo_vence'),
          onPressed: () async {
            final hoy = DateTime.now();
            final d = await showDatePicker(
              context: context,
              initialDate: f ?? hoy.add(const Duration(days: 90)),
              firstDate: DateTime(hoy.year - 1),
              lastDate: DateTime(hoy.year + 10),
              helpText: 'Fecha de vencimiento',
            );
            if (d != null) onChanged(iso(d));
          },
          child: Text(f == null ? 'Elegir' : 'Cambiar'),
        ),
        if (f != null)
          IconButton(
            tooltip: 'Quitar la fecha',
            onPressed: () => onChanged(''),
            icon: const Icon(Icons.close),
          ),
      ]),
    );
  }
}

/// «Vence en 12 días», «Vence hoy», «Venció hace 3 días» o la fecha; null
/// si no se lleva.
String? textoVence(ProductoStock x, DateTime hoy) {
  final n = x.diasParaVencer(hoy);
  if (n == null) return null;
  if (n < 0) return n == -1 ? 'Venció ayer' : 'Venció hace ${-n} días';
  if (n == 0) return 'Vence hoy';
  if (n <= 30) return n == 1 ? 'Vence mañana' : 'Vence en $n días';
  return DateFormat('d MMM y', 'es_CO').format(DateTime.parse(x.vence));
}

/// Importar productos copiados de Excel: se pegan, se revisan y se guardan.
Future<void> importarDesdeExcel(BuildContext context) async {
  final r = await showDialog<List<FilaImportada>>(
    context: context,
    builder: (_) => const _DialogoImportar(),
  );
  if (r == null || r.isEmpty) return;
  final n = await LocalDb.instance.importarProductos(r);
  SyncService.instance.sync();
  avisar([
    if (n.nuevos > 0) n.nuevos == 1 ? '1 producto nuevo' : '${n.nuevos} productos nuevos',
    if (n.actualizados > 0)
      n.actualizados == 1 ? '1 actualizado' : '${n.actualizados} actualizados',
  ].join(' y '));
}

class _DialogoImportar extends StatefulWidget {
  const _DialogoImportar();
  @override
  State<_DialogoImportar> createState() => _DialogoImportarState();
}

class _DialogoImportarState extends State<_DialogoImportar> {
  final _texto = TextEditingController();
  ResultadoImportar? _r;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = _r;
    return AlertDialog(
      title: const Text('Traer productos de Excel'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(
                'En Excel selecciona las columnas con la fila de títulos, cópialas (Ctrl+C) y pégalas aquí '
                '(Ctrl+V). Títulos que entiendo: Nombre, Precio, Costo, Stock, Código, Unidad, Mínimo, IVA, '
                'Precio por mayor y Desde.',
                style: t.bodyMedium),
            const SizedBox(height: 4),
            Text(
                'Si un producto ya existe (mismo código o mismo nombre) se actualizan su precio y sus datos; '
                'su stock no se cambia.',
                style: t.bodySmall),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('importar_texto'),
              controller: _texto,
              minLines: 6,
              maxLines: 12,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Nombre   Precio   Costo   Stock   Código\nCable 12   4200   3000   500   7701234',
                alignLabelWithHint: true,
              ),
              onChanged: (_) => setState(() => _r = null),
            ),
            if (r != null) ...[
              const SizedBox(height: 12),
              Text(
                  r.filas.isEmpty
                      ? 'No encontré productos para importar.'
                      : 'Listos para importar: ${r.filas.length} ${r.filas.length == 1 ? 'producto' : 'productos'}.',
                  key: const ValueKey('importar_resumen'),
                  style: t.titleSmall),
              for (final f in r.filas.take(5))
                Text('• ${f.nombre} · ${precioConUnidad(f.precio, f.unidad)}', style: t.bodySmall),
              if (r.filas.length > 5) Text('… y ${r.filas.length - 5} más', style: t.bodySmall),
              if (r.errores.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Estas filas no entran (corrígelas en Excel y vuelve a pegarlas):',
                    style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error)),
                for (final e in r.errores.take(8)) Text('• $e', style: t.bodySmall),
                if (r.errores.length > 8) Text('… y ${r.errores.length - 8} más', style: t.bodySmall),
              ],
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        if (r == null || r.filas.isEmpty)
          FilledButton(
            key: const ValueKey('importar_revisar'),
            onPressed: () => setState(() => _r = leerProductosPegados(_texto.text)),
            child: const Text('Revisar'),
          )
        else
          FilledButton(
            key: const ValueKey('importar_guardar'),
            onPressed: () => Navigator.pop(context, r.filas),
            child: Text('Importar ${r.filas.length}'),
          ),
      ],
    );
  }
}

/// Etiquetas de precio (hoja carta 3 × 8, con código de barras) o lista de
/// precios en PDF, de los productos que se ven (el buscador y los filtros
/// sirven para elegir cuáles).
Future<void> imprimirPrecios(BuildContext context, List<ProductoStock> lista) async {
  final productos = [for (final p in lista) if (p.precio > 0) p];
  if (productos.isEmpty) {
    avisar('No hay productos con precio para imprimir');
    return;
  }
  final r = await showDialog<(String, int)>(
    context: context,
    builder: (_) => _DialogoPrecios(n: productos.length),
  );
  if (r == null) return;
  final negocio = await LocalDb.instance.perfilNegocio();
  final fecha = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final pdf = r.$1 == 'etiquetas'
      ? PdfListo(
          nombre: 'etiquetas_$fecha.pdf',
          generar: (f) => pdfEtiquetas(productos, copias: r.$2, negocio: negocio.nombre.trim(), formato: f))
      : PdfListo(
          nombre: 'lista_de_precios_$fecha.pdf',
          generar: (f) => pdfListaPrecios(productos,
              negocio: negocio.nombre.trim(), contacto: negocio.telefono.trim(), formato: f));
  try {
    await pdf.imprimir();
  } catch (_) {
    try {
      await pdf.compartir();
    } catch (_) {
      avisar('No se pudo abrir el PDF en este equipo');
    }
  }
}

class _DialogoPrecios extends StatefulWidget {
  final int n;
  const _DialogoPrecios({required this.n});
  @override
  State<_DialogoPrecios> createState() => _DialogoPreciosState();
}

class _DialogoPreciosState extends State<_DialogoPrecios> {
  String _que = 'etiquetas';
  int _copias = 1;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final n = widget.n;
    return AlertDialog(
      title: const Text('Imprimir precios'),
      content: SizedBox(
        width: 440,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('De los $n ${n == 1 ? 'producto' : 'productos'} que se ven ahora (usa el buscador para elegir).',
              style: t.bodySmall),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: _que,
            onChanged: (v) => setState(() => _que = v ?? _que),
            child: const Column(children: [
              RadioListTile(
                key: ValueKey('op_etiquetas'),
                value: 'etiquetas',
                title: Text('Etiquetas de precio'),
                subtitle: Text('Hoja carta de 24 etiquetas, con código de barras'),
              ),
              RadioListTile(
                key: ValueKey('op_lista'),
                value: 'lista',
                title: Text('Lista de precios'),
                subtitle: Text('PDF para enviar a tus clientes (sin costos)'),
              ),
            ]),
          ),
          if (_que == 'etiquetas')
            Row(children: [
              const Expanded(child: Text('Copias de cada etiqueta')),
              IconButton(
                onPressed: _copias > 1 ? () => setState(() => _copias--) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_copias', style: t.titleMedium),
              IconButton(
                onPressed: _copias < 50 ? () => setState(() => _copias++) : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ]),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          key: const ValueKey('generar_precios'),
          onPressed: () => Navigator.pop(context, (_que, _copias)),
          child: const Text('Generar PDF'),
        ),
      ],
    );
  }
}

