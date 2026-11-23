import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../data/local_db.dart';
import '../data/sync_service.dart';
import 'comun.dart';
import 'ilustraciones.dart';
import 'tema.dart';

const _maxFallos = 5;
const _minutosBloqueo = 5;
const _claveMinima = 8;

/// Política de contraseña robusta (bases 4.4.3): mínimo 8 caracteres, con
/// letras y números. Devuelve el problema o null si la clave sirve.
String? problemaClave(String c) {
  if (c.length < _claveMinima) return 'Usa al menos $_claveMinima caracteres';
  if (!RegExp(r'[A-Za-zÁÉÍÓÚáéíóúÑñ]').hasMatch(c)) return 'Incluye al menos una letra';
  if (!RegExp(r'[0-9]').hasMatch(c)) return 'Incluye al menos un número';
  if (c.trim() != c) return 'No empieces ni termines con espacios';
  return null;
}

SupabaseClient? _cliente() {
  if (SyncService.instance.remoto == null) return null;
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}

/// Correo de la sesión abierta, o null si no hay sesión (o no hay nube).
String? correoSesion() => _cliente()?.auth.currentUser?.email;

/// Confirma la clave de la cuenta abierta (para recuperar el PIN del dueño).
/// Necesita internet. Devuelve false si la clave no es o no hay conexión.
Future<bool> confirmarClaveCuenta(String clave) async {
  final sb = _cliente();
  final correo = sb?.auth.currentUser?.email;
  if (sb == null || correo == null) return false;
  try {
    await sb.auth.signInWithPassword(email: correo, password: clave).timeout(const Duration(seconds: 20));
    return true;
  } catch (_) {
    return false;
  }
}

/// Abre la pantalla de cuenta: entrar, crear cuenta o ver la sesión.
Future<void> mostrarLogin(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute(builder: (_) => const CuentaPage()));

/// Cuenta en la nube. Necesita conexión solo para entrar o crear la cuenta;
/// la sesión se conserva en el celular. Bloqueo de 5 minutos tras 5 intentos
/// fallidos (además del límite que aplica el propio servidor).
class CuentaPage extends StatefulWidget {
  const CuentaPage({super.key});
  @override
  State<CuentaPage> createState() => _CuentaPageState();
}

class _CuentaPageState extends State<CuentaPage> {
  final _sb = _cliente();
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _sb?.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sb = _sb;
    final Widget cuerpo;
    if (sb == null) {
      cuerpo = const _ModoLocal();
    } else if (sb.auth.currentSession != null) {
      cuerpo = _Perfil(sb: sb);
    } else {
      cuerpo = _Acceso(sb: sb);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Tu cuenta')),
      body: SafeArea(top: false, child: cuerpo),
    );
  }
}

/// Encabezado de pizarra con ilustración, título y texto.
class _Cabecera extends StatelessWidget {
  final Widget ilustracion;
  final String titulo;
  final String texto;
  const _Cabecera(
      {required this.ilustracion, required this.titulo, required this.texto});

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    final t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      decoration: BoxDecoration(
        color: p.pizarra,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(children: [
        SizedBox(width: 168, height: 140, child: ilustracion),
        const SizedBox(height: 12),
        Text(titulo,
            textAlign: TextAlign.center,
            style: t.headlineSmall?.copyWith(color: p.tizaBlanca)),
        const SizedBox(height: 8),
        Text(texto,
            textAlign: TextAlign.center,
            style: t.bodyLarge?.copyWith(color: p.tizaSuave)),
      ]),
    );
  }
}

class _ModoLocal extends StatelessWidget {
  const _ModoLocal();
  @override
  Widget build(BuildContext context) => ListView(children: const [
        _Cabecera(
          ilustracion: IlustracionPizarra(),
          titulo: 'Todo se guarda en este celular',
          texto: 'Esta versión de la app funciona sin nube. Tus clientes, '
              'ventas y cobros quedan guardados y cifrados en el celular.',
        ),
      ]);
}

// ------------------------------------------------------------- acceso
class _Acceso extends StatefulWidget {
  final SupabaseClient sb;
  const _Acceso({required this.sb});
  @override
  State<_Acceso> createState() => _AccesoState();
}

