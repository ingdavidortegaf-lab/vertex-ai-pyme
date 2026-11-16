import 'package:flutter/material.dart';
import '../data/sync_service.dart';

/// Permite mostrar avisos desde cualquier parte (p. ej. cierre por
/// inactividad) sin depender de un BuildContext.
final mensajero = GlobalKey<ScaffoldMessengerState>();

void avisar(String texto) => mensajero.currentState
  ?..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(texto)));

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
