import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/local_db.dart';
import '../domain/codigos.dart';
import '../domain/exportar.dart';
import '../domain/formato.dart';
import '../domain/resumen.dart';
import '../domain/roles.dart';
import '../pdf/archivo.dart';
import 'comun.dart';
import 'escritorio.dart';
import 'tema.dart';

/// Guarda o comparte un archivo para Excel.
///
/// - En el PC: queda en Documentos\VERTEX_documentos (donde también están los
///   PDF) y se ofrece abrir la carpeta.
/// - En el celular y en la web: se comparte (WhatsApp, correo, Drive…).
Future<void> exportarCsv(String nombre, String contenido) async {
  final bytes = utf8.encode(contenido);
  if (!kIsWeb && LocalDb.esEscritorio) {
    try {
      final dir = await carpetaDocumentos();
      final ruta = p.join(dir.path, nombre);
      await File(ruta).writeAsBytes(bytes, flush: true);
      avisarConAccion('Guardado en Documentos › VERTEX_documentos › $nombre',
          'Abrir', () => launchUrl(Uri.file(ruta)));
      return;
    } catch (_) {
      // Si no se pudo escribir, se intenta compartir.
    }
  }
  try {
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, name: nombre, mimeType: 'text/csv')],
      fileNameOverrides: [nombre],
      subject: nombre,
    ));
  } catch (_) {
    avisar('Este equipo no permite compartir archivos');
  }
}

/// Kárdex de un producto: cada entrada, venta, ajuste y devolución con el
/// saldo que deja. Se exporta a Excel para el contador.
class KardexPage extends StatefulWidget {
  final ProductoStock producto;
  const KardexPage({super.key, required this.producto});
  @override
  State<KardexPage> createState() => _KardexPageState();
}

class _KardexPageState extends State<KardexPage> {
  List<LineaKardex>? _l;

  @override
  void initState() {
    super.initState();
    LocalDb.instance.kardex(widget.producto.id).then((l) {
      if (mounted) setState(() => _l = l);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pal = Paleta.of(context);
    final x = widget.producto;
    final veCostos = LocalDb.instance.puede(Permiso.verCostos);
    final l = _l;
    final fecha = DateFormat('d MMM y · h:mm a', 'es_CO');
    return Scaffold(
      appBar: AppBar(
        title: Text('Kárdex · ${x.nombre}'),
        actions: [
          if (l != null && l.isNotEmpty)
            IconButton(
              key: const ValueKey('exportar_kardex'),
              tooltip: 'Exportar a Excel',
              onPressed: () => exportarCsv(
                  nombreCsv(
                      'kardex_${x.nombre.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}',
                      DateTime.now()),
                  csvKardex(x.nombre, l, conCostos: veCostos)),
              icon: const Icon(Icons.table_view_outlined),
            ),
        ],
      ),
      body: l == null
          ? const Center(child: CircularProgressIndicator())
          : l.isEmpty
              ? const Center(
                  child: Text(
                      'Este producto aún no tiene movimientos de inventario.'))
              : AnchoContenido(
                  maxAncho: 900,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    Card(
                      child: ListTile(
                        title: Text(
                            'Saldo actual: ${cantidadConUnidad(l.last.saldo, x.unidad)}',
                            style: t.titleMedium),
                        subtitle: Text('${l.length} movimientos desde el '
                            '${DateFormat('d MMM y', 'es_CO').format(l.first.fecha.toLocal())}'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Column(children: [
                        for (final (i, k) in l.reversed.indexed) ...[
                          if (i > 0) const Divider(height: 1, indent: 16),
                          ListTile(
                            leading: Icon(
                              k.cantidad >= 0
                                  ? Icons.south_west_rounded
                                  : Icons.north_east_rounded,
                              color: k.cantidad >= 0 ? pal.ventas : pal.gastos,
                            ),
                            title: Text(
                                '${k.motivoTexto} · ${k.cantidad >= 0 ? '+' : '−'}${cantidadConUnidad(k.cantidad.abs(), x.unidad)}'),
                            subtitle: Text([
                              fecha.format(k.fecha.toLocal()),
                              if (k.detalle.isNotEmpty) k.detalle,
                              if (k.registro.isNotEmpty) k.registro,
                              if (veCostos && (k.costoUnit ?? 0) > 0)
                                'costo ${cop(k.costoUnit!)}',
                            ].join(' · ')),
                            trailing: Text(
                                'Saldo ${cantidadConUnidad(k.saldo, x.unidad)}',
                                style: cifras(t.labelLarge)),
                          ),
                        ],
                      ]),
                    ),
                  ]),
                ),
    );
  }
}
