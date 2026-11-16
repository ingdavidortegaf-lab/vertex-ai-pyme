import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/local_db.dart';
import '../data/sync_service.dart';
import 'comun.dart';

const _maxFallos = 5;
const _minutosBloqueo = 5;

/// Inicio de sesión. Necesita conexión solo para entrar; la sesión se
/// conserva en el dispositivo. Bloqueo de 5 minutos tras 5 intentos
/// fallidos (además del límite que aplica el propio servidor).
Future<void> mostrarLogin(BuildContext context) async {
  SupabaseClient? sb;
  try {
    sb = Supabase.instance.client;
  } catch (_) {}
  if (sb == null || SyncService.instance.remoto == null) {
    avisar('Modo local: esta versión no está conectada a la nube.');
    return;
  }

  final sesion = sb.auth.currentSession;
  if (sesion != null) {
    final salir = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sesión iniciada'),
        content: Text(sb!.auth.currentUser?.email ?? ''),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Volver')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (salir == true) {
      try {
        await sb.auth.signOut();
      } catch (_) {}
      SyncService.instance.sync();
    }
    return;
  }

  final db = LocalDb.instance;
  final bloqueo = DateTime.tryParse(await db.ajuste('login_bloqueo') ?? '');
  if (bloqueo != null && DateTime.now().isBefore(bloqueo)) {
    final min = bloqueo.difference(DateTime.now()).inMinutes + 1;
    avisar('Demasiados intentos. Intenta de nuevo en $min min.');
    return;
  }
  if (!context.mounted) return;

  final datos = await showDialog<(String, String)>(
    context: context,
    builder: (_) => const _LoginDialog(),
  );
  if (datos == null) return;
  final (correo, clave) = datos;

  try {
    await sb.auth.signInWithPassword(email: correo, password: clave);
    await db.borrarAjuste('login_fallos');
    await db.borrarAjuste('login_bloqueo');
    avisar('Sesión iniciada. Sincronizando…');
    SyncService.instance.sync();
  } on AuthException catch (e) {
    final credenciales = e.statusCode == '400' || e.statusCode == '401';
    if (!credenciales) {
      avisar('No se pudo conectar. Revisa tu conexión e intenta de nuevo.');
      return;
    }
    final fallos = (int.tryParse(await db.ajuste('login_fallos') ?? '') ?? 0) + 1;
    if (fallos >= _maxFallos) {
      await db.setAjuste('login_bloqueo',
          DateTime.now().add(const Duration(minutes: _minutosBloqueo)).toIso8601String());
      await db.borrarAjuste('login_fallos');
      avisar('Demasiados intentos fallidos. Espera $_minutosBloqueo minutos.');
    } else {
      await db.setAjuste('login_fallos', '$fallos');
      avisar('Correo o clave incorrectos (${_maxFallos - fallos} intentos restantes).');
    }
  } catch (_) {
    avisar('No se pudo conectar. Revisa tu conexión e intenta de nuevo.');
  }
}

class _LoginDialog extends StatefulWidget {
  const _LoginDialog();
  @override
  State<_LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<_LoginDialog> {
  final _form = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  bool _ver = false;

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Iniciar sesión'),
        content: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: _correo,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Correo'),
              validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                      .hasMatch(v?.trim() ?? '')
                  ? null
                  : 'Escribe un correo válido',
            ),
            TextFormField(
              controller: _clave,
              obscureText: !_ver,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Clave',
                suffixIcon: IconButton(
                  icon: Icon(_ver ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _ver = !_ver),
                ),
              ),
              validator: (v) =>
                  (v ?? '').isEmpty ? 'Escribe tu clave' : null,
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (_form.currentState!.validate()) {
                Navigator.pop(context, (_correo.text.trim(), _clave.text));
              }
            },
            child: const Text('Entrar'),
          ),
        ],
      );
}
