import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'escritorio.dart';
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

/// Datos de VERTEX TECH como Encargada, desde config.dart.
const encargadaConfig = DatosEncargada(
  razonSocial: Config.encargadaRazonSocial,
  nit: Config.encargadaNit,
  correo: Config.encargadaCorreo,
);

/// Cinta «BORRADOR PARA REVISIÓN DE UN ABOGADO» mientras los textos no estén
/// aprobados (Config.textosLegalesRevisados).
class MarcaBorrador extends StatelessWidget {
  const MarcaBorrador({super.key});
  @override
  Widget build(BuildContext context) {
    if (Config.textosLegalesRevisados) return const SizedBox.shrink();
    final esquema = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('marca_borrador'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: esquema.errorContainer, borderRadius: BorderRadius.circular(8)),
      child: Text(marcaBorrador,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: esquema.onErrorContainer, fontWeight: FontWeight.w800)),
    );
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
    .push(rutaVertex(const PoliticaPage()));

/// El aviso de privacidad.
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
        const MarcaBorrador(),
        Row(children: [
          Icon(Icons.verified_user_outlined, size: 18, color: Paleta.of(context).ventas),
          const SizedBox(width: 6),
          Text('Aviso de privacidad', style: t.titleSmall),
        ]),
        const SizedBox(height: 6),
        Text(avisoPrivacidad(encargadaConfig), style: t.bodyMedium),
        const SizedBox(height: 8),
        Text.rich(TextSpan(style: t.bodyMedium, children: [
          const TextSpan(text: 'Política completa: '),
          enlace(context, casillaEnlace, () => verPolitica(context)),
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
/// internet.
class PoliticaPage extends StatelessWidget {
  const PoliticaPage({super.key});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final secciones =
        politicaTratamiento(contacto: Config.contactoPrivacidad, encargada: encargadaConfig);
    return Scaffold(
      appBar: AppBar(title: const Text('Política de Tratamiento de Datos')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const MarcaBorrador(),
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

/// Formato de autorización del cliente, prellenado con los datos del
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
    encargada: encargadaConfig,
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
      pw.Text('VERTEX AI Pyme · Protección de datos personales (Ley 1581 de 2012)',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      if (!Config.textosLegalesRevisados)
        pw.Text(marcaBorrador,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.red800, fontWeight: pw.FontWeight.bold)),
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
      pw.Text('Responsable: ${a.comercio}. Encargada: ${a.encargada.nombre}, ${a.encargada.correoTexto}. '
          'Política de Tratamiento de Datos Personales: disponible en la aplicación VERTEX AI Pyme. '
          'Canal de derechos: ${Config.contactoPrivacidad}.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
    ]),
  ));
  return doc.save();
}

/// Estado de la autorización del cliente: cuándo y cómo autorizó, o un botón
/// para dejar registrado que respondió «AUTORIZO» por WhatsApp.
class EstadoAutorizacion extends StatefulWidget {
  final String clienteId;
  const EstadoAutorizacion({super.key, required this.clienteId});
  @override
  State<EstadoAutorizacion> createState() => _EstadoAutorizacionState();
}

class _EstadoAutorizacionState extends State<EstadoAutorizacion> {
  Map<String, dynamic>? _a;
  var _cargado = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await LocalDb.instance.autorizacionCliente(widget.clienteId);
    if (mounted) {
      setState(() {
        _a = a;
        _cargado = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_cargado) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final a = _a;
    if (a != null) {
      final f = DateTime.tryParse(a['fecha'] as String? ?? '')?.toLocal();
      return Row(children: [
        Icon(Icons.verified_user, size: 18, color: Paleta.of(context).ventas),
        const SizedBox(width: 6),
        Expanded(
          child: Text('Autorizó el tratamiento de datos${f == null ? '' : ' el ${_fecha.format(f)}'} (${a['medio']})',
              style: t.bodySmall),
        ),
      ]);
    }
    return OutlinedButton.icon(
      onPressed: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            title: const Text('¿El cliente respondió AUTORIZO?'),
            content: const Text('Guarde también el pantallazo del chat como prueba. '
                'Queda registrado con la fecha de hoy.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(d), child: const Text('Todavía no')),
              FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Sí, autorizó')),
            ],
          ),
        );
        if (ok != true) return;
        await LocalDb.instance.registrarAutorizacionCliente(widget.clienteId, 'respondió AUTORIZO por WhatsApp');
        _load();
      },
      icon: const Icon(Icons.how_to_reg_outlined),
      label: const Text('Ya respondió «AUTORIZO»'),
    );
  }
}
