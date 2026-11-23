import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/sync_service.dart';
import '../domain/asistente_local.dart' show enlaceWhatsApp;

/// Permite mostrar avisos desde cualquier parte (p. ej. cierre por
/// inactividad) sin depender de un BuildContext.
final mensajero = GlobalKey<ScaffoldMessengerState>();

void avisar(String texto) => mensajero.currentState
  ?..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(texto)));

/// Aviso con un botón (por ejemplo «Enviar comprobante»).
void avisarConAccion(String texto, String accion, VoidCallback alTocar) =>
    mensajero.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(texto),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(label: accion, onPressed: alTocar),
      ));

/// Abre WhatsApp con el mensaje listo. Con [telefono] va directo a ese
/// chat; sin él, WhatsApp deja elegir el contacto, un grupo o el estado.
Future<void> enviarWhatsApp(String mensaje, {String? telefono}) async {
  final uri = telefono == null || telefono.isEmpty
      ? Uri.parse('https://wa.me/?text=${Uri.encodeComponent(mensaje)}')
      : enlaceWhatsApp(telefono, mensaje);
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) avisar('No se pudo abrir WhatsApp');
  } catch (_) {
    avisar('No se pudo abrir WhatsApp');
  }
}

/// Icono pequeño con el estado de sincronización de un registro.
/// En modo solo local no se muestra nada.
Widget iconoSync(Object? estado) {
  if (SyncService.instance.remoto == null) return const SizedBox.shrink();
  switch (estado) {
    case 'enviado':
      return const Tooltip(
          message: 'Guardado en la nube',
          child: Icon(Icons.cloud_done, size: 16, color: Colors.green));
    case 'error':
      return const Tooltip(
          message: 'No se pudo enviar',
          child: Icon(Icons.error_outline, size: 16, color: Colors.red));
    default:
      return const Tooltip(
          message: 'Pendiente de enviar',
          child: Icon(Icons.cloud_upload_outlined, size: 16, color: Colors.orange));
  }
}

/// Diálogo de confirmación sí/no.
Future<bool> confirmar(BuildContext context, String titulo, String texto,
    {String si = 'Sí', String no = 'Cancelar'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(titulo),
      content: Text(texto),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(no)),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(si)),
      ],
    ),
  );
  return r == true;
}

/// Diálogo con un campo de texto cuyo controlador vive lo mismo que el
/// diálogo: se libera cuando el diálogo termina de cerrarse, no antes (si se
/// libera al volver de showDialog, la animación de salida lo usa ya liberado).
Future<T?> dialogoConTexto<T>(BuildContext context,
        {String texto = '',
        required Widget Function(BuildContext context, TextEditingController ctrl) builder}) =>
    showDialog<T>(context: context, builder: (_) => _DialogoConTexto(texto: texto, builder: builder));

class _DialogoConTexto extends StatefulWidget {
  final String texto;
  final Widget Function(BuildContext context, TextEditingController ctrl) builder;
  const _DialogoConTexto({required this.texto, required this.builder});
  @override
  State<_DialogoConTexto> createState() => _DialogoConTextoState();
}

class _DialogoConTextoState extends State<_DialogoConTexto> {
  late final _ctrl = TextEditingController(text: widget.texto);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _ctrl);
}
