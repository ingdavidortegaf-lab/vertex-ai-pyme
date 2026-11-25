import 'package:flutter/material.dart';
import 'escritorio.dart';
import '../data/local_db.dart';
import '../domain/roles.dart';
import '../data/sync_service.dart';
import '../domain/formato.dart';
import 'cliente_detalle_page.dart';
import 'campo_telefono.dart';
import 'campos_identificacion.dart';
import '../domain/ejemplos.dart';
import '../domain/identificacion.dart';
import 'comun.dart';
import 'legal_page.dart';
import 'ilustraciones.dart';
import 'tema.dart';

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});
  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  List<Map<String, Object?>> _items = [];
  bool _cargado = false;
  String _filtro = '';

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

  static String _sinTildes(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[áà]'), 'a')
      .replaceAll(RegExp('[éè]'), 'e')
      .replaceAll(RegExp('[íì]'), 'i')
      .replaceAll(RegExp('[óò]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u');

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final f = _sinTildes(_filtro.trim());
    final digitos = _filtro.replaceAll(RegExp(r'\D'), '');
    final lista = f.isEmpty
        ? _items
        : _items.where((c) {
            final nombre = _sinTildes(c['nombre'] as String);
            final tel = (c['telefono'] as String?) ?? '';
            final doc = ((c['documento'] as String?) ?? '')
                .replaceAll(RegExp(r'\D'), '');
            return nombre.contains(f) ||
                (digitos.length >= 3 &&
                    (tel.contains(digitos) || doc.contains(digitos)));
          }).toList();
    final deudores =
        _items.where((c) => ((c['saldo'] as num?) ?? 0) > 0).length;

    final crea = LocalDb.instance.puede(Permiso.crearClientes);
    return Scaffold(
        floatingActionButton: crea
            ? FloatingActionButton.extended(
                onPressed: () => mostrarFormCliente(context),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Cliente'),
              )
            : null,
        body: AnchoContenido(
          maxAncho: 1000,
          child: !_cargado
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? EstadoVacio(
                      ilustracion: const IlustracionPizarra(),
                      titulo: 'Aún no hay clientes',
                      texto:
                          'Agrega a tus clientes para venderles fiado, ver quién '
                          'te debe y cobrarles por WhatsApp.',
                      accion: crea
                          ? FilledButton.icon(
                              onPressed: () => mostrarFormCliente(context),
                              icon: const Icon(Icons.person_add_alt),
                              label: const Text('Agregar el primero'),
                            )
                          : null,
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                      children: [
                          TextField(
                            onChanged: (v) => setState(() => _filtro = v),
                            textInputAction: TextInputAction.search,
                            decoration: const InputDecoration(
                              hintText: 'Buscar por nombre, celular o cédula',
                              prefixIcon: Icon(Icons.search),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                            child: Text(
                              '${_items.length == 1 ? '1 cliente' : '${_items.length} clientes'}'
                              '${deudores > 0 ? ' · $deudores con saldo pendiente' : ''}',
                              style: t.labelLarge
                                  ?.copyWith(color: esquema.onSurfaceVariant),
                            ),
                          ),
                          if (lista.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                  'Ningún cliente coincide con «${_filtro.trim()}».',
                                  textAlign: TextAlign.center,
                                  style: t.bodyLarge),
                            )
                          else
                            Card(
                              child: Column(children: [
                                for (final (i, c) in lista.indexed) ...[
                                  if (i > 0) const Divider(indent: 72),
                                  _FilaCliente(c: c, p: p),
                                ],
                              ]),
                            ),
                        ]),
        ));
  }
}

class _FilaCliente extends StatelessWidget {
  final Map<String, Object?> c;
  final Paleta p;
  const _FilaCliente({required this.c, required this.p});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tel = (c['telefono'] as String?) ?? '';
    final saldo = (c['saldo'] as num?)?.toDouble() ?? 0;
    final nombre = c['nombre'] as String;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: AvatarCliente(nombre: nombre, clave: nombre),
      title: Text(nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
          [
            tel.isEmpty ? 'Sin celular' : mostrarTelefono(tel),
            if ((c['documento'] as String? ?? '').isNotEmpty)
              mostrarDocumento(
                  c['tipo_doc'] as String? ?? 'CC', c['documento'] as String),
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (saldo > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: p.fiadoFondo, borderRadius: BorderRadius.circular(10)),
            child: Text('Debe ${cop(saldo)}',
                style: cifras(t.labelLarge?.copyWith(color: p.fiado))),
          ),
        const SizedBox(width: 6),
        iconoSync(c['sync']),
      ]),
      onTap: () => Navigator.of(context)
          .push(rutaVertex(ClienteDetallePage(clienteId: c['id'] as String))),
    );
  }
}

/// Crear (cliente == null) o editar un cliente. Devuelve el id guardado.
Future<String?> mostrarFormCliente(BuildContext context,
    {Map<String, Object?>? cliente, String nombreInicial = ''}) async {
  final r = await showModalBottomSheet<_DatosCliente>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _FormCliente(cliente: cliente, nombreInicial: nombreInicial),
  );
  if (r == null) return null;
  final id = await LocalDb.instance.saveCliente(r.nombre, r.telefono,
      id: cliente?['id'] as String?,
      tipoDoc: r.tipoDoc,
      documento: r.documento,
      correo: r.correo);
  if (cliente == null) {
    await LocalDb.instance.registrarAutorizacionCliente(id, 'en la tienda');
  }
  SyncService.instance.sync();
  avisar(cliente == null ? 'Cliente guardado' : 'Cliente actualizado');
  return id;
}