class _AccesoState extends State<_Acceso> {
  final _form = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  final _clave2 = TextEditingController();
  bool _crear = false;
  bool _ver = false;
  bool _ocupado = false;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    _clave2.dispose();
    super.dispose();
  }

  String _mensajeAuth(AuthException e) {
    switch (e.code) {
      case 'invalid_credentials':
        return 'Correo o clave incorrectos.';
      case 'email_not_confirmed':
        return 'Primero confirma tu correo: abre el enlace que te enviamos.';
      case 'user_already_exists':
      case 'email_exists':
        return 'Ya existe una cuenta con ese correo. Entra con tu clave.';
      case 'weak_password':
        return 'La clave es muy débil. Usa al menos $_claveMinima caracteres '
            'con letras y números.';
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return 'Demasiados intentos seguidos. Espera unos minutos.';
      case 'signup_disabled':
        return 'La creación de cuentas está desactivada. Pide acceso al '
            'administrador.';
      case 'email_address_invalid':
        return 'Ese correo no es válido.';
    }
    return 'No se pudo completar. Revisa tu conexión e intenta de nuevo.';
  }

  Future<void> _enviar() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate() || _ocupado) return;
    final db = LocalDb.instance;
    if (!_crear) {
      final bloqueo = DateTime.tryParse(await db.ajuste('login_bloqueo') ?? '');
      if (bloqueo != null && DateTime.now().isBefore(bloqueo)) {
        final min = bloqueo.difference(DateTime.now()).inMinutes + 1;
        setState(() => _error = 'Demasiados intentos. Intenta de nuevo en $min min.');
        return;
      }
    }
    setState(() {
      _ocupado = true;
      _error = null;
    });
    final correo = _correo.text.trim();
    final clave = _clave.text;
    try {
      if (_crear) {
        final r = await widget.sb.auth.signUp(email: correo, password: clave);
        if (r.session != null) {
          avisar('Cuenta creada. Subiendo tus datos…');
          SyncService.instance.sync();
        } else if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (c) => AlertDialog(
              icon: const Icon(Icons.mark_email_read_outlined, size: 32),
              title: const Text('Revisa tu correo'),
              content: Text('Te enviamos un enlace a $correo para activar la '
                  'cuenta. Ábrelo y luego vuelve aquí para entrar con tu '
                  'correo y tu clave.'),
              actions: [
                FilledButton(
                    onPressed: () => Navigator.pop(c), child: const Text('Entendido')),
              ],
            ),
          );
          if (mounted) setState(() => _crear = false);
        }
      } else {
        await widget.sb.auth.signInWithPassword(email: correo, password: clave);
        await db.borrarAjuste('login_fallos');
        await db.borrarAjuste('login_bloqueo');
        avisar('Sesión iniciada. Sincronizando…');
        SyncService.instance.sync();
      }
    } on AuthException catch (e) {
      var msg = _mensajeAuth(e);
      final credenciales = e.code == 'invalid_credentials' ||
          (!_crear && (e.statusCode == '400' || e.statusCode == '401'));
      if (!_crear && credenciales) {
        final fallos = (int.tryParse(await db.ajuste('login_fallos') ?? '') ?? 0) + 1;
        if (fallos >= _maxFallos) {
          await db.setAjuste(
              'login_bloqueo',
              DateTime.now()
                  .add(const Duration(minutes: _minutosBloqueo))
                  .toIso8601String());
          await db.borrarAjuste('login_fallos');
          msg = 'Demasiados intentos fallidos. Espera $_minutosBloqueo minutos.';
        } else {
          await db.setAjuste('login_fallos', '$fallos');
          final quedan = _maxFallos - fallos;
          msg = 'Correo o clave incorrectos. '
              '${quedan == 1 ? 'Queda 1 intento' : 'Quedan $quedan intentos'}.';
        }
      }
      if (mounted) setState(() => _error = msg);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'No se pudo conectar. Revisa tu conexión e intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _olvide() async {
    final uri = Uri(
      scheme: 'mailto',
      path: Config.contactoPrivacidad,
      query: 'subject=${Uri.encodeComponent('Recuperar acceso a VERTEX AI Pyme')}',
    );
    try {
      if (!await launchUrl(uri)) {
        avisar('Escríbenos a ${Config.contactoPrivacidad}');
      }
    } catch (_) {
      avisar('Escríbenos a ${Config.contactoPrivacidad}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    return ListView(padding: EdgeInsets.zero, children: [
      _Cabecera(
        ilustracion: const IlustracionNube(),
        titulo: _crear ? 'Crea la cuenta de tu negocio' : 'Guarda tu negocio en la nube',
        texto: 'Tus datos se respaldan y puedes usarlos en otro celular. '
            'La app sigue funcionando sin señal.',
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Form(
          key: _form,
          child: AutofillGroup(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('Entrar')),
                  ButtonSegment(value: true, label: Text('Crear cuenta')),
                ],
                selected: {_crear},
                onSelectionChanged: _ocupado
                    ? null
                    : (s) => setState(() {
                          _crear = s.first;
                          _error = null;
                        }),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _correo,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                    labelText: 'Correo', prefixIcon: Icon(Icons.mail_outline)),
                validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(v?.trim() ?? '')
                    ? null
                    : 'Escribe un correo válido',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _clave,
                obscureText: !_ver,
                autofillHints: [
                  _crear ? AutofillHints.newPassword : AutofillHints.password
                ],
                textInputAction: _crear ? TextInputAction.next : TextInputAction.done,
                onFieldSubmitted: (_) => _crear ? null : _enviar(),
                decoration: InputDecoration(
                  labelText: 'Clave',
                  prefixIcon: const Icon(Icons.lock_outline),
                  helperText: _crear
                      ? 'Mínimo $_claveMinima caracteres, con letras y números'
                      : null,
                  suffixIcon: IconButton(
                    tooltip: _ver ? 'Ocultar clave' : 'Ver clave',
                    icon: Icon(_ver ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _ver = !_ver),
                  ),
                ),
                validator: (v) {
                  final c = v ?? '';
                  if (c.isEmpty) return 'Escribe tu clave';
                  if (_crear) return problemaClave(c);
                  return null;
                },
              ),
              if (_crear) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _clave2,
                  obscureText: !_ver,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _enviar(),
                  decoration: const InputDecoration(
                      labelText: 'Repite la clave',
                      prefixIcon: Icon(Icons.lock_outline)),
                  validator: (v) =>
                      v != _clave.text ? 'Las claves no coinciden' : null,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: esquema.errorContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    Icon(Icons.error_outline, color: esquema.onErrorContainer),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(_error!,
                            style: t.bodyMedium
                                ?.copyWith(color: esquema.onErrorContainer))),
                  ]),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _ocupado ? null : _enviar,
                child: _ocupado
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Text(_crear ? 'Crear cuenta' : 'Entrar'),
              ),
              if (!_crear)
                TextButton(
                  onPressed: _olvide,
                  child: const Text('¿Olvidaste tu clave?'),
                ),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.shield_outlined, size: 20, color: esquema.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Lo que ya registraste se queda en este celular y se sube '
                    'a tu cuenta al entrar. Cada negocio ve solo sus propios datos.',
                    style: t.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    ]);
  }
}

