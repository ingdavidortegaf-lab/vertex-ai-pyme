import 'package:flutter/material.dart';
import '../data/asistente_service.dart';
import '../data/local_db.dart';
import '../data/sync_service.dart';
import 'cliente_detalle_page.dart';
import 'tema.dart';

class AsistentePage extends StatefulWidget {
  const AsistentePage({super.key});
  @override
  State<AsistentePage> createState() => _AsistentePageState();
}

class _AsistentePageState extends State<AsistentePage> {
  final _q = TextEditingController();
  final _scroll = ScrollController();
  RespuestaAsistente? _resp;
  String? _pregunta;
  bool _cargando = false;
  List<Map<String, Object?>> _consejos = [];

  static const _sugeridas = [
    '¿Cuánto vendí hoy?',
    '¿Cuánto vendí esta semana?',
    '¿Quién me debe?',
    '¿Qué se me está agotando?',
    '¿Cuál es mi producto más vendido?',
    '¿Cómo voy con la meta?',
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
    _scroll.dispose();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final quieto = MediaQuery.disableAnimationsOf(context);
      final destino = _scroll.position.maxScrollExtent;
      quieto
          ? _scroll.jumpTo(destino)
          : _scroll.animateTo(destino,
              duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Paleta.of(context);
    final esquema = Theme.of(context).colorScheme;
    final resp = _resp;
    return Column(children: [
      Expanded(
        child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: p.asistenteFondo, borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.auto_awesome, color: p.asistente),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Asistente de tu negocio', style: t.titleLarge),
                const SizedBox(height: 4),
                Text(
                    'Pregúntale por tus ventas, gastos y cobros. Responde con '
                    'tus datos aunque no haya señal.',
                    style: t.bodyMedium?.copyWith(color: esquema.onSurfaceVariant)),
              ]),
            ),
          ]),
          const SizedBox(height: 18),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in _sugeridas)
              ActionChip(
                  avatar: Icon(Icons.chat_bubble_outline, size: 18, color: p.asistente),
                  label: Text(s),
                  onPressed: _cargando ? null : () => _preguntar(s)),
          ]),
          if (_pregunta != null) ...[
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: p.pizarra,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(6),
                    ),
                  ),
                  child: Text(_pregunta!,
                      style: t.bodyLarge?.copyWith(color: p.tizaBlanca)),
                ),
              ),
            ),
          ],
          if (_cargando) ...[
            const SizedBox(height: 12),
            Row(children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: p.asistente),
              ),
              const SizedBox(width: 10),
              Text('Revisando tus datos…',
                  style: t.bodyMedium?.copyWith(color: esquema.onSurfaceVariant)),
            ]),
          ],
          if (resp != null && !_cargando) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: esquema.surfaceContainerLowest,
                border: Border.all(color: esquema.outlineVariant),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: resp.esIA ? p.asistenteFondo : p.ventasFondo,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(resp.esIA ? Icons.auto_awesome : Icons.smartphone,
                        size: 14, color: resp.esIA ? p.asistente : p.ventas),
                    const SizedBox(width: 6),
                    Text(resp.esIA ? 'Respuesta con IA' : 'Con tus datos · sin señal',
                        style: t.labelMedium?.copyWith(
                            color: resp.esIA ? p.asistente : p.ventas)),
                  ]),
                ),
                const SizedBox(height: 10),
                SelectableText(resp.texto, style: t.bodyLarge),
                if (resp.telefono != null && resp.mensajeWhatsApp != null) ...[
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1C7A43),
                        foregroundColor: Colors.white),
                    onPressed: () =>
                        abrirWhatsApp(resp.telefono!, resp.mensajeWhatsApp!),
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('Abrir en WhatsApp'),
                  ),
                ],
              ]),
            ),
          ],
          if (_consejos.isNotEmpty) ...[
            const TituloSeccion('Consejos con IA'),
            Card(
              child: Column(children: [
                for (final (i, c) in _consejos.indexed) ...[
                  if (i > 0) const Divider(indent: 72),
                  ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: c['estado'] == 'pendiente'
                            ? p.fiadoFondo
                            : p.asistenteFondo,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                          c['estado'] == 'pendiente'
                              ? Icons.schedule
                              : Icons.auto_awesome,
                          color: c['estado'] == 'pendiente' ? p.fiado : p.asistente),
                    ),
                    title: Text(c['pregunta'] as String),
                    subtitle: Text(c['estado'] == 'pendiente'
                        ? 'En cola: se responderá cuando haya señal.'
                        : (c['respuesta'] as String? ?? '')),
                  ),
                ],
              ]),
            ),
          ],
        ]),
      ),
      Material(
        color: esquema.surfaceContainerLowest,
        child: Container(
          decoration: BoxDecoration(
              border: Border(top: BorderSide(color: esquema.outlineVariant))),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _q,
                maxLength: 300,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                decoration: const InputDecoration(
                  hintText: 'Escribe tu pregunta…',
                  counterText: '',
                ),
                onSubmitted: _preguntar,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Preguntar',
              style: IconButton.styleFrom(
                  minimumSize: const Size(52, 52),
                  backgroundColor: p.asistente,
                  foregroundColor: Theme.of(context).brightness == Brightness.light
                      ? Colors.white
                      : const Color(0xFF0B2018)),
              icon: const Icon(Icons.arrow_upward_rounded),
              onPressed: _cargando ? null : () => _preguntar(_q.text),
            ),
          ]),
        ),
      ),
    ]);
  }
}
