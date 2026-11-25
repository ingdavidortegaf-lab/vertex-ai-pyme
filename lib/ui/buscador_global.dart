import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/local_db.dart';
import '../domain/codigos.dart';
import '../domain/formato.dart';
import '../domain/resumen.dart';
import '../domain/roles.dart';
import 'tema.dart';

/// Lo que se encontró con el buscador global.
sealed class ResultadoBusqueda {
  const ResultadoBusqueda();
}

class IrASeccion extends ResultadoBusqueda {
  final int indice;
  const IrASeccion(this.indice);
}

class AbrirProducto extends ResultadoBusqueda {
  final ProductoStock producto;
  const AbrirProducto(this.producto);
}

class AbrirCliente extends ResultadoBusqueda {
  final String clienteId;
  const AbrirCliente(this.clienteId);
}

/// Buscador global del computador (Ctrl+K): productos por nombre o código,
/// clientes y secciones, con las flechas y Enter. Solo muestra lo que el rol
/// puede ver.
Future<ResultadoBusqueda?> buscarGlobal(
    BuildContext context, List<String> secciones) async {
  final db = LocalDb.instance;
  final productos = db.puede(Permiso.verProductos)
      ? await db.productos()
      : const <ProductoStock>[];
  final clientes = db.puede(Permiso.verClientes)
      ? await db.clientesConSaldo()
      : const <ClienteSaldo>[];
  if (!context.mounted) return null;
  return showDialog<ResultadoBusqueda>(
    context: context,
    builder: (_) => _Buscador(
        secciones: secciones, productos: productos, clientes: clientes),
  );
}

class _Item {
  final IconData icono;
  final String titulo, detalle;
  final ResultadoBusqueda r;
  const _Item(this.icono, this.titulo, this.detalle, this.r);
}

class _Buscador extends StatefulWidget {
  final List<String> secciones;
  final List<ProductoStock> productos;
  final List<ClienteSaldo> clientes;
  const _Buscador(
      {required this.secciones,
      required this.productos,
      required this.clientes});
  @override
  State<_Buscador> createState() => _BuscadorState();
}

class _BuscadorState extends State<_Buscador> {
  String _q = '';
  int _sel = 0;

  List<_Item> get _items {
    final q = _q.trim().toLowerCase();
    final out = <_Item>[];
    for (final (i, s) in widget.secciones.indexed) {
      if (q.isEmpty || s.toLowerCase().contains(q)) {
        out.add(_Item(Icons.arrow_forward, s, 'Sección', IrASeccion(i)));
      }
    }
    if (q.isEmpty) return out;
    for (final p in widget.productos) {
      if (p.nombre.toLowerCase().contains(q) ||
          (p.codigo.isNotEmpty && p.codigo.contains(q))) {
        out.add(_Item(
            Icons.inventory_2_outlined,
            p.nombre,
            '${precioConUnidad(p.precio, p.unidad)}${p.esServicio ? '' : ' · hay ${cantidadConUnidad(p.stock, p.unidad)}'}',
            AbrirProducto(p)));
      }
      if (out.length > 40) break;
    }
    for (final c in widget.clientes) {
      if (c.nombre.toLowerCase().contains(q)) {
        out.add(_Item(
            Icons.person_outline,
            c.nombre,
            c.saldo > 0 ? 'Debe ${cop(c.saldo)}' : 'Cliente',
            AbrirCliente(c.id)));
      }
      if (out.length > 60) break;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final l = _items;
    final sel = l.isEmpty ? 0 : _sel.clamp(0, l.length - 1);
    final t = Theme.of(context).textTheme;
    final pal = Paleta.of(context);
    return Dialog(
      alignment: const Alignment(0, -0.6),
      child: SizedBox(
        width: 620,
        height: 460,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Focus(
              onKeyEvent: (_, e) {
                if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
                  return KeyEventResult.ignored;
                }
                if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
                  setState(() =>
                      _sel = (sel + 1).clamp(0, l.isEmpty ? 0 : l.length - 1));
                  return KeyEventResult.handled;
                }
                if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
                  setState(() =>
                      _sel = (sel - 1).clamp(0, l.isEmpty ? 0 : l.length - 1));
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                key: const ValueKey('buscador_global'),
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Buscar producto, código, cliente o sección',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() {
                  _q = v;
                  _sel = 0;
                }),
                onSubmitted: (_) {
                  if (l.isNotEmpty) Navigator.pop(context, l[sel].r);
                },
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: l.isEmpty
                ? Center(child: Text('Sin resultados', style: t.bodyMedium))
                : ListView.builder(
                    itemCount: l.length,
                    itemBuilder: (_, i) => ListTile(
                      key: ValueKey('resultado_${l[i].titulo}'),
                      selected: i == sel,
                      selectedTileColor: pal.ventasFondo,
                      leading: Icon(l[i].icono),
                      title: Text(l[i].titulo,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(l[i].detalle),
                      onTap: () => Navigator.pop(context, l[i].r),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text('↑ ↓ para moverte · Enter para abrir · Esc para cerrar',
                style: t.bodySmall),
          ),
        ]),
      ),
    );
  }
}
