import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../data/local_db.dart';
import '../domain/formato.dart';
import '../domain/legal.dart';
import '../pdf/archivo.dart';
import 'comun.dart';
import 'herramientas_page.dart';
import 'tema.dart';

/// Abre un enlace web (o de correo) fuera de la app.
Future<void> abrirEnlace(String url) async {
  try {
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      avisar('No se pudo abrir el enlace');
    }
  } catch (_) {
    avisar('No se pudo abrir el enlace');
  }
}

/// Enlace visible y subrayado, como en una página web.
TextSpan enlace(BuildContext context, String texto, VoidCallback alTocar) => TextSpan(
      text: texto,
      style: TextStyle(
        color: Paleta.of(context).asistente,
        fontWeight: FontWeight.w700,
        decoration: TextDecoration.underline,
      ),
      recognizer: TapGestureRecognizer()..onTap = alTocar,
    );

void verPolitica(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute(builder: (_) => const PoliticaPage()));

/// El aviso de privacidad oficial (texto modelo de la convocatoria).
class AvisoOficial extends StatelessWidget {
  const AvisoOficial({super.key});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: esquema.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.verified_user_outlined, size: 18, color: Paleta.of(context).ventas),
          const SizedBox(width: 6),
          Text('Aviso de privacidad', style: t.titleSmall),
        ]),
        const SizedBox(height: 6),
        Text(avisoPrivacidadOficial, style: t.bodyMedium),
        const SizedBox(height: 8),
        Text.rich(TextSpan(style: t.bodyMedium, children: [
          const TextSpan(text: 'Política completa: '),
          enlace(context, casillaEnlace, () => verPolitica(context)),
          const TextSpan(text: ' · '),
          enlace(context, sitioGobernacionVisible, () => abrirEnlace(sitioGobernacion)),
        ])),
      ]),
    );
  }
}

/// Casilla de autorización SIN premarcar, con el enlace a la política.
class CasillaAutorizacion extends StatelessWidget {
  final bool valor;
  final ValueChanged<bool> alCambiar;
  const CasillaAutorizacion({super.key, required this.valor, required this.alCambiar});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Checkbox(value: valor, onChanged: (v) => alCambiar(v ?? false)),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text.rich(TextSpan(style: t.bodyMedium, children: [
            TextSpan(
                text: casillaAntesDelEnlace,
                recognizer: TapGestureRecognizer()..onTap = () => alCambiar(!valor)),
            enlace(context, casillaEnlace, () => verPolitica(context)),
            const TextSpan(text: casillaDespuesDelEnlace),
          ])),
        ),
      ),
    ]);
  }
}

/// Política de Tratamiento de Datos Personales: se consulta en la app, sin
/// internet («enlace offline» que pide la convocatoria).
class PoliticaPage extends StatelessWidget {
  const PoliticaPage({super.key});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final secciones = politicaTratamiento(
        contacto: Config.contactoPrivacidad, politicaGobernacion: Config.politicaGobernacion);
    return Scaffold(
      appBar: AppBar(title: const Text('Política de Tratamiento de Datos')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Política de Tratamiento de Datos Personales', style: t.headlineSmall),
        const SizedBox(height: 4),
        Text('VERTEX AI Pyme · Ley 1581 de 2012 y Decreto 1074 de 2015 · $versionAviso',
            style: t.bodySmall),
        const SizedBox(height: 12),
        const AvisoOficial(),
        for (final (titulo, cuerpo) in secciones) ...[
          const SizedBox(height: 14),
          Text(titulo, style: t.titleSmall),
          const SizedBox(height: 4),
          Text(cuerpo, style: t.bodyMedium),
        ],
        const SizedBox(height: 18),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
            onPressed: () => abrirEnlace(sitioGobernacion),
            icon: const Icon(Icons.public),
            label: const Text(sitioGobernacionVisible),
          ),
          OutlinedButton.icon(
            onPressed: () => abrirEnlace('mailto:${Config.contactoPrivacidad}'
                '?subject=${Uri.encodeComponent('Derechos sobre mis datos personales')}'),
            icon: const Icon(Icons.mail_outline),
            label: const Text(Config.contactoPrivacidad),
          ),
        ]),
      ]),
    );
  }
}

// --------------------------------------------- autorización de clientes
final _fecha = DateFormat('dd/MM/yyyy', 'es_CO');

