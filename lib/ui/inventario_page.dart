import 'package:flutter/material.dart';
import '../domain/ejemplos.dart';
import '../data/local_db.dart';
import '../domain/roles.dart';
import '../data/sync_service.dart';
import '../domain/formato.dart';
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
  bool _soloReponer = false;

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
    final valor =
        _items.fold(0.0, (s, x) => s + (x.stock > 0 ? x.stock * x.costo : 0));
    final f = _filtro.trim().toLowerCase();
    final lista = _items
        .where((x) => !_soloReponer || x.agotado || x.bajo)
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
                      ? FilledButton.icon(
                          onPressed: () => mostrarFormProducto(context),
                          icon: const Icon(Icons.add_box_outlined),
                          label: const Text('Agregar el primero'),
                        )
                      : null,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
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
                      TextField(
                        onChanged: (v) => setState(() => _filtro = v),
                        decoration: const InputDecoration(
                            hintText: 'Buscar producto',
                            prefixIcon: Icon(Icons.search)),
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        ChoiceChip(
                          label: Text('Todos (${_items.length})'),
                          selected: !_soloReponer,
                          onSelected: (_) =>
                              setState(() => _soloReponer = false),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text('Por reponer ($reponer)'),
                          selected: _soloReponer,
                          onSelected: (_) =>
                              setState(() => _soloReponer = true),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      if (lista.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                              _soloReponer
                                  ? 'Nada por reponer. ¡Todo está surtido!'
                                  : 'Ningún producto coincide.',
                              textAlign: TextAlign.center,
                              style: t.bodyLarge),
                        )
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
          '${cop(x.precio)}${esPorPeso(x.unidad) ? '/${x.unidad}' : ''}${x.costo > 0 && LocalDb.instance.puede(Permiso.verUtilidad) ? ' · gana ${(x.margen * 100).round()} %' : ''}${x.codigo.isEmpty ? '' : ' · ${x.codigo}'}'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        EtiquetaStock(x: x),
        const SizedBox(width: 6),
        iconoSync(x.sync),
      ]),
      onTap: () => _acciones(context, x),
    );
  }
}

Future<void> _acciones(BuildContext context, ProductoStock x) async {
  final db = LocalDb.instance;
  final entra = db.puede(Permiso.entradaInventario);
  final ajusta = db.puede(Permiso.ajusteInventario);
  final edita = db.puede(Permiso.editarProductos);
  if (!entra && !ajusta && !edita) return; // el contador solo consulta
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
  const _DatosProducto(this.nombre, this.precio, this.costo, this.minimo,
      this.stock, this.codigo, this.unidad, this.iva);
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
  bool get _servicio => _unidad == 'serv';

  @override
  void dispose() {
    for (final c in [_nombre, _precio, _costo, _minimo, _stock, _codigo, _iva]) {
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
        ));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final nuevo = widget.producto == null;
    final modo = LocalDb.instance.modo.value;
    // Solo se ofrecen las formas de vender que el negocio usa (y la actual).
    final segmentos = [
      if (modo.vendeProductos || _unidad == 'und')
        const ButtonSegment(value: 'und', label: Text('Unidad')),
      if ((modo.vendeProductos && modo.gramera) || _unidad == 'kg')
        const ButtonSegment(
            value: 'kg', icon: Icon(Icons.scale_outlined), label: Text('Kilo')),
      if ((modo.vendeProductos && modo.gramera) || _unidad == 'lb')
        const ButtonSegment(
            value: 'lb',
            icon: Icon(Icons.scale_outlined),
            label: Text('Libra')),
      if (modo.vendeServicios || _unidad == 'serv')
        const ButtonSegment(
            value: 'serv',
            icon: Icon(Icons.handyman_outlined),
            label: Text('Servicio')),
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
            if (segmentos.length > 1) ...[
              Text('Se vende por', style: t.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: segmentos,
                selected: {_unidad},
                onSelectionChanged: (s) => setState(() => _unidad = s.first),
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
                      labelText: esPorPeso(_unidad)
                          ? 'Precio por $_unidad'
                          : 'Precio de venta',
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
