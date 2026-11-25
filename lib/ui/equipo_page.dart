import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/equipo_service.dart';
import '../data/local_db.dart';
import '../data/sync_service.dart';
import '../domain/invitaciones.dart';
import '../domain/perfiles.dart';
import '../domain/roles.dart';
import 'comun.dart';
import 'login_page.dart' show correoSesion, mostrarLogin;
import 'tema.dart' show AvatarCliente;

/// Equipo: quién trabaja en el negocio (cuentas, lo maneja el servidor) y
/// quién usa este celular (perfiles con PIN, solo aquí).
class EquipoPage extends StatefulWidget {
  /// Para las pruebas; en la app se arma con la conexión de la nube.
  final EquipoService? servicio;
  const EquipoPage({super.key, this.servicio});
  @override
  State<EquipoPage> createState() => _EquipoPageState();
}

class _EquipoPageState extends State<EquipoPage> {
  final db = LocalDb.instance;
  late Future<List<MiembroEquipo>>? _miembros;
  List<Perfil> _perfiles = const [];

  EquipoService? get _servicio {
    if (widget.servicio != null) return widget.servicio;
    final api = SyncService.instance.remoto;
    return api == null ? null : EquipoService(db, api);
  }

  bool get _haySesion => widget.servicio?.api.haySesion ?? correoSesion() != null;

  @override
  void initState() {
    super.initState();
    db.cambios.addListener(_cargarPerfiles);
    _cargarMiembros();
    _cargarPerfiles();
  }

  @override
  void dispose() {
    db.cambios.removeListener(_cargarPerfiles);
    super.dispose();
  }

  void _cargarMiembros() {
    final s = _servicio;
    _miembros = s != null && _haySesion && db.puede(Permiso.configurarNegocio) ? s.miembros() : null;
  }

  Future<void> _cargarPerfiles() async {
    final l = await db.perfiles();
    if (mounted) setState(() => _perfiles = l);
  }

  void _recargar() => setState(_cargarMiembros);

  Future<void> _hacer(Future<void> Function() f, {String? listo}) async {
    try {
      await f();
      if (listo != null) avisar(listo);
    } on ErrorEquipo catch (e) {
      avisar(e.mensaje);
    }
    if (mounted) _recargar();
  }

