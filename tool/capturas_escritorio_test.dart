// Capturas del diseño de computador (1440 × 900) para revisarlo sin abrir la
// app. No corre con `flutter test` normal (vive fuera de test/). Uso:
//   flutter test tool/capturas_escritorio_test.dart --update-goldens
// Las imágenes quedan en .impeccable/review/ (ignorada por git). Los datos
// son de ejemplo (sintéticos), solo para ver el diseño.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:vertex_ai_pyme/data/sync_service.dart';
import 'package:vertex_ai_pyme/ui/comun.dart';
import 'package:vertex_ai_pyme/ui/consent_gate.dart';
import 'package:vertex_ai_pyme/ui/home_page.dart';
import 'package:vertex_ai_pyme/ui/punto_venta_page.dart';
import 'package:vertex_ai_pyme/ui/tema.dart';
import '../test/soporte.dart';

Future<void> _fuentes() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final dir = '$flutterRoot/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final f in ['regular', 'medium', 'bold', 'black', 'light']) {
    roboto.addFont(Future.value(ByteData.sublistView(File('$dir/roboto-$f.ttf').readAsBytesSync())));
  }
  await roboto.load();
  final iconos = FontLoader('MaterialIcons')
    ..addFont(Future.value(
        ByteData.sublistView(File('$dir/materialicons-regular.otf').readAsBytesSync())));
  await iconos.load();
}

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Future<void> _sembrar(LocalDb db) async {
  final ahora = DateTime.now();
  final hoy = DateTime(ahora.year, ahora.month, ahora.day, 7);
  DateTime t(int dias, int minutos) => hoy.subtract(Duration(days: dias)).add(Duration(minutes: minutos));
  db.reloj = () => t(5, 0);
  final ana = await db.saveCliente('Ana Pérez', '573101234567');
  final carlos = await db.saveCliente('Carlos Rojas · Contratista', '573209876543');
  await db.saveCliente('Marta Gómez', '573004561234');
  await db.saveProducto('Cable eléctrico 12 AWG',
      precio: 4200, costo: 3000, minimo: 50, stockInicial: 480, codigo: '7701234500012', unidad: 'm',
      precioMayor: 3800, cantidadMayor: 50, iva: 19);
  await db.saveProducto('Pintura blanca tipo 1',
      precio: 98000, costo: 72000, minimo: 4, stockInicial: 12, codigo: '7702345600019', unidad: 'gal', iva: 19);
  await db.saveProducto('Puntilla 2" (caja 500 g)',
      precio: 6500, costo: 4300, minimo: 10, stockInicial: 6, codigo: '7703456700016', unidad: 'caja', iva: 19);
  await db.saveProducto('Cemento gris 50 kg',
      precio: 34000, costo: 29500, minimo: 20, stockInicial: 64, codigo: '7704567800013',
      precioMayor: 32500, cantidadMayor: 10, iva: 19);
  await db.saveProducto('Arroz 500 g',
      precio: 2500, costo: 1800, minimo: 10, stockInicial: 60, codigo: '7705678900010', iva: 0);
  await db.saveProducto('Leche entera 1 L',
      precio: 4800, costo: 3900, minimo: 12, stockInicial: 18, codigo: '7706789000017', iva: 0,
      vence: _iso(ahora.add(const Duration(days: 6))));
  await db.saveProducto('Yogur de fresa 200 g',
      precio: 2900, costo: 2100, minimo: 6, stockInicial: 10, codigo: '7707890100014', iva: 19,
      vence: _iso(ahora.add(const Duration(days: 2))));
  await db.saveProducto('Queso campesino',
      precio: 24000, costo: 18000, minimo: 2, stockInicial: 6, codigo: '00123', unidad: 'kg');
  await db.saveProducto('Thinner corriente',
      precio: 16000, costo: 11000, minimo: 4, stockInicial: 3, codigo: '7708901200011', unidad: 'l', iva: 19);
  await db.saveProducto('Huevos AA (unidad)', precio: 600, costo: 450, minimo: 30, stockInicial: 0);
  Future<void> mov(int dias, int min, String c, double m,
      {String tipo = 'ingreso', bool fiado = false, String? cliente}) async {
    db.reloj = () => t(dias, min);
    await db.saveMovimiento(c, m, tipo: tipo, credito: fiado, clienteId: cliente);
  }

  for (var d = 1; d <= 25; d++) {
    await mov(d, 60, 'Venta mostrador', 180000.0 + (d % 6) * 45000);
    if (d % 5 == 0) await mov(d, 90, 'Servicios públicos', 85000, tipo: 'egreso');
  }
  await mov(2, 200, 'Materiales obra', 640000, fiado: true, cliente: carlos);
  await mov(1, 180, 'Mercado', 128000, fiado: true, cliente: ana);
  for (var i = 0; i < 14; i++) {
    await mov(0, 20 + i * 20, 'Venta mostrador', 12000.0 + i * 3500);
  }
  db.reloj = DateTime.now;
  await db.setAjuste('negocio_nombre', 'Ferremercado El Progreso');
  await db.setAjuste('negocio_meta', '9000000');
}

