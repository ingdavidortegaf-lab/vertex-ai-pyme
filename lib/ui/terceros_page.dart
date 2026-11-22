import 'package:flutter/material.dart';
import '../data/local_db.dart';
import '../domain/ejemplos.dart';
import '../domain/formato.dart';
import '../domain/identificacion.dart';
import 'campo_telefono.dart';
import 'campos_identificacion.dart';
import 'cliente_detalle_page.dart';
import 'comun.dart';
import 'tema.dart';

IconData iconoClase(String clase) => switch (clase) {
      'servicios' => Icons.bolt_outlined,
      'arriendo' => Icons.home_work_outlined,
      'empleado' => Icons.badge_outlined,
      'otro' => Icons.person_outline,
      _ => Icons.local_shipping_outlined,
    };

/// Proveedores y demás terceros: a quién se le compra o se le paga
/// (arrendador, empresa de la luz, internet, empleados…), con su NIT o
/// cédula, celular y correo, lo que se les debe y lo pagado.
class TercerosPage extends StatefulWidget {
  const TercerosPage({super.key});
  @override
  State<TercerosPage> createState() => _TercerosPageState();
}

class _TercerosPageState extends State<TercerosPage> {
  List<Map<String, Object?>> _items = [];
  String? _clase;
  String _filtro = '';
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
    final r = await LocalDb.instance.proveedores();
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
    final f = _filtro.trim().toLowerCase();
    final lista = _items.where((x) {
      if (_clase != null && x['clase'] != _clase) return false;
      if (f.isEmpty) return true;
      return (x['nombre'] as String).toLowerCase().contains(f) ||
          ((x['documento'] as String?) ?? '').contains(f);
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Proveedores y terceros')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => mostrarFormTercero(context, claseInicial: _clase ?? 'proveedor'),
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
      body: !_cargado
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 96), children: [
              Text('A quién le compras o le pagas: proveedores, arrendador, '
                  'servicios públicos y empleados.',
                  style: t.bodyMedium),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  ChoiceChip(
                      label: Text('Todos (${_items.length})'),
                      selected: _clase == null,
                      onSelected: (_) => setState(() => _clase = null)),
                  for (final c in clasesTercero.keys) ...[
                    const SizedBox(width: 8),
                    ChoiceChip(
                        avatar: Icon(iconoClase(c), size: 18),
                        label: Text(nombreClase(c)),
                        selected: _clase == c,
                        onSelected: (_) => setState(() => _clase = c)),
                  ],
                ]),
              ),
              if (_items.length > 6) ...[
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) => setState(() => _filtro = v),
                  decoration: const InputDecoration(
                      hintText: 'Buscar por nombre o NIT', prefixIcon: Icon(Icons.search)),
                ),
              ],
              const SizedBox(height: 12),
              if (lista.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                      _items.isEmpty
                          ? 'Aún no tienes proveedores ni terceros. Toca «Agregar».'
                          : 'No hay nadie en este grupo.',
                      textAlign: TextAlign.center,
                      style: t.bodyLarge),
                )
              else
                Card(
                  child: Column(children: [
                    for (final (i, x) in lista.indexed) ...[
                      if (i > 0) const Divider(indent: 72),
                      ListTile(
                        leading: CircleAvatar(
                            backgroundColor: p.asistenteFondo,
                            child: Icon(iconoClase(x['clase'] as String? ?? 'proveedor'),
                                color: p.asistente)),
                        title: Text(x['nombre'] as String,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                            [
                              nombreClase(x['clase'] as String? ?? 'proveedor'),
                              if ((x['documento'] as String? ?? '').isNotEmpty)
                                mostrarDocumento(x['tipo_doc'] as String? ?? 'NIT', x['documento'] as String),
                              if ((x['telefono'] as String? ?? '').isNotEmpty)
                                mostrarTelefono(x['telefono'] as String),
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        trailing: ((x['debo'] as num?) ?? 0) > 0.5
                            ? Text('Le debes\n${cop((x['debo'] as num).toDouble())}',
                                textAlign: TextAlign.right,
                                style: cifras(t.labelLarge?.copyWith(color: p.gastos)))
                            : null,
                        onTap: () => _acciones(x),
                      ),
                    ],
                  ]),
                ),
            ]),
    );
  }

  Future<void> _acciones(Map<String, Object?> x) async {
    final tel = (x['telefono'] as String?) ?? '';
    final pagado = ((x['pagado'] as num?) ?? 0).toDouble();
    final r = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            title: Text(x['nombre'] as String, style: Theme.of(c).textTheme.titleLarge),
            subtitle: Text([
              if ((x['correo'] as String? ?? '').isNotEmpty) x['correo'] as String,
              if (pagado > 0) 'Le has pagado ${cop(pagado)} en gastos',
            ].join('\n')),
          ),
          if (tel.isNotEmpty)
            ListTile(
                leading: const Icon(Icons.chat_outlined),
                title: const Text('Escribir por WhatsApp'),
                onTap: () => Navigator.pop(c, 'wa')),
          ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar datos'),
              onTap: () => Navigator.pop(c, 'editar')),
          ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Eliminar'),
              onTap: () => Navigator.pop(c, 'borrar')),
        ]),
      ),
    );
    if (!mounted) return;
    switch (r) {
      case 'wa':
        await abrirWhatsApp(tel, 'Hola, ${x['nombre']}. ');
      case 'editar':
        await mostrarFormTercero(context, tercero: x);
      case 'borrar':
        if (await confirmar(context, '¿Eliminar a ${x['nombre']}?',
            'Los gastos y deudas ya registrados se conservan.')) {
          await LocalDb.instance.deleteProveedor(x['id'] as String);
          avisar('Eliminado');
        }
    }
  }
}