  // ------------------------------------------------------------- invitar
  Future<void> _invitar() async {
    final s = _servicio;
    if (s == null) return;
    final rol = await _elegirRol(context, titulo: '¿Qué hará esta persona?', opciones: rolesInvitables);
    if (rol == null || !mounted) return;
    String codigo;
    try {
      codigo = await s.invitar(rol);
    } on ErrorEquipo catch (e) {
      avisar(e.mensaje);
      return;
    }
    if (!mounted) return;
    final negocio = (await db.ajuste('negocio_nombre')) ?? '';
    final mensaje = mensajeInvitacion(negocio: negocio, rol: rol, codigo: codigo);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Invitación para ${nombreRol(rol).toLowerCase()}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Comparte este código. Sirve una sola vez y vence en $diasInvitacion días.'),
          const SizedBox(height: 16),
          SelectableText(formatearCodigo(codigo),
              key: const ValueKey('codigo_invitacion'),
              textAlign: TextAlign.center,
              style: Theme.of(c).textTheme.headlineMedium?.copyWith(letterSpacing: 3, fontWeight: FontWeight.w700)),
        ]),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: formatearCodigo(codigo)));
              avisar('Código copiado');
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copiar'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(c);
              enviarWhatsApp(mensaje);
            },
            icon: const Icon(Icons.send),
            label: const Text('Enviar por WhatsApp'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- unirse
  Future<void> _unirse() async {
    final s = _servicio;
    if (s == null) return;
    if (!_haySesion) {
      await mostrarLogin(context);
      if (!mounted || !_haySesion) return;
    }
    final codigo = await dialogoConTexto<String>(
      context,
      builder: (c, ctrl) => AlertDialog(
        title: const Text('Unirme a un negocio'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Escribe el código que te envió el dueño del negocio. '
              'Desde ese momento verás lo que tu rol permite y lo que registres será del negocio.'),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('campo_codigo'),
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Código', hintText: 'ABCD-EFGH'),
            onSubmitted: (v) => Navigator.pop(c, v),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Unirme')),
        ],
      ),
    );
    if (codigo == null || codigo.trim().isEmpty) return;
    try {
      final rol = await s.unirse(codigo);
      avisar('Listo: entraste como ${nombreRol(rol).toLowerCase()}. Bajando los datos del negocio…');
      SyncService.instance.sync();
    } on ErrorEquipo catch (e) {
      avisar(e.mensaje);
    }
    if (mounted) _recargar();
  }

  // ------------------------------------------------------------- miembros
  Future<void> _opcionesMiembro(MiembroEquipo m, String accion) async {
    final s = _servicio;
    if (s == null) return;
    if (accion == 'rol') {
      final rol = await _elegirRol(context,
          titulo: 'Nuevo rol de ${m.correo}', opciones: rolesInvitables, actual: m.rol);
      if (rol == null || rol == m.rol) return;
      await _hacer(() => s.cambiarRol(m, rol), listo: 'Rol cambiado a ${nombreRol(rol).toLowerCase()}');
    } else {
      final ok = await confirmar(context, '¿Quitar a ${m.correo} del equipo?',
          'Dejará de ver los datos del negocio. Lo que ya registró se queda. '
              'Si tenía algo sin subir en su celular, no se subirá.');
      if (!ok) return;
      await _hacer(() => s.quitar(m), listo: 'Se quitó del equipo');
    }
  }

  // ------------------------------------------------------------ descuentos
  static String _pct(double p) => p == p.roundToDouble() ? p.toInt().toString() : p.toStringAsFixed(1);

  Future<void> _cambiarTope() async {
    final pct = await dialogoConTexto<double>(
      context,
      texto: _pct(db.equipo.value.descuentoMaxPct),
      builder: (c, ctrl) => AlertDialog(
        title: const Text('Tope de descuento'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('¿Hasta qué porcentaje del total pueden descontar tus empleados? 0 = ninguno.'),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('campo_tope'),
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Porcentaje', suffixText: '%'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          FilledButton(
            key: const ValueKey('guardar_tope'),
            onPressed: () {
              final v = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
              if (v != null && v >= 0 && v <= 100) Navigator.pop(c, v);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (pct == null) return;
    final s = _servicio;
    if (s == null) {
      // Sin nube: solo aplica a los perfiles de este celular.
      await db.guardarContexto(db.equipo.value.copiar(descuentoMaxPct: pct));
      if (mounted) setState(() {});
      avisar('Tope guardado');
    } else {
      await _hacer(() => s.definirDescuentoMaximo(pct), listo: 'Tope guardado');
    }
  }

  // ------------------------------------------------------------- perfiles
  Future<void> _nuevoPerfil() async {
    final primero = _perfiles.isEmpty;
    final datos = await showDialog<(String, Rol, String)>(
      context: context,
      builder: (_) => _FormPerfil(primero: primero, roles: rolesParaPerfil(db.equipo.value), rolCuenta: db.equipo.value.rol),
    );
    if (datos == null) return;
    try {
      await db.crearPerfil(datos.$1, datos.$2, datos.$3);
      if (primero) {
        // Quien lo creó queda atendiendo con su perfil.
        final p = (await db.perfiles()).firstWhere((x) => x.nombre.toLowerCase() == datos.$1.trim().toLowerCase());
        await db.entrarComo(p.id, datos.$3);
      }
      avisar('Perfil creado');
    } on StateError {
      avisar('Ya hay un perfil con ese nombre');
    } on ArgumentError {
      avisar('Revisa el nombre, el rol y el PIN');
    }
  }

  Future<void> _cambiarPin(Perfil p) async {
    final pin = await showDialog<String>(context: context, builder: (_) => _FormPin(nombre: p.nombre));
    if (pin == null) return;
    await db.cambiarPin(p.id, pin);
    avisar('PIN de ${p.nombre} cambiado');
  }

  Future<void> _quitarPerfil(Perfil p) async {
    final ok = await confirmar(context, '¿Quitar el perfil de ${p.nombre}?',
        'Ya no podrá entrar en este celular. Sus ventas conservan su nombre.');
    if (ok) await db.quitarPerfil(p.id);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ctx = db.equipo.value;
    final atiende = db.perfilActivo.value;
    final manejaEquipo = db.puede(Permiso.gestionarEquipo);
    final manejaPerfiles = db.puede(Permiso.configurarNegocio);
    final nube = _servicio != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Equipo')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text('Tu cuenta: ${nombreRol(ctx.rol)}'),
              subtitle: Text([
                descripcionRol(ctx.rol),
                if (atiende != null && atiende.nombre.isNotEmpty)
                  'Atiende ${atiende.nombre} (${nombreRol(atiende.rol).toLowerCase()}).',
              ].join('\n')),
            ),
          ),
          const SizedBox(height: 20),
          Text('Personas con cuenta', style: t.titleMedium),
          const SizedBox(height: 4),
          Text('Cada quien entra desde su propio celular con su correo y ve solo lo que su rol permite.',
              style: t.bodySmall),
          const SizedBox(height: 8),
          if (!nube)
            const Card(
              child: ListTile(
                leading: Icon(Icons.cloud_off_outlined),
                title: Text('Esta versión funciona solo en el celular'),
                subtitle: Text('Para tener empleados con cuenta se necesita la nube.'),
              ),
            )
          else if (!_haySesion)
            Card(
              child: ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Inicia sesión para manejar el equipo'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await mostrarLogin(context);
                  if (mounted) _recargar();
                },
              ),
            )
          else ...[
            if (manejaEquipo)
              FilledButton.icon(
                key: const ValueKey('invitar'),
                onPressed: _invitar,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Invitar a alguien'),
              ),
            if (_miembros != null)
              FutureBuilder<List<MiembroEquipo>>(
                future: _miembros,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                        padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                  }
                  if (snap.hasError) {
                    final e = snap.error;
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: Text(e is ErrorEquipo ? e.mensaje : 'No se pudo cargar el equipo'),
                        trailing: IconButton(
                            tooltip: 'Intentar de nuevo', onPressed: _recargar, icon: const Icon(Icons.refresh)),
                      ),
                    );
                  }
                  return Column(children: [
                    for (final m in snap.data!)
                      Card(
                        child: ListTile(
                          key: ValueKey('miembro_${m.correo}'),
                          leading: AvatarCliente(nombre: m.correo, clave: m.userId, tam: 36),
                          title: Text(m.correo, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(nombreRol(m.rol)),
                          trailing: manejaEquipo && m.rol != Rol.dueno
                              ? PopupMenuButton<String>(
                                  tooltip: 'Opciones',
                                  onSelected: (a) => _opcionesMiembro(m, a),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'rol', child: Text('Cambiar rol')),
                                    PopupMenuItem(value: 'quitar', child: Text('Quitar del equipo')),
                                  ],
                                )
                              : null,
                        ),
                      ),
                  ]);
                },
              ),
            if (manejaEquipo)
              SwitchListTile(
                key: const ValueKey('switch_fia'),
                contentPadding: EdgeInsets.zero,
                title: const Text('El vendedor puede fiar y recibir abonos'),
                subtitle: const Text('Si lo apagas, solo vende de contado.'),
                value: ctx.despachadorFia,
                onChanged: (v) => _hacer(() => _servicio!.definirDespachadorFia(v)),
              ),
            if (ctx.rol == Rol.dueno && (atiende == null || atiende.nombre.isEmpty))
              TextButton.icon(
                key: const ValueKey('tengo_codigo'),
                onPressed: _unirse,
                icon: const Icon(Icons.vpn_key_outlined),
                label: const Text('Me invitaron a otro negocio: tengo un código'),
              ),
          ],
          if (manejaEquipo && (!nube || _haySesion)) ...[
            const SizedBox(height: 24),
            Text('Descuentos', style: t.titleMedium),
            const SizedBox(height: 4),
            Card(
              child: ListTile(
                key: const ValueKey('tope_descuento'),
                leading: const Icon(Icons.percent),
                title: Text(ctx.descuentoMaxPct <= 0
                    ? 'Nadie más que tú puede dar descuentos'
                    : 'Tope de descuento: ${_pct(ctx.descuentoMaxPct)} % del total'),
                subtitle: const Text('Para todos menos el dueño. Lo hace cumplir el servidor.'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: _cambiarTope,
              ),
            ),
          ],
          if (manejaPerfiles) ...[
            const SizedBox(height: 24),
            Text('Perfiles en este celular', style: t.titleMedium),
            const SizedBox(height: 4),
            Text(
                'Para cuando varias personas usan este mismo celular. Cada una entra con su PIN, '
                've lo que su rol permite y la app guarda quién hizo cada venta. '
                'El PIN no reemplaza la cuenta: quien decide lo que se puede hacer es el servidor.',
                style: t.bodySmall),
            const SizedBox(height: 8),
            for (final p in _perfiles)
              Card(
                child: ListTile(
                  key: ValueKey('perfil_${p.nombre}'),
                  leading: AvatarCliente(nombre: p.nombre, clave: p.id, tam: 36),
                  title: Text(p.nombre),
                  subtitle: Text(nombreRol(p.rol) + (atiende?.id == p.id ? ' · atendiendo ahora' : '')),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Opciones',
                    onSelected: (a) => a == 'pin' ? _cambiarPin(p) : _quitarPerfil(p),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'pin', child: Text('Cambiar PIN')),
                      PopupMenuItem(value: 'quitar', child: Text('Quitar perfil')),
                    ],
                  ),
                ),
              ),
            OutlinedButton.icon(
              key: const ValueKey('agregar_perfil'),
              onPressed: _nuevoPerfil,
              icon: const Icon(Icons.add),
              label: Text(_perfiles.isEmpty ? 'Empezar a usar perfiles' : 'Agregar perfil'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lista de roles con su descripción para elegir uno.
Future<Rol?> _elegirRol(BuildContext context,
        {required String titulo, required List<Rol> opciones, Rol? actual}) =>
    showDialog<Rol>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(titulo),
        children: [
          for (final r in opciones)
            SimpleDialogOption(
              key: ValueKey('rol_${r.name}'),
              onPressed: () => Navigator.pop(c, r),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(r == actual ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                title: Text(nombreRol(r)),
                subtitle: Text(descripcionRol(r)),
              ),
            ),
        ],
      ),
    );