// -------------------------------------------------------------- perfil
class _Perfil extends StatelessWidget {
  final SupabaseClient sb;
  const _Perfil({required this.sb});

  Future<void> _salir(BuildContext context) async {
    final s = SyncService.instance;
    final pendientes = s.pendientes.value;
    final ok = await confirmar(
      context,
      'Cerrar sesión',
      pendientes > 0
          ? 'Hay $pendientes ${pendientes == 1 ? 'registro' : 'registros'} '
              'sin subir. Se quedan en este celular y se subirán cuando '
              'vuelvas a entrar.'
          : 'Tus datos se quedan en este celular. Para volver a sincronizar, '
              'entra de nuevo con tu correo y clave.',
      si: 'Cerrar sesión',
    );
    if (!ok) return;
    try {
      await sb.auth.signOut();
    } catch (_) {}
    s.sync();
    avisar('Sesión cerrada');
  }

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final correo = sb.auth.currentUser?.email ?? '';
    final s = SyncService.instance;
    return ListView(padding: EdgeInsets.zero, children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        decoration: BoxDecoration(
          color: p.pizarra,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: Column(children: [
          AvatarCliente(nombre: correo, clave: correo, tam: 76),
          const SizedBox(height: 14),
          Text(correo,
              textAlign: TextAlign.center,
              style: t.titleLarge?.copyWith(color: p.tizaBlanca)),
          const SizedBox(height: 4),
          Text('Administrador del negocio',
              style: t.bodyMedium?.copyWith(color: p.tizaSuave)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AnimatedBuilder(
            animation: Listenable.merge([s.estado, s.pendientes, s.errores]),
            builder: (context, _) {
              final e = s.estado.value;
              final ok = e == EstadoSync.sincronizado;
              return Card(
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: ok ? p.ventasFondo : p.fiadoFondo,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(ok ? Icons.cloud_done_outlined : Icons.cloud_sync_outlined,
                        color: ok ? p.ventas : p.fiado),
                  ),
                  title: Text(ok ? 'Todo está en la nube' : 'Sincronización'),
                  subtitle: Text(
                      textoEstado(e, s.pendientes.value, s.errores.value)),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              s.reintentarErrores();
              avisar('Sincronizando…');
            },
            icon: const Icon(Icons.sync),
            label: const Text('Sincronizar ahora'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _salir(context),
            style: OutlinedButton.styleFrom(foregroundColor: esquema.error),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
          const SizedBox(height: 20),
          Text(
            'Tus datos viajan cifrados y cada negocio ve solo los suyos. '
            'Para ejercer tus derechos sobre los datos escribe a '
            '${Config.contactoPrivacidad}.',
            style: t.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
          ),
        ]),
      ),
    ]);
  }
}
