import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/local_db.dart';
import '../domain/formato.dart';
import '../domain/resumen.dart';

/// Tablero del mes. Se calcula 100 % en el celular (funciona sin señal) y se
/// actualiza solo cada vez que cambia un dato.
class TableroPage extends StatefulWidget {
  const TableroPage({super.key});
  @override
  State<TableroPage> createState() => _TableroPageState();
}

class _TableroPageState extends State<TableroPage> {
  DatosAsistente? _d;

  @override
  void initState() {
    super.initState();
    LocalDb.instance.cambios.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    LocalDb.instance.cambios.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final d = await LocalDb.instance.datosAsistente();
    if (mounted) setState(() => _d = d);
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    if (d == null) return const Center(child: CircularProgressIndicator());
    final r = d.mes;
    final mes = DateFormat('MMMM y', 'es_CO').format(DateTime.now());
    final t = Theme.of(context).textTheme;

    Widget tarjeta(String titulo, String valor, Color color, IconData icono,
            {String? sub}) =>
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icono, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(child: Text(titulo, style: t.labelLarge)),
              ]),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(valor,
                    style: t.headlineSmall
                        ?.copyWith(color: color, fontWeight: FontWeight.bold)),
              ),
              if (sub != null) Text(sub, style: t.bodySmall),
            ]),
          ),
        );

    final total = r.ingresos + r.egresos;
    final deben = d.deudores;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        Text('Resumen de ${mes[0].toUpperCase()}${mes.substring(1)}',
            style: t.titleMedium),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.45,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            tarjeta('Ventas', cop(r.ingresos), Colors.green, Icons.trending_up,
                sub: r.nIngresos == 1 ? '1 venta' : '${r.nIngresos} ventas'),
            tarjeta('Gastos', cop(r.egresos), Colors.red, Icons.trending_down,
                sub: r.nEgresos == 1 ? '1 gasto' : '${r.nEgresos} gastos'),
            tarjeta('Utilidad', cop(r.utilidad),
                r.utilidad >= 0 ? Colors.teal : Colors.red, Icons.savings_outlined,
                sub: r.ingresos > 0 ? 'Margen ${(r.margen * 100).round()} %' : null),
            tarjeta('Por cobrar', cop(r.porCobrar), Colors.orange.shade800,
                Icons.account_balance_wallet_outlined,
                sub: r.nDeudores == 1 ? '1 cliente debe' : '${r.nDeudores} clientes deben'),
          ],
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.people_outline),
            title: Text('${r.nClientes} clientes registrados'),
            subtitle: Text('Hoy: ${cop(d.ventasHoy)} · Esta semana: ${cop(d.ventasSemana)}'),
          ),
        ),
        if (total > 0) ...[
          const SizedBox(height: 8),
          Text('Ventas frente a gastos', style: t.titleSmall),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 14,
              value: r.ingresos / total,
              color: Colors.green,
              backgroundColor: Colors.red.shade300,
            ),
          ),
        ],
        if (deben.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Quién te debe', style: t.titleSmall),
          for (final c in deben.take(5))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text(c.nombre),
              trailing: Text(cop(c.saldo),
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
            ),
        ],
        if (d.topClientes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Mejores clientes del mes', style: t.titleSmall),
          for (final c in d.topClientes)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.star_outline),
              title: Text(c.nombre),
              trailing: Text(cop(c.total)),
            ),
        ],
      ]),
    );
  }
}