/// Nombre, rol y PIN (dos veces) de un perfil nuevo. El primero es el de
/// quien maneja el celular, con el rol de la cuenta: así nunca queda
/// encerrado fuera de su propio negocio.
class _FormPerfil extends StatefulWidget {
  final bool primero;
  final List<Rol> roles;
  final Rol rolCuenta;
  const _FormPerfil({required this.primero, required this.roles, required this.rolCuenta});
  @override
  State<_FormPerfil> createState() => _FormPerfilState();
}

class _FormPerfilState extends State<_FormPerfil> {
  final _nombre = TextEditingController();
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();
  late Rol _rol = widget.primero ? widget.rolCuenta : widget.roles.last;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _pin.dispose();
    _pin2.dispose();
    super.dispose();
  }

  void _guardar() {
    final n = _nombre.text.trim();
    final e = n.length < 2
        ? 'Escribe el nombre'
        : problemaPin(_pin.text) ?? (_pin.text != _pin2.text ? 'Los dos PIN no coinciden' : null);
    if (e != null) {
      setState(() => _error = e);
      return;
    }
    Navigator.pop(context, (n, _rol, _pin.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.primero ? 'Tu perfil primero' : 'Nuevo perfil'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (widget.primero)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Desde ahora la app preguntará quién atiende. Empieza por ti, '
                  'con tu rol, y luego agrega a los demás.'),
            ),
          TextField(
            key: const ValueKey('perfil_nombre'),
            controller: _nombre,
            textCapitalization: TextCapitalization.words,
            maxLength: 40,
            decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej.: Luis'),
          ),
          if (!widget.primero)
            DropdownButtonFormField<Rol>(
              key: const ValueKey('perfil_rol'),
              initialValue: _rol,
              decoration: const InputDecoration(labelText: 'Rol'),
              items: [for (final r in widget.roles) DropdownMenuItem(value: r, child: Text(nombreRol(r)))],
              onChanged: (r) => setState(() => _rol = r ?? _rol),
            ),
          TextField(
            key: const ValueKey('perfil_pin'),
            controller: _pin,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            decoration: const InputDecoration(labelText: 'PIN (4 a 6 números)'),
          ),
          TextField(
            key: const ValueKey('perfil_pin2'),
            controller: _pin2,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            decoration: const InputDecoration(labelText: 'Repite el PIN'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(key: const ValueKey('guardar_perfil'), onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}

class _FormPin extends StatefulWidget {
  final String nombre;
  const _FormPin({required this.nombre});
  @override
  State<_FormPin> createState() => _FormPinState();
}

class _FormPinState extends State<_FormPin> {
  final _pin = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Nuevo PIN de ${widget.nombre}'),
        content: TextField(
          controller: _pin,
          obscureText: true,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          decoration: InputDecoration(labelText: 'PIN (4 a 6 números)', errorText: _error),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final e = problemaPin(_pin.text);
              if (e != null) {
                setState(() => _error = e);
              } else {
                Navigator.pop(context, _pin.text);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      );
}