Widget _app(Widget home) => MaterialApp(
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: mensajero,
      locale: const Locale('es', 'CO'),
      supportedLocales: const [Locale('es', 'CO'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: temaVertex(Brightness.light),
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

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('es_CO');
    Intl.defaultLocale = 'es_CO';
    await _fuentes();
  });

  setUp(() async {
    db = await baseDePrueba();
    await _sembrar(db);
    final s = SyncService.instance;
    s.remoto = ServidorFalso();
    s.estado.value = EstadoSync.sincronizado;
    s.subidos.value = 0;
    await db.setAjuste(ConsentGate.claveConsentimiento, '2026-11-16');
  });

  Future<void> tam(WidgetTester tester, {double ancho = 1440, double alto = 900}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(ancho, alto);
    addTearDown(tester.view.reset);
  }

  Future<void> captura(WidgetTester tester, String nombre) async {
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../.impeccable/review/$nombre.png'));
  }

  Future<void> abrir(WidgetTester tester) async {
    await tester.runAsync(() async => tester.pumpWidget(_app(const HomePage())));
    await _esperar(tester);
  }

  testWidgets('pc inicio', (tester) async {
    await tam(tester);
    await abrir(tester);
    await captura(tester, 'pc-inicio');
  });

  testWidgets('pc caja rapida', (tester) async {
    await tam(tester);
    await abrir(tester);
    await tester.tap(find.byKey(const ValueKey('menu_vender')));
    await _esperar(tester);
    // Lector de código: escribe el código y da Enter.
    await tester.enterText(find.byKey(const ValueKey('pv_buscar')), '7704567800013');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _esperar(tester);
    await tester.enterText(find.byKey(const ValueKey('pv_buscar')), '12*7704567800013');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _esperar(tester);
    await tester.enterText(find.byKey(const ValueKey('pv_buscar')), '7705678900010');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _esperar(tester);
    await tester.enterText(find.byKey(const ValueKey('pv_buscar')), 'pint');
    await _esperar(tester);
    await tester.enterText(find.byKey(const ValueKey('pv_recibido')), '500000');
    await _esperar(tester);
    await captura(tester, 'pc-caja-rapida');
  });

  testWidgets('pc inventario', (tester) async {
    await tam(tester);
    await abrir(tester);
    await tester.tap(find.byKey(const ValueKey('menu_catalogo')));
    await _esperar(tester);
    await captura(tester, 'pc-inventario');
  });

  testWidgets('pc herramientas', (tester) async {
    await tam(tester);
    await abrir(tester);
    await tester.tap(find.byKey(const ValueKey('menu_herramientas')));
    await _esperar(tester);
    await captura(tester, 'pc-herramientas');
  });

  testWidgets('pc angosto (menu de iconos)', (tester) async {
    await tam(tester, ancho: 1024, alto: 768);
    await abrir(tester);
    await tester.tap(find.byKey(const ValueKey('menu_caja')));
    await _esperar(tester);
    await captura(tester, 'pc-1024-movimientos');
  });

  testWidgets('celular caja rapida', (tester) async {
    tester.view.devicePixelRatio = 2.75;
    tester.view.physicalSize = const Size(400 * 2.75, 860 * 2.75);
    addTearDown(tester.view.reset);
    await tester.runAsync(() async => tester.pumpWidget(_app(const PuntoVentaPage())));
    await _esperar(tester);
    await tester.enterText(find.byKey(const ValueKey('pv_buscar')), '7701234500012');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _esperar(tester);
    await tester.enterText(find.byKey(const ValueKey('pv_cantidad')), '60');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _esperar(tester);
    await captura(tester, 'phone-caja-rapida');
  });
}
