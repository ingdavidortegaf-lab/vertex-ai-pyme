import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:vertex_ai_pyme/data/sync_service.dart';
import 'package:vertex_ai_pyme/ui/comun.dart';
import 'package:vertex_ai_pyme/domain/resumen.dart';
import 'package:vertex_ai_pyme/ui/home_page.dart';
import 'package:vertex_ai_pyme/ui/oficina_page.dart';
import 'package:vertex_ai_pyme/ui/punto_venta_page.dart';
import 'package:vertex_ai_pyme/ui/tema.dart';
import 'soporte.dart';

/// Diseño de computador (menú lateral, atajos), caja rápida con lector de
/// código de barras e importar desde Excel.
void main() {
  late LocalDb db;

  setUpAll(() async {
    await initializeDateFormatting('es_CO');
    Intl.defaultLocale = 'es_CO';
  });

  setUp(() async {
    db = await baseDePrueba();
    SyncService.instance
      ..remoto = null
      ..estado.value = EstadoSync.soloLocal;
  });

  Widget app(Widget home) => MaterialApp(
        scaffoldMessengerKey: mensajero,
        locale: const Locale('es', 'CO'),
        supportedLocales: const [Locale('es', 'CO'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: temaVertex(Brightness.light),
        home: home,
      );

  Future<void> esperar(WidgetTester tester, [int veces = 3]) async {
    for (var i = 0; i < veces; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> abrir(WidgetTester tester, Widget home, {Size tam = const Size(1440, 900)}) async {
    tester.view.physicalSize = tam;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(home));
    await esperar(tester);
  }

  /// Deja pasar los avisos (SnackBar) para que no quede un temporizador vivo.
  Future<void> cerrar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> escribirYEnter(WidgetTester tester, String texto) async {
    await tester.enterText(find.byKey(const ValueKey('pv_buscar')), texto);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await esperar(tester);
  }

  Future<void> productos(WidgetTester tester) => tester.runAsync(() async {
        await db.saveProducto('Cemento gris 50 kg',
            precio: 34000, costo: 29500, stockInicial: 40, codigo: '7704567800013',
            precioMayor: 32500, cantidadMayor: 10);
        await db.saveProducto('Arroz 500 g', precio: 2500, costo: 1800, stockInicial: 60, codigo: '7705678900010');
        await db.saveProducto('Cable 12', precio: 4200, stockInicial: 300, codigo: '7701', unidad: 'm');
      });

  testWidgets('en el computador hay menú lateral y F2 abre la caja rápida', (tester) async {
    await abrir(tester, const HomePage());
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Caja rápida'), findsOneWidget);
    expect(find.text('Herramientas'), findsWidgets);
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await esperar(tester);
    expect(find.byKey(const ValueKey('pv_buscar')), findsOneWidget);
    // Ctrl+1 vuelve al inicio.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await esperar(tester);
    expect(find.byKey(const ValueKey('pv_buscar')), findsNothing);
  });

  testWidgets('en el celular sigue la barra de abajo y la caja rápida está en Movimientos', (tester) async {
    await abrir(tester, const HomePage(), tam: const Size(400, 860));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    await tester.tap(find.text('Caja'));
    await esperar(tester);
    await tester.tap(find.byKey(const ValueKey('abrir_caja_rapida')));
    await esperar(tester);
    expect(find.byKey(const ValueKey('pv_buscar')), findsOneWidget);
  });

  testWidgets('lector de código, «12*», precio por mayor, cambio y F4 cobra', (tester) async {
    await productos(tester);
    await abrir(tester, const PuntoVentaPage());
    await escribirYEnter(tester, '7705678900010');
    await escribirYEnter(tester, '12*7704567800013');
    expect(find.byKey(const ValueKey('pv_linea_Arroz 500 g')), findsOneWidget);
    expect(find.textContaining('por mayor'), findsOneWidget);
    // 2.500 + 12 × 32.500 = 392.500
    expect(tester.widget<Text>(find.byKey(const ValueKey('pv_total'))).data, r'$392.500');
    await tester.enterText(find.byKey(const ValueKey('pv_recibido')), '400000');
    await esperar(tester, 1);
    expect(tester.widget<Text>(find.byKey(const ValueKey('pv_cambio'))).data, r'$7.500');
    await tester.sendKeyEvent(LogicalKeyboardKey.f4);
    await esperar(tester, 5);
    expect(find.byKey(const ValueKey('pv_venta_lista')), findsOneWidget);
    expect(find.textContaining(r'Cambio: $7.500'), findsOneWidget);
    final v = (await tester.runAsync(() => db.db.query('ventas')))!.single;
    expect(v['monto'], 392500);
    expect(v['credito'], 0);
    expect(v['pagos'], contains('efectivo'));
    final stock = {for (final p in (await tester.runAsync(db.productos))!) p.nombre: p.stock};
    expect(stock['Cemento gris 50 kg'], 28);
    expect(stock['Arroz 500 g'], 59);

    await cerrar(tester);
  });

  testWidgets('no deja cobrar si el efectivo no alcanza; código desconocido avisa', (tester) async {
    await productos(tester);
    await abrir(tester, const PuntoVentaPage());
    await escribirYEnter(tester, '9999999999');
    expect(find.textContaining('No hay un producto con el código 9999999999'), findsOneWidget);
    await escribirYEnter(tester, 'arroz');
    await tester.enterText(find.byKey(const ValueKey('pv_recibido')), '1000');
    await esperar(tester, 1);
    await tester.tap(find.byKey(const ValueKey('pv_cobrar')));
    await esperar(tester);
    expect(find.byKey(const ValueKey('pv_error')), findsOneWidget);
    expect(await tester.runAsync(() => db.db.query('ventas')), isEmpty);

    await cerrar(tester);
  });

  testWidgets('por metro pregunta la cantidad; F6 fía a un cliente', (tester) async {
    await productos(tester);
    await tester.runAsync(() => db.saveCliente('Carlos Rojas', '3001234567'));
    await abrir(tester, const PuntoVentaPage());
    await escribirYEnter(tester, '7701');
    await tester.enterText(find.byKey(const ValueKey('pv_cantidad')), '12,5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await esperar(tester);
    expect(find.text('12,5 m'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.f6);
    await esperar(tester);
    await tester.tap(find.byKey(const ValueKey('pv_cliente_Carlos Rojas')));
    await esperar(tester, 5);
    final v = (await tester.runAsync(() => db.db.query('ventas')))!.single;
    expect(v['monto'], 52500);
    expect(v['credito'], 1);

    await cerrar(tester);
  });

  testWidgets('inventario en tabla e importar desde Excel', (tester) async {
    await productos(tester);
    await abrir(tester, const HomePage());
    await tester.tap(find.byKey(const ValueKey('menu_catalogo')));
    await esperar(tester);
    expect(find.text('Vence'), findsOneWidget);
    expect(find.byKey(const ValueKey('tabla_Cable 12')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('importar_excel')));
    await esperar(tester);
    await tester.enterText(find.byKey(const ValueKey('importar_texto')),
        'Nombre\tPrecio\tStock\tUnidad\nPintura blanca\t98000\t12\tgalón\nMala\t\t1\tund');
    await tester.tap(find.byKey(const ValueKey('importar_revisar')));
    await esperar(tester, 1);
    expect(find.textContaining('Listos para importar: 1 producto'), findsOneWidget);
    expect(find.textContaining('Fila 3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('importar_guardar')));
    await esperar(tester, 5);
    expect(find.byKey(const ValueKey('tabla_Pintura blanca')), findsOneWidget);
    final p = (await tester.runAsync(db.productos))!.firstWhere((x) => x.nombre == 'Pintura blanca');
    expect(p.unidad, 'gal');
    expect(p.stock, 12);

    await cerrar(tester);
  });

  testWidgets('Ctrl+K busca un cliente y lo abre', (tester) async {
    await productos(tester);
    await tester.runAsync(() => db.saveCliente('Carlos Rojas', '3001234567'));
    await abrir(tester, const HomePage());
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await esperar(tester);
    await tester.enterText(find.byKey(const ValueKey('buscador_global')), 'cem');
    await esperar(tester, 1);
    expect(find.byKey(const ValueKey('resultado_Cemento gris 50 kg')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('buscador_global')), 'carl');
    await esperar(tester, 1);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await esperar(tester, 4);
    expect(find.text('Carlos Rojas'), findsWidgets);
    expect(find.byKey(const ValueKey('buscador_global')), findsNothing);
    await cerrar(tester);
  });

  testWidgets('devolver un producto desde Movimientos', (tester) async {
    await productos(tester);
    await tester.runAsync(() async {
      final p = await db.productos();
      final c = p.firstWhere((x) => x.nombre.startsWith('Cemento'));
      final a = p.firstWhere((x) => x.nombre.startsWith('Arroz'));
      await db.saveVentaProductos([
        ItemVenta(productoId: c.id, nombre: c.nombre, cantidad: 2, precio: c.precio, costo: c.costo),
        ItemVenta(productoId: a.id, nombre: a.nombre, cantidad: 1, precio: a.precio, costo: a.costo),
      ]);
    });
    await abrir(tester, const HomePage());
    await tester.tap(find.byKey(const ValueKey('menu_caja')));
    await esperar(tester);
    await tester.longPress(find.textContaining('2 × Cemento'));
    await esperar(tester);
    await tester.tap(find.byKey(const ValueKey('opcion_devolver')));
    await esperar(tester);
    await tester.tap(find.byKey(const ValueKey('devolver_mas_Cemento gris 50 kg')));
    await esperar(tester, 1);
    await tester.tap(find.byKey(const ValueKey('confirmar_devolucion')));
    await esperar(tester, 5);
    expect(find.textContaining('devuelve \$34.000'), findsOneWidget);
    final stock = {for (final p in (await tester.runAsync(db.productos))!) p.nombre: p.stock};
    expect(stock['Cemento gris 50 kg'], 39);
    expect(stock['Arroz 500 g'], 59);
    await cerrar(tester);
  });

  testWidgets('informes: ventas por vendedor y ganancia por producto', (tester) async {
    await productos(tester);
    await tester.runAsync(() async {
      final c = (await db.productos()).firstWhere((x) => x.nombre.startsWith('Cemento'));
      await db.saveVentaProductos([
        ItemVenta(productoId: c.id, nombre: c.nombre, cantidad: 2, precio: c.precio, costo: c.costo),
      ]);
    });
    await abrir(tester, const InformesPage(), tam: const Size(1200, 3200));
    await esperar(tester, 4);
    expect(find.byKey(const ValueKey('utilidad_Cemento gris 50 kg')), findsOneWidget);
    expect(find.byKey(const ValueKey('vendedor_Cuenta principal')), findsOneWidget);
    expect(find.byKey(const ValueKey('exportar_movimientos')), findsOneWidget);
    await cerrar(tester);
  });
}

