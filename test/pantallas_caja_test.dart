import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:vertex_ai_pyme/data/equipo_service.dart';
import 'package:vertex_ai_pyme/data/sync_service.dart';
import 'package:vertex_ai_pyme/domain/roles.dart';
import 'package:vertex_ai_pyme/ui/comun.dart';
import 'package:vertex_ai_pyme/ui/equipo_page.dart';
import 'package:vertex_ai_pyme/ui/tema.dart';
import 'package:vertex_ai_pyme/ui/turnos_page.dart';
import 'package:vertex_ai_pyme/ui/ventas_page.dart';
import 'soporte.dart';

/// Pantallas de caja: turno, anular (con autorización) y descuento.
void main() {
  late LocalDb db;
  const it = 50;

  setUpAll(() async {
    await initializeDateFormatting('es_CO');
    Intl.defaultLocale = 'es_CO';
  });

  setUp(() async {
    db = await baseDePrueba();
    await db.setAjuste('negocio_nombre', 'Tienda de prueba');
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

  Future<void> abrir(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(home));
    await esperar(tester);
  }

  Future<void> teclear(WidgetTester tester, String pin, String boton) async {
    for (final d in pin.split('')) {
      await tester.tap(find.byKey(ValueKey('tecla_$d')));
      await tester.pump();
    }
    await tester.tap(find.byKey(ValueKey(boton)));
    await esperar(tester);
  }

  testWidgets('abrir el turno con base, ver el esperado y cerrarlo con la diferencia', (tester) async {
    await abrir(tester, const VentasPage());
    await tester.tap(find.byKey(const ValueKey('abrir_turno')));
    await esperar(tester, 2);
    await tester.enterText(find.byKey(const ValueKey('campo_valor')), '50000');
    await tester.tap(find.byKey(const ValueKey('confirmar_valor')));
    await esperar(tester);
    expect(db.turnoAbierto.value?.base, 50000);
    expect(find.textContaining('50.000'), findsWidgets);

    await tester.runAsync(() => db.saveMovimiento('Venta', 10000));
    await esperar(tester);
    expect(
        tester.widget<Text>(find.byKey(const ValueKey('efectivo_esperado'))).data, contains('60.000'));

    await tester.tap(find.byKey(const ValueKey('cerrar_turno')));
    await esperar(tester, 2);
    await tester.enterText(find.byKey(const ValueKey('campo_contado')), '59000');
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const ValueKey('diferencia_turno'))).data, contains('Faltan'));
    await tester.tap(find.byKey(const ValueKey('confirmar_cierre')));
    await esperar(tester, 4);
    expect(db.turnoAbierto.value, isNull);
    final t = await tester.runAsync(db.turnos);
    expect(t!.single.diferencia, -1000);
  });

  testWidgets('la dueña anula manteniendo presionado: el original queda tachado', (tester) async {
    await tester.runAsync(() => db.saveMovimiento('Venta de mostrador', 8000));
    await abrir(tester, const VentasPage());
    await tester.longPress(find.text('Venta de mostrador'));
    await esperar(tester, 2);
    await tester.enterText(find.byKey(const ValueKey('motivo_anulacion')), 'Se cobró dos veces');
    await tester.tap(find.byKey(const ValueKey('confirmar_anulacion')));
    await esperar(tester, 4);
    expect(find.textContaining('Anulación: Venta de mostrador'), findsOneWidget);
    final original = tester.widget<Text>(find.text('Venta de mostrador'));
    expect(original.style?.decoration, TextDecoration.lineThrough);
    expect(find.textContaining('Anulada'), findsOneWidget);
  });

  testWidgets('si atiende el despachador, anular pide el PIN de un supervisor', (tester) async {
    await tester.runAsync(() async {
      await db.crearPerfil('Marta', Rol.dueno, '9051', iteraciones: it);
      final luis = await db.crearPerfil('Luis', Rol.despachador, '2580', iteraciones: it);
      await db.saveMovimiento('Venta', 5000);
      await db.entrarComo(luis, '2580');
    });
    await abrir(tester, const VentasPage());
    await tester.longPress(find.text('Venta'));
    await esperar(tester, 2);
    await tester.tap(find.byKey(const ValueKey('confirmar_anulacion')));
    await esperar(tester, 3);
    expect(find.textContaining('para autorizar la anulación'), findsOneWidget);
    await teclear(tester, '1111', 'tecla_entrar');
    expect(find.text('PIN equivocado'), findsOneWidget);
    await teclear(tester, '9051', 'tecla_entrar');
    await esperar(tester, 3);
    final movs = await tester.runAsync(db.movimientos);
    final a = movs!.singleWhere((m) => m['tipo'] == 'anulacion');
    expect(a['autoriza'], 'Marta');
    expect(a['perfil'], 'Luis');
    expect(db.perfilActivo.value?.nombre, 'Luis', reason: 'autorizar no cambia quién atiende');
  });

  testWidgets('la cuenta de despachador no puede anular (no se ofrece)', (tester) async {
    await tester.runAsync(() => db.saveMovimiento('Venta', 5000));
    db.equipo.value = const ContextoEquipo(rol: Rol.despachador);
    await abrir(tester, const VentasPage());
    await tester.longPress(find.text('Venta'));
    await esperar(tester, 2);
    expect(find.byKey(const ValueKey('confirmar_anulacion')), findsNothing);
  });

  Future<void> abrirRegistrar(WidgetTester tester) async {
    await tester.tap(find.text('Registrar'));
    await esperar(tester, 4);
  }

  testWidgets('descuento: la dueña sin tope; el despachador solo si hay tope', (tester) async {
    await abrir(tester, const VentasPage());
    await abrirRegistrar(tester);
    expect(find.byKey(const ValueKey('campo_descuento')), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '20000');
    await tester.enterText(find.byKey(const ValueKey('campo_descuento')), '5000');
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const ValueKey('total_con_descuento'))).data, contains('15.000'));
    Navigator.of(tester.element(find.byKey(const ValueKey('campo_descuento')))).pop();
    await esperar(tester, 2);

    db.equipo.value = const ContextoEquipo(rol: Rol.despachador);
    await abrir(tester, const VentasPage());
    await abrirRegistrar(tester);
    expect(find.byKey(const ValueKey('campo_descuento')), findsNothing, reason: 'sin tope no hay descuentos');
    Navigator.of(tester.element(find.text('Registrar').last)).pop();
    await esperar(tester, 2);

    db.equipo.value = const ContextoEquipo(rol: Rol.despachador, descuentoMaxPct: 10);
    await abrir(tester, const VentasPage());
    await abrirRegistrar(tester);
    await tester.enterText(find.byType(TextFormField).first, '20000');
    await tester.pump();
    expect(find.textContaining('Máximo'), findsOneWidget);
    expect(find.textContaining('2.000'), findsWidgets);
  });

  testWidgets('la lista de turnos muestra la diferencia de cada uno', (tester) async {
    await tester.runAsync(() => db.aplicarTurnosRemotos([
          {'id': 't1', 'perfil': 'Pedro', 'abre': '2026-11-21T13:00:00Z', 'cierra': '2026-11-21T22:00:00Z',
            'base': 50000, 'esperado': 180000, 'contado': 179000, 'nota': 'Billete roto'},
        ]));
    await abrir(tester, const TurnosPage());
    expect(find.text('Turno de Pedro'), findsOneWidget);
    expect(find.textContaining('1.000'), findsWidgets);
    expect(find.textContaining('Billete roto'), findsOneWidget);
  });

  testWidgets('la dueña fija el tope de descuento y el servidor lo guarda', (tester) async {
    final srv = ServidorFalso()..miembro('u-duena', 'e-tienda', Rol.dueno);
    SyncService.instance.remoto = srv;
    await abrir(tester, EquipoPage(servicio: EquipoService(db, srv)));
    await tester.tap(find.byKey(const ValueKey('tope_descuento')));
    await esperar(tester, 2);
    await tester.enterText(find.byKey(const ValueKey('campo_tope')), '10');
    await tester.tap(find.byKey(const ValueKey('guardar_tope')));
    await esperar(tester, 3);
    expect(srv.descuentoMax['e-tienda'], 10);
    expect(db.equipo.value.descuentoMaxPct, 10);
    expect(find.textContaining('10 %'), findsOneWidget);
  });
}