/// Formato de autorización del Anexo 3, prellenado con los datos del
/// cliente y del comercio; se archiva con número (AU-…) y se puede imprimir
/// para firmar o enviar por WhatsApp para que el cliente responda AUTORIZO.
Future<void> generarAutorizacionCliente(BuildContext context, String clienteId) async {
  final db = LocalDb.instance;
  final c = await db.cliente(clienteId);
  if (c == null) return;
  final negocio = await db.perfilNegocio();
  final a = AutorizacionCliente(
    cliente: c['nombre'] as String,
    comercio: negocio.nombreVisible,
    telefono: mostrarTelefono((c['telefono'] as String?) ?? ''),
    municipio: negocio.direccion,
    fecha: DateTime.now(),
  );
  final documento = await db.emitirDocumento('autorizacion',
      refId: clienteId, clienteId: clienteId, clienteNombre: a.cliente,
      resumen: 'Autorización de datos personales', reutilizar: true);
  final numero = documento['numero'] as String;
  final pdf = PdfListo(nombre: nombreArchivo(numero), generar: (_) => pdfAutorizacion(a, numero));
  await archivarDocumento(documento, pdf);
  if (!context.mounted) return;
  await mostrarDocumento(context,
      titulo: 'Autorización N.º $numero',
      texto: a.textoWhatsApp(),
      telefono: (c['telefono'] as String?) ?? '',
      pdf: pdf,
      boton: 'Pedir autorización por WhatsApp',
      nota: 'Imprímela para que el cliente la firme, o envíala por WhatsApp y '
          'guarda su respuesta «AUTORIZO».');
}

Future<Uint8List> pdfAutorizacion(AutorizacionCliente a, String numero) async {
  const azul = PdfColor.fromInt(0xFF17362C);
  final doc = pw.Document(title: 'Autorización $numero');
  pw.Widget campo(String etiqueta, String valor) => pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey500, width: .6)),
        child: pw.Row(children: [
          pw.Text('$etiqueta ', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.Expanded(
              child: pw.Text(valor.isEmpty ? '______________________________' : valor,
                  style: const pw.TextStyle(fontSize: 10))),
        ]),
      );
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.letter.applyMargin(
        left: 18 * PdfPageFormat.mm, right: 18 * PdfPageFormat.mm,
        top: 16 * PdfPageFormat.mm, bottom: 16 * PdfPageFormat.mm),
    build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Text('Convocatoria CreaTIC Casanare 2026 · Formatos Modelo de Protección de Datos (Ley 1581 de 2012)',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      pw.SizedBox(height: 6),
      pw.Container(
        color: azul,
        padding: const pw.EdgeInsets.all(10),
        child: pw.Text('FORMATO DE AUTORIZACIÓN Y CONSENTIMIENTO INFORMADO PARA EL TRATAMIENTO DE DATOS PERSONALES',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 12)),
      ),
      pw.SizedBox(height: 4),
      pw.Text('N.º $numero', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9)),
      pw.SizedBox(height: 8),
      pw.Text(a.cuerpo, style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 3), textAlign: pw.TextAlign.justify),
      pw.SizedBox(height: 10),
      pw.Text(AutorizacionCliente.finalidades,
          style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 3), textAlign: pw.TextAlign.justify),
      pw.SizedBox(height: 14),
      pw.Row(children: [
        pw.Expanded(child: campo('Teléfono / Celular:', a.telefono)),
        pw.Expanded(child: campo('Correo electrónico:', '')),
      ]),
      pw.Row(children: [
        pw.Expanded(child: campo('Municipio / Dirección:', a.municipio)),
        pw.Expanded(child: campo('Fecha (DD/MM/AAAA):', _fecha.format(a.fecha))),
      ]),
      pw.SizedBox(height: 40),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Column(children: [
          pw.Container(width: 220, height: .8, color: PdfColors.black),
          pw.SizedBox(height: 3),
          pw.Text('Firma del titular', style: const pw.TextStyle(fontSize: 9)),
        ]),
        pw.Column(children: [
          pw.Container(width: 160, height: .8, color: PdfColors.black),
          pw.SizedBox(height: 3),
          pw.Text('C.C. / NIT', style: const pw.TextStyle(fontSize: 9)),
        ]),
      ]),
      pw.Spacer(),
      pw.Text('Responsable: ${a.comercio}. Encargada: Gobernación de Casanare – Dirección de las TIC. '
          'Política de Tratamiento de Datos Personales: disponible en la aplicación VERTEX AI Pyme y en '
          '$sitioGobernacionVisible. Canal de derechos: ${Config.contactoPrivacidad}.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
    ]),
  ));
  return doc.save();
}
