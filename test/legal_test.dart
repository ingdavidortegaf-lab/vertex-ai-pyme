import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vertex_ai_pyme/domain/legal.dart';
import 'package:vertex_ai_pyme/ui/legal_page.dart';
import 'soporte.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_CO'));

  test('el aviso y la casilla son el texto modelo oficial de la convocatoria', () {
    expect(avisoPrivacidadOficial, startsWith('AVISO DE PRIVACIDAD: En cumplimiento de la Ley 1581 de 2012 y el Decreto 1074 de 2015'));
    expect(avisoPrivacidadOficial, contains('la MiPyme usuaria actúa como Responsable del Tratamiento'));
    expect(avisoPrivacidadOficial, contains('actúa como Encargada del Tratamiento'));
    expect('$casillaAntesDelEnlace$casillaEnlace$casillaDespuesDelEnlace',
        'He leído el Aviso de Privacidad y autorizo de manera previa, expresa e informada el '
        'tratamiento de mis datos personales conforme a la Política de Tratamiento de Datos Personales.');
  });

  test('la política trae roles, finalidades, derechos, plazos y el sitio de la Gobernación', () {
    final p = politicaTratamiento(contacto: 'correo@x.co').map((e) => '${e.$1} ${e.$2}').join(' ');
    for (final palabra in ['Responsable', 'Encargada', 'Finalidades', 'Superintendencia', '10 días', '15 días', 'www.casanare.gov.co', 'correo@x.co']) {
      expect(p, contains(palabra));
    }
  });

  test('formato de autorización del cliente (Anexo 3) prellenado, en PDF y registrado', () async {
    final a = AutorizacionCliente(cliente: 'Ana Pérez', comercio: 'Tienda Doña Marta', fecha: DateTime(2026, 11, 19));
    expect(a.cuerpo, contains('AUTORIZO a Tienda Doña Marta en calidad de Responsable'));
    expect(a.cuerpo, contains('GOBERNACIÓN DE CASANARE – DIRECCIÓN DE LAS TIC'));
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
}
