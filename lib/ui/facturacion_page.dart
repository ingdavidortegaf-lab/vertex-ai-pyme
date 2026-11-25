import 'package:flutter/material.dart';
import '../data/local_db.dart';
import '../data/sync_service.dart';
import '../domain/facturacion.dart';
import '../domain/formato.dart';
import 'comun.dart';
import 'tema.dart';

/// Factura electrónica: los datos del negocio como emisor (los escribe el
/// dueño tal como están en su RUT y su resolución), facturar una venta y la
/// cola de envío. No hay proveedor real conectado: las facturas esperan en
/// la cola hasta que se conecte uno.
class FacturacionPage extends StatefulWidget {
  const FacturacionPage({super.key});
  @override
  State<FacturacionPage> createState() => _FacturacionPageState();
}

class _FacturacionPageState extends State<FacturacionPage> {
  final db = LocalDb.instance;
  final _form = GlobalKey<FormState>();
  final _c = {for (final k in DatosEmisor.claves) k: TextEditingController()};
  List<FacturaEmitida> _facturas = const [];
  bool _cargado = false;

  @override
  void initState() {
    super.initState();
    db.cambios.addListener(_cargarFacturas);
    _cargar();
  }

  @override
  void dispose() {
    db.cambios.removeListener(_cargarFacturas);
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    final e = await db.datosEmisor();
    final a = e.aAjustes();
    for (final k in DatosEmisor.claves) {
      final v = a[k] ?? '';
      _c[k]!.text = (k == 'fe_desde' || k == 'fe_hasta') && v == '0' ? '' : v;
    }
    await _cargarFacturas();
    if (mounted) setState(() => _cargado = true);
  }

  Future<void> _cargarFacturas() async {
    final l = await db.facturas();
    if (mounted) setState(() => _facturas = l);
  }

