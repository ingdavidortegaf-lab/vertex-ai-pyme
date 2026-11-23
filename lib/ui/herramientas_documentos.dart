part of 'herramientas_page.dart';

// Comprobantes de venta y la hoja para ver, imprimir o compartir un documento.

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
  // En el PDF, el cliente sale con su cédula o NIT si la tiene.
  var clientePdf = v['cliente_nombre'] as String?;
  if (clienteId != null) {
    final c = await db.cliente(clienteId);
    saldo = (c?['saldo'] as num?)?.toDouble() ?? 0;
    final doc = (c?['documento'] as String?) ?? '';
    if (clientePdf != null && doc.isNotEmpty) {
      clientePdf = '$clientePdf · ${ident.mostrarDocumento(c?['tipo_doc'] as String? ?? 'CC', doc)}';
    }
  }
  final texto = textoComprobante(
    negocio: negocio,
    ventaId: ventaId,
    fecha: DateTime.parse(v['fecha'] as String).toLocal(),
    lineas: lineas,
    total: (v['monto'] as num).toDouble(),
    cliente: v['cliente_nombre'] as String?,
    fiado: v['credito'] == 1,
    formaPago: textoPagos(leerPagos(v['pagos'],
        monto: (v['monto'] as num).toDouble(),
        tipo: 'ingreso',
        credito: v['credito'] == 1)),
    saldoCliente: saldo,
  );
  final fiado = v['credito'] == 1;
  // Número único y archivado: reimprimir la misma venta conserva el número.
  final documento = await db.emitirDocumento('venta',
      refId: ventaId,
      clienteId: clienteId,
      clienteNombre: v['cliente_nombre'] as String?,
      total: (v['monto'] as num).toDouble(),
      resumen: lineas.map((l) => l.nombre).join(', '),
      reutilizar: true);
  final numero = documento['numero'] as String;
  final doc = DocImprimible(
    titulo: 'Comprobante de venta',
    numero: numero,
    fecha: DateTime.parse(v['fecha'] as String).toLocal(),
    negocio: negocio,
    cliente: clientePdf,
    lineas: lineas,
    total: (v['monto'] as num).toDouble(),
    notas: [
      'Forma de pago: ${textoPagos(leerPagos(v['pagos'], monto: (v['monto'] as num).toDouble(), tipo: 'ingreso', credito: fiado))}',
      if (fiado && saldo > 0) 'Saldo pendiente a la fecha: ${cop(saldo)}',
      '¡Gracias por su compra!',
    ],
  );
  final pdf = pdfListo(doc);
  await archivarDocumento(documento, pdf);
  if (!context.mounted) return;
  await mostrarDocumento(context,
      titulo: 'Comprobante N.º $numero',
      texto: texto.replaceFirst(numeroDoc(ventaId), numero),
      telefono: (v['cliente_telefono'] as String?) ?? '',
      pdf: pdf,
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
    PdfListo? pdf,
    String boton = 'Enviar por WhatsApp'}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (c) {
      final t = Theme.of(c).textTheme;
      final esquema = Theme.of(c).colorScheme;
      return ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.85),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
                  child: SelectableText(
                      texto.replaceAll('*', '').replaceAll('_', ''),
                      style: cifras(t.bodyMedium)),
                ),
              ),
            ),
            if (nota != null) ...[
              const SizedBox(height: 10),
              Text(nota,
                  style:
                      t.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1C7A43),
                  foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(c);
                enviarWhatsApp(texto, telefono: telefono);
              },
              icon: const Icon(Icons.chat_outlined),
              label:
                  Text(telefono.isEmpty ? '$boton (elegir contacto)' : boton),
            ),
            if (pdf != null) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await pdf.imprimir();
                      } catch (_) {
                        avisar('No se pudo abrir la impresión');
                      }
                    },
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Imprimir'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await pdf.compartir();
                      } catch (_) {
                        avisar('No se pudo crear el PDF');
                      }
                    },
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('PDF'),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Text('El PDF queda guardado en «Documentos emitidos».',
                  textAlign: TextAlign.center,
                  style:
                      t.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
            ],
          ]),
        ),
      );
    },
  );
}

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
    if (mounted) {
      setState(() => _ventas = m.where((x) => x['tipo'] == 'ingreso' && (x['anulada'] as num? ?? 0) == 0).toList());
    }
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
                      child: Text(
                          'Aún no hay ventas. Registra una y aquí podrás '
                          'enviar su comprobante.',
                          textAlign: TextAlign.center)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  children: [
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
                              onTap: () =>
                                  enviarComprobante(context, x['id'] as String),
                              child: IgnorePointer(
                                  child: FilaMovimiento(v: x, fmt: fmt)),
                            ),
                          ],
                        ]),
                      ),
                    ]),
    );
  }
}
