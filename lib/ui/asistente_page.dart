import 'package:flutter/material.dart';
import '../data/asistente_service.dart';
import '../data/local_db.dart';
import '../data/sync_service.dart';
import 'cliente_detalle_page.dart';

class AsistentePage extends StatefulWidget {
  const AsistentePage({super.key});
  @override
  State<AsistentePage> createState() => _AsistentePageState();
}

class _AsistentePageState extends State<AsistentePage> {
  final _q = TextEditingController();
  RespuestaAsistente? _resp;
  String? _pregunta;
  bool _cargando = false;
  List<Map<String, Object?>> _consejos = [];

  static const _sugeridas = [
    '¿Cuánto vendí hoy?',
    '¿Cuánto vendí esta semana?',
    '¿Quién me debe?',
    '¿Quiénes son mis mejores clientes?',
    '¿Cuánto gasté este mes?',
    '¿Cómo voy este mes?',
  ];

  @override
  void initState() {
    super.initState();
    LocalDb.instance.cambios.addListener(_cargarConsejos);
    _cargarConsejos();
  }

  @override
  void dispose() {
    LocalDb.instance.cambios.removeListener(_cargarConsejos);
    _q.dispose();
    super.dispose();
  }

  Future<void> _cargarConsejos() async {
    final l = await LocalDb.instance.preguntasIA();
    if (mounted) setState(() => _consejos = l);
  }

  Future<void> _preguntar(String texto) async {
    final pregunta = texto.trim();
    if (pregunta.isEmpty || _cargando) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _cargando = true;
      _pregunta = pregunta;
    });
    final s = SyncService.instance;
    RespuestaAsistente resp;
    try {
      resp = await AsistenteService.preguntar(pregunta,
          api: s.remoto, hayRed: s.hayRed);
    } catch (_) {
      resp = const RespuestaAsistente(
          'No pude consultar tus datos en este momento. Intenta de nuevo.');
    }
    if (!mounted) return;
    setState(() {
      _resp = resp;
      _cargando = false;
    });
    _q.clear();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final resp = _resp;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Asistente de tu negocio', style: t.titleLarge),
      const SizedBox(height: 4),
      const Text('Pregúntale por tus ventas, gastos y cobros. Responde con tus '
          'datos aunque no haya señal.'),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 4, children: [
        for (final s in _sugeridas)
          ActionChip(
              label: Text(s), onPressed: _cargando ? null : () => _preguntar(s)),
      ]),
      const SizedBox(height: 12),
      TextField(
        controller: _q,
        maxLength: 300,
        textInputAction: TextInputAction.send,
        decoration: InputDecoration(
          labelText: 'Escribe tu pregunta',
          hintText: 'Ej.: mensaje para cobrarle a Ana',
          suffixIcon: IconButton(
            tooltip: 'Preguntar',
            icon: const Icon(Icons.send),
            onPressed: _cargando ? null : () => _preguntar(_q.text),
          ),
        ),
        onSubmitted: _preguntar,
      ),
      if (_cargando)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      if (resp != null && !_cargando)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_pregunta != null)
                Text(_pregunta!, style: t.titleSmall),
              const SizedBox(height: 4),
              Row(children: [
                Icon(resp.esIA ? Icons.auto_awesome : Icons.phone_android, size: 14),
                const SizedBox(width: 4),
                Text(
                    resp.esIA
                        ? 'Respuesta con IA'
                        : 'Respuesta con tus datos (funciona sin señal)',
                    style: t.labelMedium),
              ]),
              const SizedBox(height: 8),
              SelectableText(resp.texto),
              if (resp.telefono != null && resp.mensajeWhatsApp != null) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () =>
                      abrirWhatsApp(resp.telefono!, resp.mensajeWhatsApp!),
                  icon: const Icon(Icons.send),
                  label: const Text('Abrir en WhatsApp'),
                ),
              ],
            ]),
          ),
        ),
      if (_consejos.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('Consejos con IA', style: t.titleMedium),
        for (final c in _consejos)
          Card(
            child: ListTile(
              title: Text(c['pregunta'] as String),
              subtitle: Text(c['estado'] == 'pendiente'
                  ? 'En cola: se responderá cuando haya señal.'
                  : (c['respuesta'] as String? ?? '')),
              leading: Icon(c['estado'] == 'pendiente'
                  ? Icons.schedule
                  : Icons.auto_awesome),
            ),
          ),
      ],
    ]);
  }
}
