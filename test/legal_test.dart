import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vertex_ai_pyme/config.dart';
import 'package:vertex_ai_pyme/domain/legal.dart';
import 'package:vertex_ai_pyme/ui/legal_page.dart';
import 'soporte.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_CO'));

  const vertex = DatosEncargada(
      razonSocial: 'VERTEX TECH S.A.S.', nit: '900123456-7', correo: 'datos@vertex.co');

  test('el aviso y la casilla: la MiPyme es Responsable y VERTEX TECH Encargada', () {
    final aviso = avisoPrivacidad(vertex);
    expect(aviso, startsWith('AVISO DE PRIVACIDAD: En cumplimiento de la Ley 1581 de 2012 y el Decreto 1074 de 2015'));
    expect(aviso, contains('la MiPyme usuaria actúa como Responsable del Tratamiento'));
    expect(aviso, contains('VERTEX TECH (VERTEX TECH S.A.S., NIT 900123456-7), como operadora de la plataforma, '
        'actúa como Encargada del Tratamiento'));
    expect('$casillaAntesDelEnlace$casillaEnlace$casillaDespuesDelEnlace',
        'He leído el Aviso de Privacidad y autorizo de manera previa, expresa e informada el '
        'tratamiento de mis datos personales conforme a la Política de Tratamiento de Datos Personales.');
  });

  test('la política trae los datos de la Encargada, finalidades, derechos, plazos y contacto', () {
    final p = politicaTratamiento(contacto: 'correo@x.co', encargada: vertex)
        .map((e) => '${e.$1} ${e.$2}')
        .join(' ');
    for (final palabra in [
      'Responsable', 'Encargada', 'VERTEX TECH S.A.S.', '900123456-7', 'datos@vertex.co',
      'Finalidades', 'cédula o NIT', 'Superintendencia', '10 días', '15 días', 'correo@x.co',
    ]) {
      expect(p, contains(palabra));
    }
  });

  test('si faltan los datos de config.dart, los textos lo dicen en vez de quedar vacíos', () {
    const vacia = DatosEncargada();
    expect(vacia.incompleta, isTrue);
    expect(vertex.incompleta, isFalse);
    expect(avisoPrivacidad(vacia), contains('[razón social pendiente], NIT [NIT pendiente]'));
    final p = politicaTratamiento(contacto: 'c@x.co').map((e) => e.$2).join(' ');
    expect(p, contains('[correo pendiente]'));
  });

  test('formato de autorización del cliente prellenado, en PDF y registrado', () async {
    final a = AutorizacionCliente(
        cliente: 'Ana Pérez', comercio: 'Tienda Doña Marta', fecha: DateTime(2026, 11, 19), encargada: vertex);
    expect(a.cuerpo, contains('AUTORIZO a Tienda Doña Marta en calidad de Responsable'));
    expect(a.cuerpo, contains('VERTEX TECH (VERTEX TECH S.A.S., NIT 900123456-7) en calidad de Encargada'));
    expect(a.textoWhatsApp(), contains('AUTORIZO'));
    final pdf = await pdfAutorizacion(a, 'AU-TEST-000001');
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');

    final db = await baseDePrueba();
    final id = await db.saveCliente('Ana Pérez', '3001234567');
    expect(await db.autorizacionCliente(id), isNull);
    await db.registrarAutorizacionCliente(id, 'en la tienda');
    expect((await db.autorizacionCliente(id))!['medio'], 'en la tienda');
    final doc = await db.emitirDocumento('autorizacion', refId: id);
    expect(doc['numero'], startsWith('AU-'));
  });

  testWidgets('mientras no estén revisados, el aviso y la política muestran la marca de borrador', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: AvisoOficial()))));
    expect(find.text(marcaBorrador), Config.textosLegalesRevisados ? findsNothing : findsOneWidget);
    await tester.pumpWidget(const MaterialApp(home: PoliticaPage()));
    expect(find.text(marcaBorrador), Config.textosLegalesRevisados ? findsNothing : findsWidgets);
  });

  test('ningún texto legal menciona a terceros ajenos al servicio', () {
    final todo = [
      avisoPrivacidad(vertex),
      ...politicaTratamiento(contacto: 'c@x.co', encargada: vertex).map((e) => '${e.$1} ${e.$2}'),
      AutorizacionCliente(cliente: 'A', comercio: 'B', fecha: DateTime(2026), encargada: vertex).cuerpo,
      AutorizacionCliente.finalidades,
    ].join(' ').toLowerCase();
    // Las palabras van partidas para que la búsqueda en el repositorio no las encuentre aquí.
    for (final p in ['gober' 'naci', 'casa' 'nare', 'crea' 'tic', 'convo' 'catoria', 'anexo' ' 3']) {
      expect(todo, isNot(contains(p)));
    }
  });
}
