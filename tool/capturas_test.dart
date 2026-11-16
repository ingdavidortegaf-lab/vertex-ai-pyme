// Capturas de pantalla para revisar el diseño sin celular.
// No corre con `flutter test` normal (vive fuera de test/). Uso:
//   flutter test tool/capturas_test.dart --update-goldens
// Las imágenes quedan en .impeccable/review/ (ignorada por git).
// Los datos son de ejemplo (sintéticos), solo para ver el diseño.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:vertex_ai_pyme/data/local_db.dart';
import 'package:vertex_ai_pyme/data/sync_service.dart';
import 'package:vertex_ai_pyme/ui/cliente_detalle_page.dart';
import 'package:vertex_ai_pyme/ui/comun.dart';
import 'package:vertex_ai_pyme/ui/consent_gate.dart';
import 'package:vertex_ai_pyme/ui/home_page.dart';
import 'package:vertex_ai_pyme/ui/tema.dart';
import '../test/soporte.dart';

const _dpr = 2.75;
const _ancho = 400.0; // dp, como el Xiaomi 14T

Future<void> _fuentes() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final dir = '$flutterRoot/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final f in ['regular', 'medium', 'bold', 'black', 'light']) {
    roboto.addFont(Future.value(
        ByteData.sublistView(File('$dir/roboto-$f.ttf').readAsBytesSync())));
  }
  await roboto.load();
  final iconos = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(
        File('$dir/materialicons-regular.otf').readAsBytesSync())));
  await iconos.load();
}

Future<String> _sembrar(LocalDb db) async {
  final ahora = DateTime.now();
  final hoy = DateTime(ahora.year, ahora.month, ahora.day, 7);
  DateTime t(int dias, int minutos) =>
      hoy.subtract(Duration(days: dias)).add(Duration(minutes: minutos));
  db.reloj = () => t(3, 0);
  final ana = await db.saveCliente('Ana Pérez', '573101234567');
  final carlos = await db.saveCliente('Carlos Rojas', '573209876543');
  await db.saveCliente('Marta Gómez', '573004561234');
  final luis = await db.saveCliente('Luis Fernando Silva', '');
  await db.saveCliente('Yuli Barrera', '573158887766');

  Future<void> mov(int dias, int min, String c, double m,
      {String tipo = 'ingreso', bool fiado = false, String? cliente}) async {
    db.reloj = () => t(dias, min);
    await db.saveMovimiento(c, m, tipo: tipo, credito: fiado, clienteId: cliente);
  }

  await mov(2, 60, 'Arriendo del local', 450000, tipo: 'egreso');
  await mov(2, 90, '3 bultos de concentrado', 186000, cliente: luis);
  await mov(2, 200, 'Herramienta y alambre', 95000, cliente: carlos);
  await mov(1, 30, 'Mercancía para surtir', 320000, tipo: 'egreso');
  await mov(1, 120, 'Venta mostrador', 54000);
  await mov(1, 180, 'Insumos veterinarios', 128000, fiado: true, cliente: ana);
  await mov(1, 300, 'Venta mostrador', 38500);
  final hoyVentas = [
    ('Gaseosas y pan', 12500.0),
    ('Arroz y aceite', 31000.0),
    ('Venta mostrador', 18000.0),
    ('2 bultos de sal mineralizada', 96000.0),
    ('Venta mostrador', 9500.0),
    ('Huevos y leche', 22000.0),
    ('Purina 40 kg', 118000.0),
    ('Venta mostrador', 15000.0),
    ('Cuaderno y lapiceros', 8500.0),
    ('Venta mostrador', 27000.0),
    ('Jabón y detergente', 19800.0),
  ];
  for (final (i, (c, m)) in hoyVentas.indexed) {
    await mov(0, 20 + i * 25, c, m);
  }
  await mov(0, 140, 'Insumos de ordeño', 40000, fiado: true, cliente: carlos);
  await mov(0, 200, 'Fletes', 32000, tipo: 'egreso');
  await mov(0, 260, 'Abono', 20000, tipo: 'abono', cliente: ana);
  db.reloj = DateTime.now;
  return ana;
}

