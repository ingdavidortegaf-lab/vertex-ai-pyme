import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/local_db.dart';
import '../domain/caja.dart';
import '../domain/formato.dart';
import 'tema.dart';

/// Turnos de caja cerrados: quién, cuándo, cuánto debía haber y cuánto se
/// contó. Los de los empleados llegan de la nube.
class TurnosPage extends StatefulWidget {
  const TurnosPage({super.key});
  @override
  State<TurnosPage> createState() => _TurnosPageState();
}

class _TurnosPageState extends State<TurnosPage> {
  List<Turno>? _turnos;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final l = await LocalDb.instance.turnos();
    if (mounted) setState(() => _turnos = l);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Paleta.of(context);
    final fmt = DateFormat("EEE d 'de' MMM, h:mm a", 'es_CO');
    final hora = DateFormat('h:mm a', 'es_CO');
    final l = _turnos;
    return Scaffold(
      appBar: AppBar(title: const Text('Turnos de caja')),
      body: l == null
          ? const Center(child: CircularProgressIndicator())
          : l.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Aún no hay turnos cerrados. Se abren y cierran desde la Caja.',
                        textAlign: TextAlign.center),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                  itemCount: l.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final x = l[i];
                    final d = x.diferencia ?? 0;
                    final color = d.abs() < 0.5 ? p.ventas : (d < 0 ? Theme.of(context).colorScheme.error : p.fiado);
                    return Card(
                      child: ListTile(
                        key: ValueKey('turno_${x.id}'),
                        title: Text(x.perfil.isEmpty ? 'Turno' : 'Turno de ${x.perfil}'),
                        subtitle: Text([
                          '${fmt.format(x.abre)} a ${hora.format(x.cierra!)}',
                          'Base ${cop(x.base)} · debía haber ${cop(x.esperado ?? 0)} · contó ${cop(x.contado ?? 0)}',
                          if (x.nota.isNotEmpty) x.nota,
                        ].join('\n')),
                        isThreeLine: true,
                        trailing: Text(
                          d.abs() < 0.5 ? 'Cuadra' : '${d > 0 ? '+' : '−'}${cop(d.abs())}',
                          style: cifras(t.titleSmall?.copyWith(color: color)),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