/// Crear o editar un proveedor o tercero. Devuelve el id guardado.
Future<String?> mostrarFormTercero(BuildContext context,
    {Map<String, Object?>? tercero, String claseInicial = 'proveedor', String nombreInicial = ''}) async {
  final id = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FormTercero(
        tercero: tercero, claseInicial: claseInicial, nombreInicial: nombreInicial),
  );
  if (id != null) avisar(tercero == null ? 'Guardado' : 'Datos actualizados');
  return id;
}

class _FormTercero extends StatefulWidget {
  final Map<String, Object?>? tercero;
  final String claseInicial;
  final String nombreInicial;
  const _FormTercero({this.tercero, required this.claseInicial, this.nombreInicial = ''});
  @override
  State<_FormTercero> createState() => _FormTerceroState();
}

class _FormTerceroState extends State<_FormTercero> {
  final _form = GlobalKey<FormState>();
  late String _clase = widget.tercero?['clase'] as String? ?? widget.claseInicial;
  late final _nombre =
      TextEditingController(text: widget.tercero?['nombre'] as String? ?? widget.nombreInicial);
  late final _tel = TelefonoCtrl(widget.tercero?['telefono'] as String? ?? '');
  late final _id = IdentificacionCtrl(
      tipo: widget.tercero?['tipo_doc'] as String? ??
          (widget.claseInicial == 'empleado' ? 'CC' : 'NIT'),
      documento: widget.tercero?['documento'] as String? ?? '',
      correo: widget.tercero?['correo'] as String? ?? '');

  @override
  void dispose() {
    _nombre.dispose();
    _tel.dispose();
    _id.dispose();
    super.dispose();
  }

  String get _ejemplo => switch (_clase) {
        'servicios' => 'Ej.: empresa de energía, acueducto, internet',
        'arriendo' => 'Ej.: Don Pedro Rincón (dueño del local)',
        'empleado' => 'Ej.: Luis Fernando Pérez',
        'otro' => 'Ej.: Contador, mensajero',
        _ => 'Ej.: ${ejemplosPara(LocalDb.instance.tipoNegocio.value).proveedor}',
      };

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    final tel = _tel.valor;
    if (tel == null) {
      avisar('Revisa el celular (toca el país si es de otro país)');
      return;
    }
    final id = await LocalDb.instance.saveProveedor(
        _nombre.text.trim().replaceAll(RegExp(r'\s+'), ' '), tel,
        id: widget.tercero?['id'] as String?,
        tipoDoc: _id.tipo,
        documento: _id.documentoNormal,
        correo: _id.correoNormal,
        clase: _clase);
    if (mounted) Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(widget.tercero == null ? 'Nuevo proveedor o tercero' : 'Editar datos',
                style: t.headlineSmall),
            const SizedBox(height: 12),
            Text('¿Qué es para tu negocio?', style: t.titleSmall),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final c in clasesTercero.keys)
                ChoiceChip(
                  avatar: Icon(iconoClase(c), size: 18),
                  label: Text(nombreClase(c)),
                  selected: _clase == c,
                  onSelected: (_) => setState(() => _clase = c),
                ),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nombre,
              autofocus: widget.tercero == null && widget.nombreInicial.isEmpty,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              maxLength: 80,
              decoration: InputDecoration(
                  labelText: _id.esEmpresa ? 'Nombre o razón social' : 'Nombre completo',
                  hintText: _ejemplo,
                  counterText: ''),
              validator: (v) => (v ?? '').trim().length < 2 ? 'Escribe el nombre' : null,
            ),
            const SizedBox(height: 8),
            CampoTelefono(ctrl: _tel, etiqueta: 'Celular (WhatsApp, opcional)'),
            const SizedBox(height: 8),
            CamposIdentificacion(
                ctrl: _id,
                alCambiarTipo: () => setState(() {}),
                ayuda: 'El contador los necesita para soportar tus gastos.'),
            const SizedBox(height: 16),
            FilledButton(onPressed: _guardar, child: const Text('Guardar')),
          ]),
        ),
      ),
    );
  }
}

/// Elegir a quién se le pagó (o crear uno nuevo ahí mismo). Devuelve el id,
/// '' si se eligió «Nadie en particular», o null si se cerró.
Future<String?> elegirTercero(BuildContext context, {String? actual, String claseNuevo = 'otro'}) async {
  final lista = await LocalDb.instance.proveedores();
  if (!context.mounted) return null;
  final r = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (c) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.7),
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 16), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text('¿A quién le pagaste?', style: Theme.of(c).textTheme.titleLarge),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          leading: const Icon(Icons.person_add_alt_1_outlined),
          title: const Text('Nuevo proveedor o tercero'),
          onTap: () => Navigator.pop(c, '+'),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          leading: const Icon(Icons.person_off_outlined),
          title: const Text('Nadie en particular'),
          onTap: () => Navigator.pop(c, ''),
        ),
        for (final x in lista)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: Icon(iconoClase(x['clase'] as String? ?? 'proveedor')),
            title: Text(x['nombre'] as String),
            subtitle: Text(nombreClase(x['clase'] as String? ?? 'proveedor')),
            selected: x['id'] == actual,
            onTap: () => Navigator.pop(c, x['id'] as String),
          ),
      ]),
    ),
  );
  if (r == '+' && context.mounted) {
    return mostrarFormTercero(context, claseInicial: claseNuevo);
  }
  return r;
}
