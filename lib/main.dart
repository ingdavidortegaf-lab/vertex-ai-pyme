import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'data/local_db.dart';
import 'data/remote_api.dart';
import 'data/sync_service.dart';
import 'ui/comun.dart';
import 'ui/consent_gate.dart';
import 'ui/home_page.dart';
import 'ui/inactividad.dart';
import 'ui/tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_CO');
  Intl.defaultLocale = 'es_CO';

  try {
    await LocalDb.instance.open();
  } catch (_) {
    runApp(const _ErrorInicio());
    return;
  }

  final sync = SyncService.instance;
  if (Config.nubeConfigurada) {
    try {
      await Supabase.initialize(
          url: Config.supabaseUrl, publishableKey: Config.supabaseAnonKey);
      sync.remoto = SupabaseRemote(Supabase.instance.client);
    } catch (_) {
      // Sin nube: la app sigue funcionando en modo local.
    }
  }
  // Lo que quedó apartado por error en una sesión anterior se reintenta.
  try {
    await LocalDb.instance.reintentarErrores();
  } catch (_) {}
  sync.start();
  runApp(const VertexApp());
}

class VertexApp extends StatelessWidget {
  const VertexApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'VERTEX AI Pyme',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: mensajero,
        locale: const Locale('es', 'CO'),
        supportedLocales: const [Locale('es', 'CO'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: temaVertex(Brightness.light),
        darkTheme: temaVertex(Brightness.dark),
        themeMode: ThemeMode.system,
        // En el PC la app se ve como en el celular, centrada, para que no se
        // estire en pantallas anchas.
        builder: (context, child) {
          final ancho = MediaQuery.sizeOf(context).width;
          if (ancho <= 720 || child == null) return child ?? const SizedBox();
          return ColoredBox(
            color: const Color(0xFF17362C),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ClipRect(child: child),
              ),
            ),
          );
        },
        home: const ConsentGate(child: InactividadGuard(child: HomePage())),
      );
}

class _ErrorInicio extends StatelessWidget {
  const _ErrorInicio();
  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No se pudo abrir el almacenamiento seguro del celular. '
                'Cierra la app y vuelve a abrirla. Si el problema sigue, '
                'reinicia el celular.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
}
