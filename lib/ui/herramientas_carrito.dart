part of 'herramientas_page.dart';

// Lista de productos con cantidades, compartida por el pedido al proveedor y las cotizaciones.

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
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleSmall),
                    Text(
                        '${precioConUnidad(usarCosto ? p.costo : p.precio, p.unidad)}'
                        '${p.esServicio ? '' : ' · hay ${cantidadConUnidad(p.stock, p.unidad)}'}',
                        style: t.bodySmall
                            ?.copyWith(color: esquema.onSurfaceVariant)),
                  ]),
            ),
            IconButton(
              tooltip: 'Quitar',
              onPressed: () {
                final n = c - (esFraccionable(p.unidad) ? 0.25 : 1);
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
                width: esFraccionable(p.unidad) ? 64 : 32,
                child: Text(cantidadConUnidad(c, p.unidad),
                    textAlign: TextAlign.center, style: cifras(t.titleSmall))),
            IconButton(
              tooltip: 'Agregar',
              onPressed: () {
                cantidades[p.id] = c + (esFraccionable(p.unidad) ? 0.25 : 1);
                onCambio();
              },
              icon: const Icon(Icons.add_circle_outline),
            ),
          ]),
        ),
    ]);
  }
}

/// Lee un código (cámara, lector o teclado) y suma el producto a [cant].
/// Con etiqueta de gramera suma el peso leído.
Future<void> agregarPorCodigo(
    BuildContext context,
    List<ProductoStock> productos,
    Map<String, double> cant,
    VoidCallback alCambiar) async {
  final c = await escanearCodigo(context);
  if (c == null) return;
  final r = buscarPorCodigo(productos, c);
  if (r == null) {
    avisar('No hay un producto con el código $c. Agrégalo en Inventario.');
    return;
  }
  final p = r.producto;
  cant[p.id] = (cant[p.id] ?? 0) + (r.cantidad ?? 1);
  alCambiar();
  avisar(r.cantidad == null
      ? '${p.nombre} agregado'
      : '${p.nombre}: ${cantidadConUnidad(r.cantidad!, p.unidad)}');
}

Future<ProductoStock?> _elegirProducto(
    BuildContext context, List<ProductoStock> l) {
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
