import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import '../data/sync_service.dart';
import 'comun.dart';

/// Expiración de sesión por inactividad (OWASP M3): si la app no se usa
/// durante [Config.minutosInactividad] minutos, se cierra la sesión de la
/// nube. Los datos locales siguen disponibles y cifrados; para volver a
/// sincronizar hay que iniciar sesión otra vez.
class InactividadGuard extends StatefulWidget {
  final Widget child;
  const InactividadGuard({super.key, required this.child});
  @override
  State<InactividadGuard> createState() => _InactividadGuardState();
}

class _InactividadGuardState extends State<InactividadGuard>
    with WidgetsBindingObserver {
  DateTime _ultimo = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _revisar());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _revisar();
      SyncService.instance.sync();
    }
  }

  Future<void> _revisar() async {
    if (SyncService.instance.remoto == null) return;
    const limite = Duration(minutes: Config.minutosInactividad);
    if (DateTime.now().difference(_ultimo) < limite) return;
    _ultimo = DateTime.now();
    try {
      final auth = Supabase.instance.client.auth;
      if (auth.currentSession == null) return;
      await auth.signOut();
    } catch (_) {
      // sin red: la sesión local se limpia igual en el siguiente intento
    }
    avisar('Por seguridad cerramos tu sesión por inactividad. '
        'Tus datos siguen guardados en el celular.');
    SyncService.instance.sync();
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _ultimo = DateTime.now(),
        child: widget.child,
      );
}
