import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/local_db.dart';
import '../domain/perfiles.dart';
import '../domain/roles.dart';
import 'tema.dart' show AvatarCliente;
import 'comun.dart';
import 'login_page.dart' show confirmarClaveCuenta, correoSesion;

/// Si en este celular hay perfiles, nadie entra sin decir quién es (con su
/// PIN). Sin perfiles, la app abre directo como siempre.
///
/// El PIN oculta lo que el rol de esa persona no permite y deja el nombre en
/// cada venta; no reemplaza la cuenta: lo que de verdad se puede hacer lo
/// decide el servidor según el rol de la cuenta.
class PerfilGate extends StatefulWidget {
  final Widget child;
  const PerfilGate({super.key, required this.child});
  @override
  State<PerfilGate> createState() => _PerfilGateState();
}

class _PerfilGateState extends State<PerfilGate> {
  final db = LocalDb.instance;
  List<Perfil>? _perfiles;

  @override
  void initState() {
    super.initState();
    db.cambios.addListener(_cargar);
    db.perfilActivo.addListener(_refrescar);
    _cargar();
  }

  @override
  void dispose() {
    db.cambios.removeListener(_cargar);
    db.perfilActivo.removeListener(_refrescar);
    super.dispose();
  }

  void _refrescar() => setState(() {});

  Future<void> _cargar() async {
    final l = await db.perfiles();
    if (mounted) setState(() => _perfiles = l);
  }

  @override
  Widget build(BuildContext context) {
    final l = _perfiles;
    if (l == null) return const Scaffold(body: SizedBox.shrink());
    if (l.isEmpty || db.perfilActivo.value != null) return widget.child;
    return QuienAtiendePage(perfiles: l);
  }
}