Widget _app(Widget home, {Brightness brillo = Brightness.light}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: mensajero,
      locale: const Locale('es', 'CO'),
      supportedLocales: const [Locale('es', 'CO'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: temaVertex(brillo),
      home: home,
    );

Future<void> _esperar(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump(const Duration(milliseconds: 600));
  }
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  late LocalDb db;
  late String anaId;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('es_CO');
    Intl.defaultLocale = 'es_CO';
    await _fuentes();
  });

  setUp(() async {
    db = await baseDePrueba();
    anaId = await _sembrar(db);
    final s = SyncService.instance;
    s.remoto = ServidorFalso();
    s.estado.value = EstadoSync.sincronizado;
    s.subidos.value = 0;
    await db.setAjuste(ConsentGate.claveConsentimiento, '2026-11-16');
  });

  Future<void> tam(WidgetTester tester, double alto) async {
    tester.view.devicePixelRatio = _dpr;
    tester.view.physicalSize = Size(_ancho * _dpr, alto * _dpr);
    addTearDown(tester.view.reset);
  }

  Future<void> captura(WidgetTester tester, String nombre) async {
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('../.impeccable/review/$nombre.png'));
  }

  testWidgets('inicio', (tester) async {
    await tam(tester, 890);
    SyncService.instance.subidos.value = 11;
    await tester.runAsync(() async {
      await tester.pumpWidget(_app(const HomePage()));
    });
    await _esperar(tester);
    await captura(tester, 'phone-inicio');
  });

  testWidgets('inicio completo', (tester) async {
    await tam(tester, 1900);
    await tester.runAsync(() async {
      await tester.pumpWidget(_app(const HomePage()));
    });
    await _esperar(tester);
    await captura(tester, 'phone-inicio-completo');
  });

  testWidgets('inicio oscuro', (tester) async {
    await tam(tester, 890);
    await tester.runAsync(() async {
      await tester.pumpWidget(_app(const HomePage(), brillo: Brightness.dark));
    });
    await _esperar(tester);
    await captura(tester, 'phone-inicio-oscuro');
  });

  testWidgets('movimientos', (tester) async {
    await tam(tester, 890);
    await tester.runAsync(() async {
      await tester.pumpWidget(_app(const HomePage()));
    });
    await _esperar(tester);
    await tester.tap(find.text('Movimientos'));
    await _esperar(tester);
    await captura(tester, 'phone-movimientos');
  });

  testWidgets('clientes', (tester) async {
    await tam(tester, 890);
    await tester.runAsync(() async {
      await tester.pumpWidget(_app(const HomePage()));
    });
    await _esperar(tester);
    await tester.tap(find.text('Clientes'));
    await _esperar(tester);
    await captura(tester, 'phone-clientes');
  });

  testWidgets('asistente', (tester) async {
    await tam(tester, 890);
    await tester.runAsync(() async {
      await tester.pumpWidget(_app(const HomePage()));
    });
    await _esperar(tester);
    await tester.tap(find.text('Asistente'));
    await _esperar(tester);
    await tester.tap(find.text('¿Quién me debe?'));
    await _esperar(tester);
    await captura(tester, 'phone-asistente');
  });

  testWidgets('registrar', (tester) async {
    await tam(tester, 890);
    await tester.runAsync(() async {
      await tester.pumpWidget(_app(const HomePage()));
    });
    await _esperar(tester);
    await tester.tap(find.text('Venta').first);
    await _esperar(tester);
    await captura(tester, 'phone-registrar');
  });

  testWidgets('cliente', (tester) async {
    await tam(tester, 890);
    await tester.runAsync(() async {
      await tester.pumpWidget(_app(ClienteDetallePage(clienteId: anaId)));
    });
    await _esperar(tester);
    await captura(tester, 'phone-cliente');
  });

  testWidgets('bienvenida', (tester) async {
    await tam(tester, 890);
    await tester.runAsync(() => db.borrarAjuste(ConsentGate.claveConsentimiento));
    await tester.runAsync(() async {
      await tester.pumpWidget(_app(const ConsentGate(child: HomePage())));
    });
    await _esperar(tester);
    await captura(tester, 'phone-bienvenida');
  });
}
