import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:vertex_ai_pyme/data/sync_service.dart';
import 'package:vertex_ai_pyme/domain/facturacion.dart';
import 'package:vertex_ai_pyme/ui/comun.dart';
import 'package:vertex_ai_pyme/ui/facturacion_page.dart';
import 'package:vertex_ai_pyme/ui/inventario_page.dart';
import 'package:vertex_ai_pyme/ui/tema.dart';
import 'soporte.dart';

/// Pantalla de factura electrónica y el IVA en el formulario del producto.
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
      ..facturador = const SinProveedor()
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
    tester.view.physicalSize = const Size(1200, 5000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(home));
    await esperar(tester);
  }

  testWidgets('sin datos del negocio no deja facturar; con ellos, factura y queda en cola', (tester) async {
    await tester.runAsync(() async {
      final ana = await db.saveCliente('Ana Pérez', '3001234567', tipoDoc: 'CC', documento: '1020304050');
      await db.saveMovimiento('Servicio de prueba', 12000, credito: true, clienteId: ana);
    });
    await abrir(tester, const FacturacionPage());
    expect(find.text('Aún no hay un proveedor de facturación conectado'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('facturar_venta'))).onPressed, isNull);

    const datos = {
      'fe_razon_social': 'Tienda de Prueba S.A.S.',
      'fe_nit': '900123456',
      'fe_dv': '1',
      'fe_direccion': 'Calle 1 # 2-3',
      'fe_municipio': 'Ciudad de prueba',
      'fe_correo': 'tienda@prueba.local',
      'fe_resolucion': '000000',
      'fe_prefijo': 'PRU',
      'fe_desde': '1',
      'fe_hasta': '100',
      'fe_vigente_hasta': '2099-12-31',
    };
    for (final e in datos.entries) {
      await tester.enterText(find.byKey(ValueKey(e.key)), e.value);
    }
    await tester.tap(find.byKey(const ValueKey('guardar_emisor')));
    await esperar(tester);
    final emisor = await tester.runAsync(db.datosEmisor);
    expect(emisor!.faltantes(), isEmpty);

    await tester.tap(find.byKey(const ValueKey('facturar_venta')));
    await esperar(tester);
    await tester.tap(find.byKey(const ValueKey('venta_Servicio de prueba')));
    await esperar(tester);
    await tester.enterText(find.byKey(const ValueKey('campo_iva_venta')), '0');
    await tester.tap(find.byKey(const ValueKey('guardar_iva_venta')));
    await esperar(tester, 5);
    expect(find.byKey(const ValueKey('factura_PRU1')), findsOneWidget);
    expect(find.textContaining('Pendiente de envío'), findsOneWidget);
    expect((await tester.runAsync(db.facturas))!.single.total, 12000);
  });

  testWidgets('el formulario del producto guarda el IVA', (tester) async {
    await tester.runAsync(() => db.saveProducto('Gaseosa', precio: 3300));
    final p = (await tester.runAsync(db.productos))!.single;
    expect(p.iva, -1);
    await abrir(
        tester,
        Builder(
            builder: (c) => Scaffold(
                body: Center(
                    child: TextButton(
                        onPressed: () => mostrarFormProducto(c, producto: p), child: const Text('editar'))))));
    await tester.tap(find.text('editar'));
    await esperar(tester, 3);
    await tester.enterText(find.byKey(const ValueKey('campo_iva')), '150');
    await tester.tap(find.text('Guardar cambios'));
    await tester.pump();
    expect(find.text('Escribe un porcentaje de 0 a 100'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('campo_iva')), '10');
    await tester.tap(find.text('Guardar cambios'));
    await esperar(tester, 4);
    expect((await tester.runAsync(db.productos))!.single.iva, 10);
  });
}