  DatosEmisor get _emisor =>
      DatosEmisor.desdeAjustes({for (final k in DatosEmisor.claves) k: _c[k]!.text});

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    await db.guardarEmisor(_emisor);
    final f = _emisor.faltantes();
    avisar(f.isEmpty ? 'Datos guardados: ya puedes facturar' : 'Guardado. Falta: ${f.join(', ')}');
    setState(() {});
  }

  Future<void> _facturarVenta() async {
    final ya = {for (final f in _facturas) f.ventaId};
    final ventas = [
      for (final v in await db.movimientos(limite: 100))
        if (v['tipo'] == 'ingreso' && (v['anulada'] as num? ?? 0) == 0 && !ya.contains(v['id'])) v
    ];
    if (!mounted) return;
    if (ventas.isEmpty) {
      avisar('No hay ventas recientes sin factura');
      return;
    }
    final v = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('¿Qué venta vas a facturar?'),
        children: [
          for (final v in ventas.take(30))
            SimpleDialogOption(
              key: ValueKey('venta_${v['concepto']}'),
              onPressed: () => Navigator.pop(c, v),
              child: Text('${v['concepto']} · ${cop((v['monto'] as num).toDouble())}'
                  '${v['cliente_nombre'] == null ? '' : ' · ${v['cliente_nombre']}'}'),
            ),
        ],
      ),
    );
    if (v == null) return;
    final id = v['id'] as String;
    try {
      FacturaEmitida f;
      try {
        f = await db.encolarFactura(id);
      } on ErrorFactura catch (e) {
        if (!e.mensaje.startsWith('Indica el IVA') || !mounted) rethrow;
        final iva = await _pedirIva();
        if (iva == null) return;
        f = await db.encolarFactura(id, ivaSinProductos: iva);
      }
      avisar('Factura ${f.numero} en cola');
      SyncService.instance.sync();
    } on ErrorFactura catch (e) {
      avisar(e.mensaje);
    }
  }

  Future<double?> _pedirIva() => dialogoConTexto<double>(
        context,
        builder: (c, ctrl) => AlertDialog(
          title: const Text('IVA de esta venta'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('La venta no tiene productos del inventario. ¿Qué porcentaje de IVA le corresponde? '
                'Si no lo sabes, pregúntale a tu contador.'),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('campo_iva_venta'),
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'IVA', suffixText: '%'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
            FilledButton(
              key: const ValueKey('guardar_iva_venta'),
              onPressed: () {
                final x = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
                if (x != null && x >= 0 && x <= 100) Navigator.pop(c, x);
              },
              child: const Text('Facturar'),
            ),
          ],
        ),
      );

  Widget _campo(String clave, String etiqueta,
          {String? ayuda, TextInputType? teclado}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          key: ValueKey(clave),
          controller: _c[clave],
          keyboardType: teclado,
          decoration: InputDecoration(labelText: etiqueta, helperText: ayuda, helperMaxLines: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Paleta.of(context);
    final prov = SyncService.instance.facturador;
    final faltan = _emisor.faltantes();
    return Scaffold(
      appBar: AppBar(title: const Text('Factura electrónica')),
      body: !_cargado
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                Card(
                  child: ListTile(
                    leading: Icon(prov.configurado ? Icons.cloud_done_outlined : Icons.info_outline),
                    title: Text(prov.configurado
                        ? 'Proveedor: ${prov.nombre}'
                        : 'Aún no hay un proveedor de facturación conectado'),
                    subtitle: Text(prov.configurado
                        ? 'Las facturas en cola se envían al sincronizar.'
                        : 'Puedes dejar todo listo: las facturas quedan en cola y se envían solas '
                            'cuando se conecte un proveedor autorizado por la DIAN.'),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const ValueKey('facturar_venta'),
                  onPressed: faltan.isEmpty ? _facturarVenta : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Facturar una venta'),
                ),
                if (faltan.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Para facturar faltan: ${faltan.join(', ')}.', style: t.bodySmall),
                  ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: Text('Facturas', style: t.titleMedium)),
                  TextButton.icon(
                    onPressed: () => SyncService.instance.sync(),
                    icon: const Icon(Icons.sync),
                    label: const Text('Enviar ahora'),
                  ),
                ]),
                if (_facturas.isEmpty)
                  Text('Todavía no hay facturas.', style: t.bodySmall)
                else
                  for (final f in _facturas) _filaFactura(f, t, p),
                const SizedBox(height: 24),
                Text('Datos del negocio para facturar', style: t.titleMedium),
                const SizedBox(height: 4),
                Text('Escríbelos tal como aparecen en tu RUT y en tu resolución de facturación de la DIAN.',
                    style: t.bodySmall),
                const SizedBox(height: 12),
                Form(
                  key: _form,
                  child: Column(children: [
                    _campo('fe_razon_social', 'Razón social o nombre'),
                    Row(children: [
                      Expanded(
                          flex: 3,
                          child: _campo('fe_nit', 'NIT (sin dígito de verificación)',
                              teclado: TextInputType.number)),
                      const SizedBox(width: 10),
                      Expanded(child: _campo('fe_dv', 'DV', teclado: TextInputType.number)),
                    ]),
                    _campo('fe_responsabilidad', 'Responsabilidad fiscal (opcional)',
                        ayuda: 'Tal como aparece en tu RUT.'),
                    _campo('fe_direccion', 'Dirección'),
                    _campo('fe_municipio', 'Municipio'),
                    _campo('fe_correo', 'Correo para facturación', teclado: TextInputType.emailAddress),
                    _campo('fe_telefono', 'Teléfono (opcional)', teclado: TextInputType.phone),
                    _campo('fe_resolucion', 'Número de la resolución de facturación'),
                    _campo('fe_prefijo', 'Prefijo (opcional)'),
                    Row(children: [
                      Expanded(child: _campo('fe_desde', 'Desde el número', teclado: TextInputType.number)),
                      const SizedBox(width: 10),
                      Expanded(child: _campo('fe_hasta', 'Hasta el número', teclado: TextInputType.number)),
                    ]),
                    _campo('fe_vigente_hasta', 'Vigente hasta (AAAA-MM-DD)',
                        teclado: TextInputType.datetime),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        key: const ValueKey('guardar_emisor'),
                        onPressed: _guardar,
                        child: const Text('Guardar datos'),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
    );
  }

  Widget _filaFactura(FacturaEmitida f, TextTheme t, Paleta p) {
    final color = switch (f.estado) {
      EstadoFE.aceptado => p.ventas,
      EstadoFE.rechazado => Theme.of(context).colorScheme.error,
      _ => p.fiado,
    };
    final ultima = _facturas.isNotEmpty && _facturas.first.id == f.id;
    return Card(
      child: ListTile(
        key: ValueKey('factura_${f.numero}'),
        title: Text('${f.numero} · ${f.comprador}'),
        subtitle: Text([
          estadoFETexto(f.estado),
          if (f.mensaje.isNotEmpty) f.mensaje,
          if (f.aceptada) 'CUFE ${f.cufe!.length > 16 ? '${f.cufe!.substring(0, 16)}…' : f.cufe}',
        ].join('\n')),
        isThreeLine: f.mensaje.isNotEmpty || f.aceptada,
        leading: Icon(
            switch (f.estado) {
              EstadoFE.aceptado => Icons.verified_outlined,
              EstadoFE.rechazado => Icons.error_outline,
              EstadoFE.enviado => Icons.schedule_send_outlined,
              EstadoFE.pendiente => Icons.outbox_outlined,
            },
            color: color),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(cop(f.total), style: cifras(t.titleSmall)),
          if (f.estado == EstadoFE.rechazado)
            IconButton(
              tooltip: 'Volver a enviar',
              onPressed: () async {
                await db.reintentarFactura(f.id);
                SyncService.instance.sync();
              },
              icon: const Icon(Icons.refresh),
            )
          else if (f.estado == EstadoFE.pendiente && ultima)
            IconButton(
              tooltip: 'Quitar de la cola',
              onPressed: () async {
                final ok = await confirmar(context, '¿Quitar la factura ${f.numero}?',
                    'Todavía no se ha enviado. Su número se usará en la próxima factura.');
                if (ok && await db.quitarFacturaPendiente(f.id)) avisar('Factura quitada de la cola');
              },
              icon: const Icon(Icons.delete_outline),
            ),
        ]),
      ),
    );
  }
}
