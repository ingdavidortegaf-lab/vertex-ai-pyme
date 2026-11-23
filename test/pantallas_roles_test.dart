import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:vertex_ai_pyme/data/sync_service.dart';
import 'package:vertex_ai_pyme/domain/roles.dart';
import 'package:vertex_ai_pyme/ui/comun.dart';
import 'package:vertex_ai_pyme/ui/home_page.dart';
import 'package:vertex_ai_pyme/ui/tema.dart';
import 'soporte.dart';

/// Lo que ve cada rol en la app: la barra de abajo, los botones rápidos, las
/// herramientas y el formulario de registrar. (La app oculta; el servidor
/// impide: eso lo prueban supabase/tests/roles_y_permisos.sql.)
void main() {
  late LocalDb db;

  setUpAll(() async {
    await initializeDateFormatting('es_CO');
    Intl.defaultLocale = 'es_CO';
  });

  setUp(() async {
    db = await baseDePrueba();
    await db.setAjuste('negocio_nombre', 'Tienda de prueba');
    await db.saveProducto('Arroz', precio: 2500, costo: 2000, stockInicial: 20);
    await db.saveMovimiento('Venta', 5000);
    SyncService.instance
      ..remoto = ServidorFalso()
      ..estado.value = EstadoSync.sincronizado;
  });

  Widget app() => MaterialApp(
        scaffoldMessengerKey: mensajero,
        locale: const Locale('es', 'CO'),
        supportedLocales: const [Locale('es', 'CO'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: temaVertex(Brightness.light),
        home: const HomePage(),
      );

  Future<void> abrir(WidgetTester tester, ContextoEquipo c) async {
    tester.view.physicalSize = const Size(1800, 5200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    db.equipo.value = c;
    await tester.runAsync(() async {
      await tester.pumpWidget(app());
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump(const Duration(seconds: 2));
  }

  List<String> barra(WidgetTester tester) => tester
      .widgetList<NavigationDestination>(find.byType(NavigationDestination))
      .map((d) => d.label)
      .toList();

  Finder boton(String etiqueta) => find.bySemanticsLabel('Registrar $etiqueta');

  /// El formulario consulta la base antes de abrirse (E/S real: runAsync) y
  /// la app tiene animaciones que no terminan (logo), así que se avanzan
  /// cuadros fijos en vez de pumpAndSettle.
  Future<void> abrirFormulario(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  testWidgets('dueño: todas las secciones, todos los botones y todas las herramientas', (tester) async {
    await abrir(tester, const ContextoEquipo(rol: Rol.dueno));
    expect(barra(tester), ['Inicio', 'Caja', 'Inventario', 'Clientes', 'Asistente']);
    expect(boton('Venta'), findsOneWidget);
    expect(boton('Gasto'), findsOneWidget);
    expect(boton('Abono'), findsOneWidget);
    expect(find.text('Hoy vendiste'), findsOneWidget);
    for (final h in ['Pagos fijos', 'Cierre de caja', 'Informes', 'Proveedores y terceros']) {
      expect(find.text(h), findsOneWidget, reason: h);
    }
  });

  testWidgets('despachador: vende y ve la caja; sin gastos, abonos, clientes, informes ni cierre', (tester) async {
    await abrir(tester, const ContextoEquipo(rol: Rol.despachador));
    expect(barra(tester), ['Inicio', 'Caja', 'Inventario']);
    expect(boton('Venta'), findsOneWidget);
    expect(boton('Gasto'), findsNothing);
    expect(boton('Abono'), findsNothing);
    expect(find.text('Comprobantes'), findsOneWidget);
    for (final h in ['Pagos fijos', 'Cierre de caja', 'Informes', 'Proveedores y terceros', 'Lo que debo']) {
      expect(find.text(h), findsNothing, reason: h);
    }
    expect(find.text('Reportes'), findsNothing, reason: 'los reportes muestran utilidad');
  });

  testWidgets('despachador: el formulario solo registra ventas de contado, sin cliente ni fiado', (tester) async {
    await abrir(tester, const ContextoEquipo(rol: Rol.despachador));
    await tester.tap(boton('Venta'));
    await abrirFormulario(tester);
    expect(find.text('Guardar venta'), findsOneWidget);
    expect(find.text('Gasto'), findsNothing, reason: 'sin selector de gasto');
    expect(find.text('Venta fiada'), findsNothing);
    expect(find.text('Cliente (opcional)'), findsNothing);
  });

  testWidgets('despachador con fiado activado por el dueño: ve clientes y puede fiar', (tester) async {
    await abrir(tester, const ContextoEquipo(rol: Rol.despachador, despachadorFia: true));
    expect(barra(tester), ['Inicio', 'Caja', 'Inventario', 'Clientes']);
    expect(boton('Abono'), findsOneWidget);
    await tester.tap(boton('Venta'));
    await abrirFormulario(tester);
    expect(find.text('Venta fiada'), findsOneWidget);
    expect(find.text('Gasto'), findsNothing);
  });

  testWidgets('contador: consulta todo y no registra nada', (tester) async {
    await abrir(tester, const ContextoEquipo(rol: Rol.contador));
    expect(barra(tester), ['Inicio', 'Caja', 'Inventario', 'Clientes']);
    expect(boton('Venta'), findsNothing);
    expect(boton('Gasto'), findsNothing);
    expect(find.text('Informes'), findsOneWidget);
    expect(find.text('Registrar'), findsNothing);
  });

  testWidgets('bodeguero: solo inventario, sin ventas', (tester) async {
    await abrir(tester, const ContextoEquipo(rol: Rol.bodeguero));
    expect(barra(tester), ['Inicio', 'Inventario']);
    expect(boton('Venta'), findsNothing);
    expect(boton('Inventario'), findsOneWidget);
    expect(find.text('Hoy vendiste'), findsNothing);
    expect(find.text('Comprobantes'), findsNothing);
  });
}