/// «¿Quién atiende?»: se elige el nombre y se escribe el PIN.
class QuienAtiendePage extends StatelessWidget {
  final List<Perfil> perfiles;
  const QuienAtiendePage({super.key, required this.perfiles});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          children: [
            Text('¿Quién atiende?', style: t.headlineSmall),
            const SizedBox(height: 6),
            Text('Toca tu nombre y escribe tu PIN. Lo que registres quedará a tu nombre.',
                style: t.bodyMedium),
            const SizedBox(height: 20),
            for (final p in perfiles)
              Card(
                child: ListTile(
                  key: ValueKey('perfil_${p.nombre}'),
                  minVerticalPadding: 14,
                  leading: AvatarCliente(nombre: p.nombre, clave: p.id, tam: 40),
                  title: Text(p.nombre, style: t.titleMedium),
                  subtitle: Text(nombreRol(p.rol)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => pedirPin(context, p),
                ),
              ),
            if (correoSesion() != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                key: const ValueKey('olvide_pin_dueno'),
                onPressed: () => _recuperarConCuenta(context),
                icon: const Icon(Icons.key_outlined),
                label: const Text('Soy el dueño y olvidé mi PIN'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// El dueño entra con la clave de su cuenta (necesita internet) y luego
/// cambia su PIN en Equipo.
Future<void> _recuperarConCuenta(BuildContext context) async {
  final clave = await dialogoConTexto<String>(
    context,
    builder: (c, ctrl) => AlertDialog(
      title: const Text('Entrar con la cuenta'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Escribe la clave de la cuenta ${correoSesion() ?? ''}. Se necesita internet.'),
        const SizedBox(height: 12),
        TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Clave de la cuenta'),
          onSubmitted: (v) => Navigator.pop(c, v),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Entrar')),
      ],
    ),
  );
  if (clave == null || clave.isEmpty) return;
  if (await confirmarClaveCuenta(clave)) {
    LocalDb.instance.entrarComoCuenta();
    avisar('Entraste con la cuenta. Cambia tu PIN en Más opciones > Equipo.');
  } else {
    avisar('No se pudo confirmar: revisa la clave y la conexión.');
  }
}

/// Teclado de PIN. Devuelve true si entró.
Future<bool> pedirPin(BuildContext context, Perfil p) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TecladoPin(perfil: p),
    ) ??
    false;

/// Un dueño o administrador del celular autoriza algo con su PIN (por
/// ejemplo, anular cuando atiende un despachador). Devuelve su nombre, o
/// null si no autorizó.
Future<String?> autorizarSupervisor(BuildContext context, {required String que}) async {
  final supervisores = [
    for (final p in await LocalDb.instance.perfiles())
      if (p.rol == Rol.dueno || p.rol == Rol.administrador) p
  ];
  if (!context.mounted) return null;
  if (supervisores.isEmpty) {
    avisar('No hay un perfil de dueño o administrador en este celular para autorizar.');
    return null;
  }
  final elegido = supervisores.length == 1
      ? supervisores.first
      : await showDialog<Perfil>(
          context: context,
          builder: (c) => SimpleDialog(
            title: Text('¿Quién autoriza $que?'),
            children: [
              for (final p in supervisores)
                SimpleDialogOption(
                  key: ValueKey('autoriza_${p.nombre}'),
                  onPressed: () => Navigator.pop(c, p),
                  child: Text('${p.nombre} (${nombreRol(p.rol).toLowerCase()})'),
                ),
            ],
          ),
        );
  if (elegido == null || !context.mounted) return null;
  final ok = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _TecladoPin(perfil: elegido, soloAutorizar: true, que: que),
      ) ??
      false;
  return ok ? elegido.nombre : null;
}

class _TecladoPin extends StatefulWidget {
  final Perfil perfil;

  /// Solo revisa el PIN (quien atiende no cambia).
  final bool soloAutorizar;
  final String que;
  const _TecladoPin({required this.perfil, this.soloAutorizar = false, this.que = ''});
  @override
  State<_TecladoPin> createState() => _TecladoPinState();
}

class _TecladoPinState extends State<_TecladoPin> {
  final db = LocalDb.instance;
  String _pin = '';
  String? _error;
  int _espera = 0;
  bool _revisando = false;
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    _mirarEspera();
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  Future<void> _mirarEspera() async {
    final s = await db.esperaPin();
    if (!mounted) return;
    setState(() => _espera = s);
    _reloj?.cancel();
    if (s > 0) {
      _reloj = Timer.periodic(const Duration(seconds: 1), (_) async {
        final r = await db.esperaPin();
        if (!mounted) return;
        setState(() => _espera = r);
        if (r == 0) _reloj?.cancel();
      });
    }
  }

  void _tecla(String d) {
    if (_espera > 0 || _revisando || _pin.length >= 6) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _error = null;
    });
  }

  void _borrar() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _entrar() async {
    if (_pin.length < 4 || _revisando) return;
    setState(() => _revisando = true);
    final ok = widget.soloAutorizar
        ? await db.verificarPin(widget.perfil.id, _pin) != null
        : await db.entrarComo(widget.perfil.id, _pin);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _revisando = false;
      _pin = '';
      _error = 'PIN equivocado';
    });
    await _mirarEspera();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    Widget boton(String d) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: SizedBox(
              height: 56,
              child: OutlinedButton(
                key: ValueKey('tecla_$d'),
                onPressed: () => _tecla(d),
                child: Text(d, style: t.titleLarge),
              ),
            ),
          ),
        );
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.perfil.nombre, style: t.titleLarge),
        const SizedBox(height: 4),
        Text(widget.soloAutorizar ? 'Escribe tu PIN para autorizar ${widget.que}' : 'Escribe tu PIN',
            textAlign: TextAlign.center, style: t.bodyMedium),
        const SizedBox(height: 16),
        Semantics(
          label: '${_pin.length} números escritos',
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < 6; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length ? cs.primary : Colors.transparent,
                  border: Border.all(color: i < 4 || i < _pin.length ? cs.primary : cs.outlineVariant),
                ),
              ),
          ]),
        ),
        SizedBox(
          height: 32,
          child: Center(
            child: Text(
              _espera > 0
                  ? 'Demasiados intentos. Espera $_espera s.'
                  : (_error ?? ''),
              style: t.bodyMedium?.copyWith(color: cs.error),
            ),
          ),
        ),
        for (final fila in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(children: [for (final d in fila) boton(d)]),
        Row(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: SizedBox(
                height: 56,
                child: TextButton(
                  key: const ValueKey('tecla_borrar'),
                  onPressed: _borrar,
                  child: const Icon(Icons.backspace_outlined, semanticLabel: 'Borrar'),
                ),
              ),
            ),
          ),
          boton('0'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: SizedBox(
                height: 56,
                child: FilledButton(
                  key: const ValueKey('tecla_entrar'),
                  onPressed: _pin.length >= 4 && _espera == 0 && !_revisando ? _entrar : null,
                  child: _revisando
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(widget.soloAutorizar ? 'Autorizar' : 'Entrar'),
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Text('¿Olvidaste el PIN? Pide a quien maneja el negocio que te lo cambie en Equipo.',
            textAlign: TextAlign.center, style: t.bodySmall),
      ]),
    );
  }
}
