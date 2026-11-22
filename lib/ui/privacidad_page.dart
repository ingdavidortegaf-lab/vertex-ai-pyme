import 'package:flutter/material.dart';
import 'legal_page.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../data/local_db.dart';
import '../data/sync_service.dart';
import 'comun.dart';
import 'consent_gate.dart';

/// Aviso de privacidad (Ley 1581 de 2012). Se muestra en el primer uso y
/// desde el menú «Privacidad y datos».
class TextoAvisoPrivacidad extends StatelessWidget {
  const TextoAvisoPrivacidad({super.key});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget h(String s) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(s, style: t.titleSmall));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text(
          'VERTEX AI Pyme te ayuda a llevar los clientes, las ventas, los '
          'gastos y los cobros de tu negocio, aunque no haya señal.'),
      h('Qué datos guardamos'),
      const Text('• De tus clientes: solo nombre y celular (opcional).\n'
          '• De tu negocio: ventas, gastos, abonos y cobros pendientes.\n'
          '• De tu cuenta: el correo con el que inicias sesión.\n'
          'No pedimos cédulas, direcciones ni datos sensibles.'),
      h('Para qué los usamos'),
      const Text('Para registrar y consultar la información de tu negocio, '
          'mostrarte el tablero del mes, sugerirte mensajes para tus clientes '
          'y respaldar tu información en la nube.'),
      h('Cómo los protegemos'),
      const Text('• En el celular se guardan cifrados.\n'
          '• Viajan a la nube solo por conexión segura (HTTPS).\n'
          '• Cada empresa ve únicamente sus propios datos.\n'
          '• La sesión se cierra sola tras 30 minutos sin uso.\n'
          '• El asistente de IA recibe solo totales y la pregunta sin '
          'nombres, celulares ni correos.'),
      h('Quién es responsable'),
      const Text('Tu negocio es el responsable de los datos de sus clientes y '
          'debe contar con su autorización para registrarlos. VERTEX TECH, '
          'como operadora de la app, actúa como encargada del tratamiento y '
          'solo los usa para prestarte el servicio.'),
      h('Política de tratamiento de datos'),
      const Text('Puedes consultar la Política de Tratamiento de Datos '
          'Personales completa en esta app, en el menú ⋮ → «Privacidad y datos».'),
      h('Tus derechos'),
      const Text('Puedes conocer, actualizar, rectificar y suprimir tus datos, '
          'revocar esta autorización y presentar quejas ante la '
          'Superintendencia de Industria y Comercio. Escríbenos a '
          '${Config.contactoPrivacidad}. Respondemos consultas en máximo 10 '
          'días hábiles y reclamos en máximo 15 días hábiles.'),
    ]);
  }
}

class PrivacidadPage extends StatelessWidget {
  const PrivacidadPage({super.key});

  Future<void> _escribir() async {
    final uri = Uri(
      scheme: 'mailto',
      path: Config.contactoPrivacidad,
      queryParameters: {'subject': 'Derechos de datos personales'},
    );
    try {
      if (!await launchUrl(uri)) avisar('No se pudo abrir el correo');
    } catch (_) {
      avisar('No se pudo abrir el correo');
    }
  }

  Future<void> _revocar(BuildContext context) async {
    final ok = await confirmar(
        context,
        'Revocar autorización',
        'La app dejará de funcionar hasta que vuelvas a autorizar. Tus datos '
            'no se borran.',
        si: 'Revocar');
    if (!ok) return;
    await LocalDb.instance.borrarAjuste(ConsentGate.claveConsentimiento);
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    ConsentGate.revocado.value++;
  }

  Future<void> _borrar(BuildContext context) async {
    final pend = await LocalDb.instance.pendientes();
    if (!context.mounted) return;
    final extra = pend > 0
        ? '\n\nAtención: hay $pend cambios que aún no se han enviado a la nube '
            'y se perderán.'
        : '';
    final ok = await confirmar(
        context,
        'Borrar datos de este celular',
        'Se borrarán los clientes, movimientos y consultas guardados en este '
            'celular. No se puede deshacer.$extra',
        si: 'Borrar');
    if (!ok) return;
    await LocalDb.instance.borrarDatosLocales();
    await SyncService.instance.sync();
    avisar('Datos del celular borrados');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Privacidad y datos')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const AvisoOficial(),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () => verPolitica(context),
            icon: const Icon(Icons.gavel_outlined),
            label: const Text('Política de Tratamiento de Datos (completa)'),
          ),
          const SizedBox(height: 16),
          const TextoAvisoPrivacidad(),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            onPressed: _escribir,
            icon: const Icon(Icons.mail_outline),
            label: const Text('Ejercer mis derechos por correo'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _revocar(context),
            icon: const Icon(Icons.block),
            label: const Text('Revocar autorización'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _borrar(context),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Borrar datos de este celular'),
          ),
        ]),
      );
}