class _DatosCliente {
  final String nombre, telefono, tipoDoc, documento, correo;
  const _DatosCliente(
      this.nombre, this.telefono, this.tipoDoc, this.documento, this.correo);
}

class _FormCliente extends StatefulWidget {
  final Map<String, Object?>? cliente;
  final String nombreInicial;
  const _FormCliente({this.cliente, this.nombreInicial = ''});
  @override
  State<_FormCliente> createState() => _FormClienteState();
}

class _FormClienteState extends State<_FormCliente> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(
      text: widget.cliente?['nombre'] as String? ?? widget.nombreInicial);
  late final _tel = TelefonoCtrl(widget.cliente?['telefono'] as String? ?? '');
  late final _id = IdentificacionCtrl(
      tipo: widget.cliente?['tipo_doc'] as String? ?? 'CC',
      documento: widget.cliente?['documento'] as String? ?? '',
      correo: widget.cliente?['correo'] as String? ?? '');

  /// Los datos de factura se muestran abiertos si ya hay alguno.
  late bool _verDatos =
      (widget.cliente?['documento'] as String? ?? '').isNotEmpty ||
          (widget.cliente?['correo'] as String? ?? '').isNotEmpty;

  /// Autorización del cliente (Ley 1581): casilla SIN premarcar,
  /// obligatoria para registrar un cliente nuevo.
  bool _autoriza = false;
  String? _errorAutoriza;

  @override
  void initState() {
    super.initState();
    _nombre.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nombre.dispose();
    _tel.dispose();
    _id.dispose();
    super.dispose();
  }

  void _guardar() {
    final nuevo = widget.cliente == null;
    setState(() => _errorAutoriza = nuevo && !_autoriza
        ? 'Para registrar al cliente necesitas su autorización'
        : null);
    if (!_form.currentState!.validate()) {
      // Si el error está en los datos de factura, se abren para verlo.
      if (problemaDocumento(_id.tipo, _id.documento.text) != null ||
          problemaCorreo(_id.correo.text) != null) {
        setState(() => _verDatos = true);
      }
      return;
    }
    if (_errorAutoriza != null) return;
    final nombre = _nombre.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final tel = _tel.valor ?? '';
    Navigator.pop(
        context,
        _DatosCliente(
            nombre, tel, _id.tipo, _id.documentoNormal, _id.correoNormal));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final nombre = _nombre.text.trim();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Form(
          key: _form,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              AvatarCliente(
                  nombre: nombre.isEmpty ? '?' : nombre,
                  clave: nombre.replaceAll(RegExp(r'\s+'), ' '),
                  tam: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                    widget.cliente == null ? 'Nuevo cliente' : 'Editar cliente',
                    style: t.headlineSmall),
              ),
            ]),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nombre,
              autofocus: widget.cliente == null,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              maxLength: 80,
              decoration: InputDecoration(
                  labelText: _id.esEmpresa
                      ? 'Razón social de la empresa'
                      : 'Nombre completo',
                  hintText: _id.esEmpresa
                      ? 'Ej.: ${ejemplosPara(LocalDb.instance.tipoNegocio.value).empresa}'
                      : 'Ej.: Ana María Pérez Rojas',
                  prefixIcon: Icon(_id.esEmpresa
                      ? Icons.business_outlined
                      : Icons.person_outline)),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.length < 2) {
                  return _id.esEmpresa
                      ? 'Escribe el nombre de la empresa'
                      : 'Escribe el nombre del cliente';
                }
                if (!_id.esEmpresa && RegExp(r'[0-9@]').hasMatch(t)) {
                  return 'El nombre no debe llevar números ni correos';
                }
                return null;
              },
            ),
            const SizedBox(height: 4),
            CampoTelefono(ctrl: _tel),
            const SizedBox(height: 4),
            if (!_verDatos)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('ver_datos_factura'),
                  onPressed: () => setState(() => _verDatos = true),
                  icon: const Icon(Icons.badge_outlined),
                  label: const Text('Agregar cédula o NIT y correo'),
                ),
              )
            else
              CamposIdentificacion(
                  ctrl: _id, alCambiarTipo: () => setState(() {})),
            const SizedBox(height: 12),
            if (widget.cliente == null) ...[
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Checkbox(
                    value: _autoriza,
                    onChanged: (v) => setState(() {
                          _autoriza = v ?? false;
                          if (_autoriza) _errorAutoriza = null;
                        })),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text.rich(TextSpan(style: t.bodyMedium, children: [
                      const TextSpan(
                          text:
                              'El cliente me autorizó, de manera previa, expresa e '
                              'informada, a guardar sus datos conforme a la '),
                      enlace(context, 'Política de Tratamiento de Datos',
                          () => verPolitica(context)),
                      const TextSpan(
                          text:
                              '. Después puedes imprimir o enviarle el formato de '
                              'autorización desde su ficha.'),
                    ])),
                  ),
                ),
              ]),
              if (_errorAutoriza != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(_errorAutoriza!,
                      style: t.bodySmall?.copyWith(color: esquema.error)),
                ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _guardar,
              child: Text(widget.cliente == null
                  ? 'Guardar cliente'
                  : 'Guardar cambios'),
            ),
          ]),
        ),
      ),
    );
  }
}
