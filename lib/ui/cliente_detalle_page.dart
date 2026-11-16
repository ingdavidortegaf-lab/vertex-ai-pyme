import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/asistente_service.dart';
import '../data/local_db.dart';
import '../data/sync_service.dart';
import '../domain/asistente_local.dart';
import '../domain/formato.dart';
import '../domain/resumen.dart';
import 'clientes_page.dart';
import 'comun.dart';
import 'tema.dart';
import 'ventas_page.dart';

/// Ficha del cliente: saldo, historial y mensaje sugerido para WhatsApp.
class ClienteDetallePage extends StatefulWidget {
  final String clienteId;
  const ClienteDetallePage({super.key, required this.clienteId});
  @override
  State<ClienteDetallePage> createState() => _ClienteDetallePageState();
}

class _ClienteDetallePageState extends State<ClienteDetallePage> {
  Map<String, Object?>? _c;
  List<Map<String, Object?>> _movs = [];
  bool _generando = false;

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
    final c = await LocalDb.instance.cliente(widget.clienteId);
    final m = await LocalDb.instance.movimientos(clienteId: widget.clienteId);
    if (!mounted) return;
    if (c == null || c['deleted'] == 1) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _c = c;
      _movs = m;
    });
  }

  double get _saldo => (_c?['saldo'] as num?)?.toDouble() ?? 0;
  String get _tel => (_c?['telefono'] as String?) ?? '';

  ClienteSaldo get _clienteSaldo => ClienteSaldo(
      id: widget.clienteId,
      nombre: _c!['nombre'] as String,
      telefono: _tel,
      saldo: _saldo);

  Future<void> _mensaje() async {
    setState(() => _generando = true);
    final s = SyncService.instance;
    final (texto, esIA) = await AsistenteService.mensajeParaCliente(_clienteSaldo,
        api: s.remoto, hayRed: s.hayRed);
    if (!mounted) return;
    setState(() => _generando = false);
    final ctrl = TextEditingController(text: texto);
    final enviar = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(esIA ? 'Mensaje sugerido con IA' : 'Mensaje sugerido'),
        content: TextField(
          controller: ctrl,
          maxLines: 6,
          minLines: 3,
          decoration: const InputDecoration(
              helperText: 'Puedes editarlo antes de enviarlo'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(c, true),
            icon: const Icon(Icons.send),
            label: const Text('Abrir WhatsApp'),
          ),
        ],
      ),
    );
    final msg = ctrl.text.trim();
    ctrl.dispose();
    if (enviar == true && msg.isNotEmpty) await abrirWhatsApp(_tel, msg);
  }

  Future<void> _eliminar() async {
    final ok = await confirmar(
        context,
        'Eliminar cliente',
        '¿Eliminar a ${_c!['nombre']}? Sus ventas y abonos se conservan en '
            'el historial.',
        si: 'Eliminar');
    if (!ok) return;
    await LocalDb.instance.deleteCliente(widget.clienteId);
    SyncService.instance.sync();
    avisar('Cliente eliminado');
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final fmt = DateFormat('d MMM, h:mm a', 'es_CO');
    final p = Paleta.of(context);
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final nombre = c['nombre'] as String;
    final debe = _saldo > 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cliente'),
        actions: [
          IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => mostrarFormCliente(context, cliente: c)),
          IconButton(
              tooltip: 'Eliminar',
              icon: const Icon(Icons.delete_outline),
              onPressed: _eliminar),
        ],
      ),
      body: ListView(padding: EdgeInsets.zero, children: [
        Container(
          decoration: BoxDecoration(
            color: p.pizarra,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              AvatarCliente(nombre: nombre, clave: nombre, tam: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleLarge?.copyWith(color: p.tizaBlanca)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.phone_android, size: 16, color: p.tizaSuave),
                    const SizedBox(width: 4),
                    Text(_tel.isEmpty ? 'Sin celular' : mostrarTelefono(_tel),
                        style: t.bodyMedium?.copyWith(color: p.tizaSuave)),
                  ]),
                ]),
              ),
              iconoSync(c['sync']),
            ]),
            const SizedBox(height: 22),
            Text(debe ? 'Te debe' : 'Está al día',
                style: t.titleSmall?.copyWith(color: p.tizaSuave)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(cop(debe ? _saldo : 0),
                  style: cifras(t.displaySmall?.copyWith(
                      color: debe ? p.fiadoTiza : p.ventasTiza, fontSize: 40))),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1C7A43),
                  foregroundColor: Colors.white),
              onPressed: _tel.isEmpty || _generando ? null : _mensaje,
              icon: _generando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.chat_outlined),
              label: Text(_tel.isEmpty
                  ? 'Agrega su celular para escribirle'
                  : debe
                      ? 'Cobrar por WhatsApp'
                      : 'Escribir por WhatsApp'),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      mostrarFormMovimiento(context, clienteId: widget.clienteId),
                  icon: const Icon(Icons.add),
                  label: const Text('Venta'),
                ),
              ),
              if (debe) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: p.fiado, side: BorderSide(color: p.fiado)),
                    onPressed: () => mostrarFormMovimiento(context,
                        clienteId: widget.clienteId, tipoInicial: 'abono'),
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Abono'),
                  ),
                ),
              ],
            ]),
            const TituloSeccion('Historial'),
            if (_movs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                child: Text('Todavía no hay movimientos con este cliente.',
                    style: t.bodyLarge?.copyWith(color: esquema.onSurfaceVariant)),
              )
            else
              Card(
                child: Column(children: [
                  for (final (i, m) in _movs.indexed) ...[
                    if (i > 0) const Divider(indent: 72),
                    filaMovimiento(m, fmt, mostrarCliente: false),
                  ],
                ]),
              ),
            const SizedBox(height: 28),
          ]),
        ),
      ]),
    );
  }
}

Future<void> abrirWhatsApp(String telefono, String mensaje) async {
  try {
    final ok = await launchUrl(enlaceWhatsApp(telefono, mensaje),
        mode: LaunchMode.externalApplication);
    if (!ok) avisar('No se pudo abrir WhatsApp');
  } catch (_) {
    avisar('No se pudo abrir WhatsApp');
  }
}
