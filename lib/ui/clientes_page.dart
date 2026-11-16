import 'package:flutter/material.dart';
import '../data/local_db.dart';
import '../data/sync_service.dart';
import '../domain/formato.dart';
import 'cliente_detalle_page.dart';
import 'comun.dart';

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});
  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  List<Map<String, Object?>> _items = [];
  bool _cargado = false;

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
    final r = await LocalDb.instance.clientes();
    if (mounted) {
      setState(() {
        _items = r;
        _cargado = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => mostrarFormCliente(context),
          icon: const Icon(Icons.person_add_alt),
          label: const Text('Cliente'),
        ),
        body: !_cargado
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? const Center(
                    child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Aún no hay clientes. Toca «Cliente» para agregar el primero.',
                        textAlign: TextAlign.center),
                  ))
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final c = _items[i];
                      final tel = (c['telefono'] as String?) ?? '';
                      final saldo = (c['saldo'] as num?)?.toDouble() ?? 0;
                      final nombre = c['nombre'] as String;
                      return ListTile(
                        leading: CircleAvatar(
                            child: Text(nombre.isEmpty ? '?' : nombre[0].toUpperCase())),
                        title: Text(nombre),
                        subtitle: Text(tel.isEmpty ? 'Sin celular' : mostrarTelefono(tel)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (saldo > 0)
                            Text('Debe ${cop(saldo)}',
                                style: const TextStyle(
                                    color: Colors.red, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 6),
                          iconoSync(c['sync']),
                        ]),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                ClienteDetallePage(clienteId: c['id'] as String))),
                      );
                    },
                  ),
      );
}

/// Crear (cliente == null) o editar un cliente. Devuelve el id guardado.
Future<String?> mostrarFormCliente(BuildContext context,
    {Map<String, Object?>? cliente}) async {
  final r = await showDialog<(String, String)>(
    context: context,
    builder: (_) => _FormCliente(cliente: cliente),
  );
  if (r == null) return null;
  final (nombre, tel) = r;
  final id = await LocalDb.instance
      .saveCliente(nombre, tel, id: cliente?['id'] as String?);
  SyncService.instance.sync();
  avisar(cliente == null ? 'Cliente guardado' : 'Cliente actualizado');
  return id;
}

class _FormCliente extends StatefulWidget {
  final Map<String, Object?>? cliente;
  const _FormCliente({this.cliente});
  @override
  State<_FormCliente> createState() => _FormClienteState();
}

class _FormClienteState extends State<_FormCliente> {
  final _form = GlobalKey<FormState>();
  late final _nombre =
      TextEditingController(text: widget.cliente?['nombre'] as String? ?? '');
  late final _tel = TextEditingController(
      text: mostrarTelefono(widget.cliente?['telefono'] as String? ?? ''));

  @override
  void dispose() {
    _nombre.dispose();
    _tel.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_form.currentState!.validate()) return;
    final nombre = _nombre.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final tel = normalizarTelefono(_tel.text) ?? '';
    Navigator.pop(context, (nombre, tel));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.cliente == null ? 'Nuevo cliente' : 'Editar cliente'),
        content: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: _nombre,
              autofocus: widget.cliente == null,
              textCapitalization: TextCapitalization.words,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'Nombre *'),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.length < 2) return 'Escribe el nombre del cliente';
                if (RegExp(r'[0-9@]').hasMatch(t)) {
                  return 'El nombre no debe llevar números ni correos';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _tel,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Celular (WhatsApp)', hintText: '300 123 4567'),
              validator: (v) => normalizarTelefono(v ?? '') == null
                  ? 'Celular colombiano de 10 dígitos que empiece por 3'
                  : null,
              onFieldSubmitted: (_) => _guardar(),
            ),
            const SizedBox(height: 8),
            Text('Pide autorización al cliente para guardar sus datos.',
                style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(onPressed: _guardar, child: const Text('Guardar')),
        ],
      );
}
