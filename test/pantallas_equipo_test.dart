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
import 'package:vertex_ai_pyme/ui/perfil_gate.dart';
import 'package:vertex_ai_pyme/ui/tema.dart';
import 'package:vertex_ai_pyme/ui/ventas_page.dart';
import 'soporte.dart';

/// Pantallas del equipo: «¿Quién atiende?» con PIN, la de Equipo según el
/// rol y el nombre de quien vendió en la caja.
void main() {
  late LocalDb db;
  late ServidorFalso srv;
  const it = 50; // pocas iteraciones en pruebas; se guardan con el hash

  setUpAll(() async {
    await initializeDateFormatting('es_CO');
    Intl.defaultLocale = 'es_CO';
  });

  setUp(() async {
    db = await baseDePrueba();
    await db.setAjuste('negocio_nombre', 'Tienda de prueba');
    srv = ServidorFalso()
      ..miembro('u-duena', 'e-tienda', Rol.dueno, 'duena@correo.co')
      ..miembro('u-pedro', 'e-tienda', Rol.despachador, 'pedro@correo.co');
    SyncService.instance
      ..remoto = srv
      ..estado.value = EstadoSync.sincronizado;
  });

  Widget app(Widget home) => MaterialApp(
        scaffoldMessengerKey: mensajero,
        locale: const Locale('es', 'CO'),
        supportedLocales: const [Locale('es', 'CO'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: temaVertex(Brightness.light),
        home: home,
      );

  /// La base hace E/S real: se le da tiempo con runAsync y se avanzan cuadros.
  Future<void> esperar(WidgetTester tester, [int veces = 3]) async {
    for (var i = 0; i < veces; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> abrir(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(home));
    await esperar(tester);
  }

  Future<void> teclear(WidgetTester tester, String pin) async {
    for (final d in pin.split('')) {
      await tester.tap(find.byKey(ValueKey('tecla_$d')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('tecla_entrar')));
    await esperar(tester);
  }

  testWidgets('sin perfiles la app abre directo', (tester) async {
    await abrir(tester, const PerfilGate(child: Text('la caja')));
    expect(find.text('la caja'), findsOneWidget);
    expect(find.text('¿Quién atiende?'), findsNothing);
  });

  testWidgets('con perfiles hay que decir quién atiende; el PIN equivocado no entra', (tester) async {
    await tester.runAsync(() async {
      await db.crearPerfil('Marta', Rol.dueno, '9051', iteraciones: it);
      await db.crearPerfil('Luis', Rol.despachador, '2580', iteraciones: it);
    });
    await abrir(tester, const PerfilGate(child: Text('la caja')));
    expect(find.text('¿Quién atiende?'), findsOneWidget);
    expect(find.text('la caja'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('perfil_Luis')));
    await esperar(tester);
    await teclear(tester, '1111');
    expect(find.text('PIN equivocado'), findsOneWidget);
    expect(db.perfilActivo.value, isNull);

    await teclear(tester, '2580');
    await esperar(tester);
    expect(db.perfilActivo.value?.nombre, 'Luis');
    expect(find.text('la caja'), findsOneWidget);
    expect(db.puede(Permiso.verCostos), isFalse, reason: 'atiende el despachador');

    // «Cambiar de persona» vuelve a preguntar.
    db.salirPerfil();
    await esperar(tester);
    expect(find.text('¿Quién atiende?'), findsOneWidget);
  });

  testWidgets('en la caja se ve quién hizo cada venta', (tester) async {
    await tester.runAsync(() async {
      final luis = await db.crearPerfil('Luis', Rol.despachador, '2580', iteraciones: it);
      await db.entrarComo(luis, '2580');
      await db.saveMovimiento('Venta de mostrador', 4000);
    });
    await abrir(tester, const VentasPage());
    expect(find.textContaining('por Luis'), findsOneWidget);
  });

  testWidgets('la dueña ve el equipo, invita con código y cambia roles', (tester) async {
    await abrir(tester, EquipoPage(servicio: EquipoService(db, srv)));
    expect(find.byKey(const ValueKey('miembro_duena@correo.co')), findsOneWidget);
    expect(find.byKey(const ValueKey('miembro_pedro@correo.co')), findsOneWidget);
    expect(find.byKey(const ValueKey('switch_fia')), findsOneWidget);
    expect(find.byKey(const ValueKey('agregar_perfil')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('invitar')));
    await esperar(tester, 2);
    await tester.tap(find.byKey(const ValueKey('rol_bodeguero')));
    await esperar(tester);
    expect(find.text('ABCD-EFAA'), findsOneWidget);
    expect(srv.invitaciones['ABCDEFAA']!.rol, 'bodeguero');
    await tester.tapAt(const Offset(5, 5)); // cierra el diálogo
    await esperar(tester, 2);

    await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('miembro_pedro@correo.co')), matching: find.byType(PopupMenuButton<String>)));
    await esperar(tester, 2);
    await tester.tap(find.text('Cambiar rol'));
    await esperar(tester, 2);
    await tester.tap(find.byKey(const ValueKey('rol_contador')));
    await esperar(tester);
    expect(srv.miembros['u-pedro']!.rol, 'contador');
  });

  testWidgets('el despachador no ve el equipo ni puede invitar ni manejar perfiles', (tester) async {
    srv.yo = 'u-pedro';
    db.equipo.value = const ContextoEquipo(rol: Rol.despachador, empresaId: 'e-tienda');
    await abrir(tester, EquipoPage(servicio: EquipoService(db, srv)));
    expect(find.text('Tu cuenta: Despachador'), findsOneWidget);
    expect(find.byKey(const ValueKey('invitar')), findsNothing);
    expect(find.byKey(const ValueKey('miembro_pedro@correo.co')), findsNothing);
    expect(find.byKey(const ValueKey('switch_fia')), findsNothing);
    expect(find.byKey(const ValueKey('agregar_perfil')), findsNothing);
    expect(find.byKey(const ValueKey('tengo_codigo')), findsNothing);
  });

  testWidgets('el primer perfil es el de la dueña y queda atendiendo', (tester) async {
    await abrir(tester, EquipoPage(servicio: EquipoService(db, srv)));
    await tester.tap(find.byKey(const ValueKey('agregar_perfil')));
    await esperar(tester, 2);
    expect(find.text('Tu perfil primero'), findsOneWidget);
    expect(find.byKey(const ValueKey('perfil_rol')), findsNothing, reason: 'el primero lleva el rol de la cuenta');
    await tester.enterText(find.byKey(const ValueKey('perfil_nombre')), 'Marta');
    await tester.enterText(find.byKey(const ValueKey('perfil_pin')), '9051');
    await tester.enterText(find.byKey(const ValueKey('perfil_pin2')), '9015');
    await tester.tap(find.byKey(const ValueKey('guardar_perfil')));
    await tester.pump();
    expect(find.text('Los dos PIN no coinciden'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('perfil_pin2')), '9051');
    await tester.tap(find.byKey(const ValueKey('guardar_perfil')));
    await esperar(tester, 6);
    final perfiles = await tester.runAsync(db.perfiles);
    expect(perfiles!.single.rol, Rol.dueno);
    expect(db.perfilActivo.value?.nombre, 'Marta');
  });
}
